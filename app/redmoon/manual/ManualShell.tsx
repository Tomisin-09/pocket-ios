import Link from 'next/link'
import type { ReactNode } from 'react'
import { RedMoonFooter, RedMoonNav } from '../_components/brand'
import { BASE } from './manual'

/* The frame every manual page shares, taken from the privacy page's prose layout — the beta guide
 * already reuses those classes, and the manual is the same kind of long-form reading. */
export default function ManualShell({
  title,
  isIndex = false,
  children,
}: {
  title: string
  isIndex?: boolean
  children: ReactNode
}) {
  return (
    <div className="rm-page">
      <RedMoonNav current="manual" />

      <main className="privacy-page">
        <div className="privacy-inner">
          <p className="section-label">
            {isIndex ? 'Manual' : <Link href={BASE}>Manual</Link>}
          </p>
          <h1 className="section-heading">{title}</h1>
          <p className="privacy-meta">Red Moon Practice</p>

          {children}

          <section className="privacy-section">
            <p>
              {!isIndex && <><Link href={BASE}>All manual pages</Link>. </>}
              Something not covered here? <Link href="/redmoon/support">Get in touch</Link> — we
              read every message.
            </p>
          </section>
        </div>
      </main>

      <RedMoonFooter />
    </div>
  )
}
