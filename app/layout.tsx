import type { Metadata } from 'next'
import { Cormorant_Garamond, DM_Sans, Jost } from 'next/font/google'
import './globals.css'

const cormorant = Cormorant_Garamond({
  subsets: ['latin'],
  weight: ['300', '400', '500', '600'],
  style: ['normal', 'italic'],
  variable: '--font-cormorant',
})

const dmSans = DM_Sans({
  subsets: ['latin'],
  weight: ['300', '400', '500'],
  variable: '--font-dm-sans',
})

// Futura clone, used as the web fallback for the Red Moon pages' brand type
const jost = Jost({
  subsets: ['latin'],
  weight: ['300', '400', '500', '600', '700'],
  // Italic for the landing headline and the story lyric; a browser only fetches the faces a page uses.
  style: ['normal', 'italic'],
  variable: '--font-jost',
})

export const metadata: Metadata = {
  metadataBase: new URL('https://decooperations.co.uk'),
  title: 'Deco Operations — Digital Products & Consultancy',
  description:
    'Deco Operations builds digital products for independent businesses and offers hands-on AI consultancy to small teams. London.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${cormorant.variable} ${dmSans.variable} ${jost.variable}`}>
      <body>{children}</body>
    </html>
  )
}
