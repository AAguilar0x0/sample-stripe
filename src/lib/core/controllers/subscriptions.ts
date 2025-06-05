import { StripeService } from '@/lib/extern/payment/stripe'

export class SubscriptionsController {
  constructor(private stripeService: StripeService) {}

  async handleWebhook() {}

  async createCheckoutSession(email: string, priceId: string, baseUrl: string) {
    return await this.stripeService.createCheckoutSession(email, priceId, baseUrl, baseUrl)
  }

  async checkSubscriptionStatus(sessionId: string) {
    const session = await this.stripeService.retrieveSession(sessionId)
    if (!session.subscription) {
      return { status: 'pending' as const }
    }

    const subscription = await this.stripeService.retrieveSubscription(
      session.subscription as string,
    )
    return {
      status: subscription.status as
        | 'active'
        | 'canceled'
        | 'incomplete'
        | 'incomplete_expired'
        | 'past_due'
        | 'trialing'
        | 'unpaid',
      subscriptionId: subscription.id,
      customerId: subscription.customer as string,
    }
  }
}
