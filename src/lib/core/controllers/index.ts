import { MyServiceProvider } from '@/lib/extern'
import { AuthController } from '@/lib/core/controllers/auth'
import { SubscriptionsController } from '@/lib/core/controllers/subscriptions'

export class MyControllerFactory {
  services: MyServiceProvider
  constructor(services: MyServiceProvider) {
    this.services = services
  }

  Auth() {
    return new AuthController(this.services.AuthRepo())
  }

  Subscription() {
    return new SubscriptionsController(this.services.Payment())
  }
}
