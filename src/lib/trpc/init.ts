import { initTRPC, TRPCError } from '@trpc/server'
import { cache } from 'react'
import superjson from 'superjson'
import { headers } from 'next/headers'
import { MyServiceProvider } from '@/lib/extern'
import { MyControllerFactory } from '@/lib/core/controllers'
import { env } from '@/lib/env/server'

export const createTRPCContext = cache(async () => {
  const header = await headers()
  const services = new MyServiceProvider()
  const controllers = new MyControllerFactory(services)
  const auth = controllers.Auth()
  async function getUser() {
    try {
      return await auth.getCurrentUser()
    } catch {
      return null
    }
  }
  const prodURL = env.VERCEL_ENV === 'production' ? env.VERCEL_PROJECT_PRODUCTION_URL : undefined
  const origin = prodURL ?? env.VERCEL_BRANCH_URL ?? env.VERCEL_URL ?? 'http://localhost:3000'
  return {
    user: await getUser(),
    origin: header.get('origin') ?? origin,
    referer: header.get('referer') ?? origin,
    controllers: {
      auth: auth,
      subscriptions: controllers.Subscription(),
    },
  }
})
export type Context = Awaited<ReturnType<typeof createTRPCContext>>

const t = initTRPC.context<Context>().create({
  transformer: superjson,
})

export const router = t.router
export const createCallerFactory = t.createCallerFactory
export const publicProcedure = t.procedure
export const protectedProcedure = t.procedure.use(opts => {
  if (!opts.ctx.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' })
  }
  return opts.next({
    ctx: {
      user: opts.ctx.user,
    },
  })
})
