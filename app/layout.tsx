import type { Metadata } from 'next'
import { Cormorant_Garamond, DM_Sans, Jost } from 'next/font/google'
import { MoonProvider } from './_components/moon'
import './globals.css'

// The three faces the pages used when they shared a deployment with Deco Operations' site, kept as
// they were so nothing re-renders. Futura itself is a system font on Apple devices (see
// `--font-futura`); Jost is its web fallback. Cormorant and DM Sans are still reached by a few shared
// prose rules that `.rm-page` doesn't re-point (`.privacy-table th`, for one).
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

// Futura clone, used as the web fallback for the brand type
const jost = Jost({
  subsets: ['latin'],
  weight: ['300', '400', '500', '600', '700'],
  // Italic for the landing headline and the story lyric; a browser only fetches the faces a page uses.
  style: ['normal', 'italic'],
  variable: '--font-jost',
})

// Link previews, og:image and canonical URLs resolve against the site's own domain. A page that sets
// none of its own (the beta guide, a 404) gets Red Moon's name, not another company's.
export const metadata: Metadata = {
  metadataBase: new URL('https://www.redmoonpracticestudio.co.uk'),
  title: 'Red Moon Practice Studio',
  description: 'Red Moon is a practice studio for guitar and bass players, for iPhone.',
}

// The moon picked on the landing page lives here, so it's still there when a visitor comes back to
// the landing page from another page, until a reload (`_components/moon.tsx`).
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${cormorant.variable} ${dmSans.variable} ${jost.variable}`}>
      <body>
        <MoonProvider>{children}</MoonProvider>
      </body>
    </html>
  )
}
