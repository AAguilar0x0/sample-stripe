import { Avatar, AvatarFallback } from '../components/ui/avatar'
import { CheckoutButton } from '../components/checkout-button'
import { trpc } from '@/lib/trpc/server'

export default async function HomePage() {
  try {
    const accountData = await trpc.auth.getAccountData()

    return (
      <main className='container mx-auto p-4'>
        <div className='rounded-lg border p-4 shadow-sm'>
          <h1 className='mb-4 text-2xl font-bold'>Account Data</h1>
          <div className='space-y-4'>
            <div className='flex items-center gap-4'>
              <Avatar>
                <AvatarFallback>{accountData.name.slice(0, 2).toUpperCase()}</AvatarFallback>
              </Avatar>
              <h2 className='text-xl font-semibold'>{accountData.name}</h2>
            </div>
            <div className='grid grid-cols-[100px_1fr] gap-2 text-sm'>
              <span className='font-medium text-muted-foreground'>ID:</span>
              <span>{accountData.id}</span>
              <span className='font-medium text-muted-foreground'>Email:</span>
              <span>{accountData.email}</span>
            </div>
          </div>
          <div className='mt-4 flex justify-end'>
            <CheckoutButton />
          </div>
        </div>
      </main>
    )
  } catch (error) {
    return (
      <main className='container mx-auto p-4'>
        <div className='rounded-lg border border-destructive p-4 text-destructive'>
          <h1 className='mb-4 text-2xl font-bold'>Error</h1>
          <p>{error instanceof Error ? error.message : 'Unknown error'}</p>
        </div>
      </main>
    )
  }
}
