import { z } from 'zod'

export const stripeProductSchema = z.object({
  id: z.string(),
  priceId: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  price: z.number(),
  currency: z.string(),
  interval: z.string(),
  intervalCount: z.number(),
})

export type StripeProduct = z.infer<typeof stripeProductSchema>
