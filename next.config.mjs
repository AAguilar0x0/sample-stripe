/** @type {import('next').NextConfig} */
import { fileURLToPath } from 'node:url'
import { createJiti } from 'jiti'
const jiti = createJiti(fileURLToPath(import.meta.url))

await jiti.import('./src/lib/env/server')
await jiti.import('./src/lib/env/client')
const nextConfig = {
  images: {
    unoptimized: process.env.VERCEL_ENV !== 'production',
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'hmpemfjgqpfpwjivikwz.supabase.co',
      },
      {
        protocol: 'https',
        hostname: 'msfzudfrogvuubnfrcin.supabase.co',
      },
      {
        protocol: 'http',
        hostname: '127.0.0.1',
      },
      {
        protocol: 'http',
        hostname: 'localhost',
      },
    ],
  },
  rewrites: async () => {
    return [
      {
        source: '/@:handle',
        destination: '/business/:handle',
      },
      {
        source: '/@:handle/catalog/:identifier',
        destination: '/business/:handle/catalog/:identifier',
      },
      {
        source: '/admin/@:handle',
        destination: '/admin/business/:handle',
      },
    ]
  },
}

export default nextConfig
