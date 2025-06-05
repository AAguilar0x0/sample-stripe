import { z } from 'zod'
import { publicProcedure, router } from '@/lib/trpc/init'

export const subscriptionsRouter = router({
  createCheckoutSession: publicProcedure.mutation(async ({ ctx }) => {
    return ctx.controllers.subscriptions.createCheckoutSession(
      'john.doe@example.com',
      'price_1Qpoc1IVwe1nYvpm2pLACqSA',
      ctx.referer,
    )
  }),
  checkSubscriptionStatus: publicProcedure
    .input(z.object({ sessionId: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.controllers.subscriptions.checkSubscriptionStatus(input.sessionId)
    }),
})
