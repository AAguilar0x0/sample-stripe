import { env } from '@/lib/env/server'
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  out: './src/lib/extern/db/drizzle/migrations',
  schema: './src/lib/extern/db/drizzle/schemas.ts',
  dialect: 'postgresql',
  dbCredentials: {
    url: env.DATABASE_URL,
  },
})
