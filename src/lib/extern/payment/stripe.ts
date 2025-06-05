import Stripe from 'stripe'
import { StripeProduct } from '@/lib/core/dtos/stripe'

export class StripeService {
  private stripe: Stripe

  constructor(
    apiKey: string,
    private webhookSecret: string,
  ) {
    this.stripe = new Stripe(apiKey, {
      apiVersion: '2025-02-24.acacia',
    })
  }

  async constructWebhookEvent(payload: string, signature: string) {
    const event = this.stripe.webhooks.constructEvent(payload, signature, this.webhookSecret)
    const result = {
      productId: '',
      email: '',
      subscriptionId: '',
      end: 0,
      customerId: '',
    }
    try {
      switch (event.type) {
        case 'invoice.payment_succeeded':
          const object = event.data.object
          const id = object.lines.data[0].plan?.product
          if (typeof id !== 'string') {
            throw new Error('Product ID is required')
          }
          result.productId = id
          if (!object.customer_email) {
            throw new Error('Customer email is required')
          }
          result.email = object.customer_email
          const subscriptionId = object.subscription
          if (typeof subscriptionId !== 'string') {
            throw new Error('Subscription ID is required')
          }
          result.subscriptionId = subscriptionId
          result.end = object.lines.data[0].period.end
          if (!object.metadata) {
            throw new Error('Metadata is required')
          }
          if (typeof object.customer !== 'string') {
            throw new Error('Customer ID is required')
          }
          result.customerId = object.customer
          return {
            status: 'active',
            productId: result.productId,
            email: result.email,
            subscriptionId: result.subscriptionId,
            end: result.end,
            customerId: result.customerId,
          }
        case 'customer.subscription.deleted':
          const deletedSubscription = event.data.object
          if (!deletedSubscription.items.data[0].plan?.product) {
            throw new Error('Product ID is required')
          }
          result.productId = deletedSubscription.items.data[0].plan.product as string
          if (typeof deletedSubscription.id !== 'string') {
            throw new Error('Subscription ID is required')
          }
          result.subscriptionId = deletedSubscription.id
          if (!deletedSubscription.metadata) {
            throw new Error('Metadata is required')
          }
          if (typeof deletedSubscription.customer !== 'string') {
            throw new Error('Customer ID is required')
          }
          result.customerId = deletedSubscription.customer
          return {
            status: 'canceled',
            productId: result.productId,
            email: result.email,
            subscriptionId: result.subscriptionId,
            customerId: result.customerId,
          }
        default:
          // throw new Error(`Unhandled event type: ${event.type}`)
          return {}
      }
    } catch (error) {
      throw error
    }
  }

  async createBusinessCustomer(email: string, businessId: string) {
    const customer = await this.stripe.customers.create({
      email,
      metadata: {
        business_id: businessId,
      },
    })
    return customer.id
  }

  async getPortalSession(customerId: string, returnUrl: string) {
    const session = await this.stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl,
    })
    if (!session.url) {
      throw new Error('No URL returned from Stripe')
    }
    return session.url
  }

  async createCheckoutSession(
    email: string,
    priceId: string,
    successUrl: string,
    cancelUrl: string,
  ) {
    const session = await this.stripe.checkout.sessions.create({
      customer_email: email,
      line_items: [{ price: priceId, quantity: 1 }],
      mode: 'subscription',
      automatic_tax: { enabled: true },
      allow_promotion_codes: true,
      success_url: successUrl,
      cancel_url: cancelUrl,
    })
    if (!session.url) {
      throw new Error('No URL returned from Stripe')
    }
    return session
  }

  async getProducts(): Promise<StripeProduct[]> {
    const products = await this.stripe.products.list({
      active: true,
    })

    const processedProducts = await Promise.all(
      products.data.map(async data => {
        try {
          // Fetch all active recurring prices for the product
          const prices = await this.stripe.prices.list({
            product: data.id,
            active: true,
            type: 'recurring',
          })

          if (prices.data.length === 0) {
            return null
          }

          // Group prices by interval
          const pricesByInterval = prices.data.reduce<Record<string, Stripe.Price>>(
            (acc, price) => {
              if (price.recurring) {
                acc[price.recurring.interval] = price
              }
              return acc
            },
            {},
          )

          // Get monthly and annual prices if they exist
          const monthlyPrice = pricesByInterval['month']
          const annualPrice = pricesByInterval['year']

          // If neither monthly nor annual price exists, skip this product
          if (!monthlyPrice && !annualPrice) {
            return null
          }

          const baseProduct = {
            id: data.id,
            name: data.name,
            description: data.description,
          }

          const products: StripeProduct[] = []

          if (monthlyPrice) {
            products.push({
              ...baseProduct,
              priceId: monthlyPrice.id,
              price: monthlyPrice.unit_amount ?? 0,
              currency: monthlyPrice.currency,
              interval: monthlyPrice.recurring?.interval ?? 'month',
              intervalCount: monthlyPrice.recurring?.interval_count ?? 1,
            })
          }

          if (annualPrice) {
            products.push({
              ...baseProduct,
              priceId: annualPrice.id,
              price: annualPrice.unit_amount ?? 0,
              currency: annualPrice.currency,
              interval: annualPrice.recurring?.interval ?? 'year',
              intervalCount: annualPrice.recurring?.interval_count ?? 1,
            })
          }

          return products
        } catch (error) {
          console.error('Error processing product:', data.id, error)
          return null
        }
      }),
    )

    // Flatten the array of arrays and remove nulls
    const validProducts = processedProducts
      .filter((products): products is NonNullable<typeof products> => products !== null)
      .flat()

    if (validProducts.length === 0) {
      throw new Error('No valid products found with recurring prices')
    }

    return validProducts
  }

  async retrieveSession(sessionId: string) {
    return await this.stripe.checkout.sessions.retrieve(sessionId)
  }

  async retrieveSubscription(subscriptionId: string) {
    return await this.stripe.subscriptions.retrieve(subscriptionId)
  }
}
