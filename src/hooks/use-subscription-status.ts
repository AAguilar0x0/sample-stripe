import { useEffect, useState } from 'react'
import { trpc } from '@/lib/trpc/client'

type SubscriptionStatus =
  | 'pending'
  | 'active'
  | 'canceled'
  | 'incomplete'
  | 'incomplete_expired'
  | 'past_due'
  | 'trialing'
  | 'unpaid'

const SESSION_ID_KEY = 'subscription_session_id'

export function useSubscriptionStatus(providedSessionId?: string | null) {
  const [status, setStatus] = useState<SubscriptionStatus | null>(null)
  const [subscriptionId, setSubscriptionId] = useState<string | null>(null)
  const [customerId, setCustomerId] = useState<string | null>(null)
  const [sessionId, setSessionId] = useState<string | null>(null)

  // Load session ID from localStorage on mount if no sessionId is provided
  useEffect(() => {
    if (typeof window !== 'undefined' && !providedSessionId) {
      const storedSessionId = localStorage.getItem(SESSION_ID_KEY)
      if (storedSessionId) {
        setSessionId(storedSessionId)
      }
    } else if (providedSessionId) {
      setSessionId(providedSessionId)
    }
  }, [providedSessionId])

  const { data, isLoading } = trpc.subscriptions.checkSubscriptionStatus.useQuery(
    { sessionId: sessionId ?? '' },
    {
      enabled: !!sessionId,
      refetchInterval: 2000,
      refetchIntervalInBackground: true,
    },
  )

  useEffect(() => {
    if (data) {
      setStatus(data.status)
      setSubscriptionId(data.subscriptionId ?? null)
      setCustomerId(data.customerId ?? null)
    }
  }, [data])

  const saveSessionId = (newSessionId: string) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem(SESSION_ID_KEY, newSessionId)
    }
    setSessionId(newSessionId)
  }

  const clearSessionId = () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(SESSION_ID_KEY)
    }
    setSessionId(null)
  }

  return {
    status,
    subscriptionId,
    customerId,
    isLoading,
    sessionId,
    saveSessionId,
    clearSessionId,
  }
}
