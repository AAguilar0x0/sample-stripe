import trpcAdapter from '@/lib/adapters/trpc/routers'

export const appRouter = trpcAdapter

export type AppRouter = typeof appRouter
