import type { Metadata, Viewport } from 'next'
import './globals.css'
import { PwaRegister } from './pwa-register'

export const metadata: Metadata = {
  title: 'Rembayung Access',
  description: 'Fair-access booking invitation layer for Rembayung.',
  manifest: '/manifest.webmanifest',
  icons: {
    icon: '/icon.svg'
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'Rembayung Access'
  }
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#171717'
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ms">
      <body>
        <PwaRegister />
        {children}
      </body>
    </html>
  )
}
