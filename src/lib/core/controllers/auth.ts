import { AuthRepo } from '@/lib/extern/db/supabase/auth-repo'

export class AuthController {
  constructor(private authRepo: AuthRepo) {}

  async getCurrentUser() {
    return this.authRepo.getCurrentUser()
  }
}
