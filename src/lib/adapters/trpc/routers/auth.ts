import { publicProcedure, router } from '@/lib/trpc/init'

export const authRouter = router({
  getAccountData: publicProcedure.query(async ({ ctx }) => {
    return ctx.controllers.auth.getCurrentUser()
  }),
})
