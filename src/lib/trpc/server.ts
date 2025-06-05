import 'server-only' // <-- ensure this file cannot be imported from the client
import { createHydrationHelpers } from '@trpc/react-query/rsc'
import { cache } from 'react'
import { createCallerFactory, createTRPCContext } from '@/lib/trpc/init'
import { makeQueryClient } from '@/lib/trpc/query-client'
import { appRouter } from '@/lib/trpc'

export const getQueryClient = cache(makeQueryClient)
const caller = createCallerFactory(appRouter)(createTRPCContext)
export const { trpc, HydrateClient } = createHydrationHelpers<typeof appRouter>(
  caller,
  getQueryClient,
)
