import type { Metadata } from 'next'
import type { ReactNode } from 'react'

// Every /redmoon page is Red Moon's, on either host, so its canonical home is Red Moon's own domain:
// link previews, og:image and canonical URLs resolve against it. /privacy-on-decooperations keeps
// the root layout's metadataBase.
export const metadata: Metadata = {
  metadataBase: new URL('https://www.redmoonpracticestudio.co.uk'),
}

export default function RedMoonLayout({ children }: { children: ReactNode }) {
  return children
}
