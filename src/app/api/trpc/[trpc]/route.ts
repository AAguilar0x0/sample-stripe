import { fetchRequestHandler } from '@trpc/server/adapters/fetch'
import { appRouter } from '@/lib/trpc'
import { createTRPCContext } from '@/lib/trpc/init'

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: '/api/trpc',
    req,
    router: appRouter,
    createContext: createTRPCContext,
    onError({ error, ctx, req: {}, ...opts }) {
      const date = new Date()
      const data = [date.toISOString(), error]
      if (ctx !== undefined) {
        const { controllers: _, ...rest } = ctx
        Object.assign(opts, { ctx: rest })
      }
      data.push(JSON.stringify(opts, null, 2))
      console.error('[Error]', ...data)
    },
  })

export { handler as GET, handler as POST }
