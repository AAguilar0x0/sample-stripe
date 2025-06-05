import { authRouter } from './auth'
import { subscriptionsRouter } from './subscriptions'
import { router } from '@/lib/trpc/init'

const trpcAdapter = router({
  auth: authRouter,
  subscriptions: subscriptionsRouter,
})

export default trpcAdapter
