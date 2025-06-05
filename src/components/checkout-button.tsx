'use client'

import { ShoppingCart } from 'lucide-react'
import { useState } from 'react'
import { Button } from './ui/button'
import { trpc } from '@/lib/trpc/client'
import { useSubscriptionStatus } from '@/hooks/use-subscription-status'

export function CheckoutButton() {
  const [sessionId, setSessionId] = useState<string | null>(null)
  const createCheckoutSession = trpc.subscriptions.createCheckoutSession.useMutation()
  const { status, isLoading, saveSessionId } = useSubscriptionStatus(sessionId)

  const handleCheckout = async () => {
    try {
      const session = await createCheckoutSession.mutateAsync()
      if (session.url) {
        saveSessionId(session.id)
        setSessionId(session.id)
        window.location.href = session.url
      }
    } catch (error) {
      console.error('Failed to create checkout session:', error)
    }
  }

  if (isLoading) {
    return (
      <Button disabled className='gap-2'>
        <ShoppingCart className='h-4 w-4' />
        Checking Status...
      </Button>
    )
  }

  if (status === 'active') {
    return (
      <Button disabled className='gap-2 bg-green-600 hover:bg-green-700'>
        <ShoppingCart className='h-4 w-4' />
        Subscription Active
      </Button>
    )
  }

  return (
    <Button onClick={handleCheckout} className='gap-2'>
      <ShoppingCart className='h-4 w-4' />
      Upgrade Plan
    </Button>
  )
}
