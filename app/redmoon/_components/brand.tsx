import Image, { type StaticImageData } from 'next/image'
import Link from 'next/link'

// The pieces every Red Moon page shares: the nav, the footer, the store button and the phone frame.
// One place, so a page can't drift from the others.

// TODO (availability ON): the live App Store URL. Every store button on the site reads this one
// constant, so switching it on is a one-line change.
export const APP_STORE_URL = '#'

// Apple logo mark for the store button
function AppleMark() {
  return (
    <svg viewBox="0 0 384 512" fill="currentColor" aria-hidden="true">
      <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
    </svg>
  )
}

export function StoreButton() {
  return (
    <a href={APP_STORE_URL} className="rm-store-btn">
      <AppleMark />
      <span className="rm-store-labels">
        <span className="rm-store-small">Download on the</span>
        <span className="rm-store-big">App Store</span>
      </span>
    </a>
  )
}

type Place = 'story' | 'manual' | 'support' | 'privacy'

/** The bar at the top of every Red Moon page. Always dark, light pages included, so the site reads as
 *  one thing from page to page. `onLanding` keeps "Get the app" an in-page jump on the landing page. */
export function RedMoonNav({ current, onLanding = false }: { current?: Place; onLanding?: boolean }) {
  const item = (href: string, label: string, place: Place) => (
    <Link href={href} className="rm-hide-sm" aria-current={current === place ? 'page' : undefined}>
      {label}
    </Link>
  )
  return (
    <header className="rm-nav">
      <div className="rm-nav-inner">
        <Link href="/redmoon" className="rm-nav-brand" aria-label="Red Moon Practice Studio, home">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/redmoon/mark.svg" alt="" width={17} height={25} className="rm-nav-mark" />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/redmoon/wordmark.svg" alt="" width={77} height={15} className="rm-nav-word" />
        </Link>
        <nav className="rm-nav-links" aria-label="Red Moon">
          {item('/redmoon/story', 'Story', 'story')}
          {item('/redmoon/manual', 'Manual', 'manual')}
          {item('/redmoon/support', 'Support', 'support')}
          <a href={onLanding ? '#get' : '/redmoon#get'} className="rm-nav-cta">
            Get the app
          </a>
        </nav>
      </div>
    </header>
  )
}

export function RedMoonFooter() {
  return (
    <footer className="rm-footer">
      <div className="rm-footer-inner">
        <nav aria-label="More from Red Moon">
          <Link href="/redmoon/story">Story</Link>
          <Link href="/redmoon/manual">Manual</Link>
          <Link href="/redmoon/support">Support</Link>
          <Link href="/redmoon/privacy">Privacy</Link>
          <a
            href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
            target="_blank"
            rel="noopener noreferrer"
          >
            Terms of Use
          </a>
        </nav>
        <p>
          © 2026 <a href="https://decooperations.co.uk">Deco Operations Ltd</a> · London
        </p>
      </div>
    </footer>
  )
}

/** A screenshot in a thin phone frame. The captures are dark-appearance, on black, so on a black
 *  page the phone is the only edge: the frame is drawn, not photographed. */
export function Phone({
  src,
  alt,
  sizes,
  eager = false,
}: {
  src: StaticImageData
  alt: string
  sizes: string
  eager?: boolean
}) {
  return (
    <div className="rm-phone">
      <div className="rm-phone-body">
        <Image
          src={src}
          alt={alt}
          sizes={sizes}
          loading={eager ? 'eager' : 'lazy'}
          fetchPriority={eager ? 'high' : undefined}
        />
      </div>
    </div>
  )
}
