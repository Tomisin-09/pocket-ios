import type { Metadata } from 'next'
import Link from 'next/link'
import BetaGuide from './BetaGuide'

/* Closed-beta tester guide. Reached only by the link sent to the eight invited testers.
 *
 * **This is obscurity, not access control.** The URL is unguessable and the page is excluded from
 * indexing, but the copy ships in the client bundle and the acceptance gate is `localStorage`.
 * Anyone with the link can read it. That is the intended level: real auth would mean middleware,
 * an API route and a signed cookie on a branch that deploys straight to production with no CI, and
 * a bad middleware matcher would take `/redmoon/support` and `/privacy` down with it — both of
 * which App Review checks.
 *
 * Canonical copy lives in the app repo at `docs/beta/user-guide.md`; this is the port.
 */
export const metadata: Metadata = {
  title: 'Beta guide — Red Moon Practice',
  robots: { index: false, follow: false, nocache: true },
}

export default function RedMoonBetaGuidePage() {
  return (
    <div className="rm-page">
      <header className="topbar" style={{ position: 'relative' }}>
        <Link href="/redmoon" className="topbar-mark">Red Moon Practice Studio</Link>
      </header>

      <main className="privacy-page">
        <div className="privacy-inner">
          <p className="section-label">Closed beta</p>
          <h1 className="section-heading">Red Moon Practice</h1>
          <p className="privacy-meta">A guide for the eight of you</p>

          <BetaGuide />
        </div>
      </main>
    </div>
  )
}