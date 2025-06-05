import type { Metadata } from 'next'
import './globals.css'
import { TRPCProvider } from '@/common/providers/trpc-provider'

export const metadata: Metadata = {
  title: 'Vectle - AI Optimization for Businesses',
  description:
    'Vectle helps you track and optimize your business for AI so customers can find you and when thet have a problem you can sovle',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang='en'>
      <body className={`bg-background antialiased`}>
        <TRPCProvider>{children}</TRPCProvider>
      </body>
    </html>
  )
}
