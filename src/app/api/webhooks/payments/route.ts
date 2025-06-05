import { NextRequest, NextResponse } from 'next/server'
import { MyControllerFactory } from '@/lib/core/controllers'
import { MyServiceProvider } from '@/lib/extern'

export async function POST(request: NextRequest) {
  try {
    const signature = request.headers.get('stripe-signature')
    if (!signature) {
      return new NextResponse('No signature found', { status: 400 })
    }

    const services = new MyServiceProvider()
    const controller = new MyControllerFactory(services)

    await controller.Subscription().handleWebhook()

    return new NextResponse('Webhook processed successfully', { status: 200 })
  } catch (error) {
    console.error('Webhook error:', error)
    return new NextResponse(
      'Webhook error: ' + (error instanceof Error ? error.message : 'Unknown error'),
      { status: 400 },
    )
  }
}
