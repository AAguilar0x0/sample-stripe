import { useRouter } from 'next/navigation'
import { useSubscriptionStatus } from '@/hooks/use-subscription-status'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'

type SubscriptionCheckProps = {
  children: React.ReactNode
}

export function SubscriptionCheck({ children }: SubscriptionCheckProps) {
  const { status, isLoading } = useSubscriptionStatus()
  const router = useRouter()

  if (isLoading) {
    return (
      <div className='flex min-h-[200px] items-center justify-center'>
        <div className='h-8 w-8 animate-spin rounded-full border-b-2 border-primary' />
      </div>
    )
  }

  // If subscription is not active, show upgrade plan
  if (status !== 'active' && status !== 'trialing') {
    return (
      <Card className='mx-auto max-w-md'>
        <CardHeader>
          <CardTitle>Upgrade Your Plan</CardTitle>
          <CardDescription>
            Subscribe to access premium features and unlock your full potential
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ul className='space-y-2'>
            <li className='flex items-center gap-2'>
              <span className='text-primary'>✓</span>
              <span>Access to all premium features</span>
            </li>
            <li className='flex items-center gap-2'>
              <span className='text-primary'>✓</span>
              <span>Priority support</span>
            </li>
            <li className='flex items-center gap-2'>
              <span className='text-primary'>✓</span>
              <span>Advanced analytics</span>
            </li>
          </ul>
        </CardContent>
        <CardFooter>
          <Button className='w-full' onClick={() => router.push('/pricing')}>
            View Plans
          </Button>
        </CardFooter>
      </Card>
    )
  }

  // If subscription is active, render children
  return <>{children}</>
}
