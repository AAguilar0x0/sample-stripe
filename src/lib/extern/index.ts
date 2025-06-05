import { StripeService } from './payment/stripe'
import { AuthRepo } from '@/lib/extern/db/supabase/auth-repo'
import { env } from '@/lib/env/server'

export class MyServiceProvider {
  private authRepo?: AuthRepo
  private payment?: StripeService

  AuthRepo() {
    if (!this.authRepo) {
      this.authRepo = new AuthRepo()
    }
    return this.authRepo
  }

  Payment() {
    if (!this.payment) {
      this.payment = new StripeService(env.STRIPE_SECRET_KEY, env.STRIPE_WEBHOOK_SECRET)
    }
    return this.payment
  }
}
