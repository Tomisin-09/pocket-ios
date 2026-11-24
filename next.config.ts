import type { NextConfig } from 'next'

// The pages answer at the root: /support, /story, /privacy, /manual/..., /beta/....
//
// Until ADR 0306 they lived under /redmoon/ in a deployment shared with Deco Operations' site, and a
// host rewrite served them at the root here. These redirects keep any /redmoon/... page address that
// was typed, bookmarked or hard-coded landing on the page it meant. Apart from the four generated
// files at the end, they are PAGE addresses only:
// the images, the starter track and the manual's figures are still served from /redmoon/... (the
// app repo's export writes figures to public/redmoon/manual/), so nothing may catch them. That is why
// the beta guide is redirected by its exact address and the manual's pattern refuses anything with
// a dot in it: no page slug has one, and every figure does.
//
// Temporary (307), as they were before the move. Make them permanent in their own change.
const MOVED: Array<[string, string]> = [
  ['/redmoon', '/'],
  ['/redmoon/support', '/support'],
  ['/redmoon/story', '/story'],
  ['/redmoon/privacy', '/privacy'],
  ['/redmoon/manual', '/manual'],
  ['/redmoon/manual/:path([^.]+)', '/manual/:path'],
  ['/redmoon/beta/14675668e46224e5773801fc', '/beta/14675668e46224e5773801fc'],
  // Not pages, but generated from app/ like them, so they moved to the root too. A link preview
  // already made elsewhere keeps the og:image address it was given, query string included.
  ['/redmoon/opengraph-image', '/opengraph-image'],
  ['/redmoon/twitter-image', '/twitter-image'],
  ['/redmoon/icon.png', '/icon.png'],
  ['/redmoon/apple-icon.png', '/apple-icon.png'],
]

// The manual is off the site while how it should work is rethought (Tomisin, 2026-11-24): its
// figures are still the old blue, and it had drifted behind the app. Its pages still build from
// `content/manual/`, so the export from `main` keeps working, and bringing it back is deleting
// HIDDEN and putting the nav and footer links back (`app/_components/brand.tsx`). Nothing the app
// ships links here; the old /redmoon/manual addresses above now end on Support through this.
// Temporary (307) on purpose: the manual is coming back.
const HIDDEN: Array<[string, string]> = [
  ['/manual', '/support'],
  ['/manual/:path*', '/support'],
]

const nextConfig: NextConfig = {
  async redirects() {
    return [...MOVED, ...HIDDEN].map(([source, destination]) => ({
      source,
      destination,
      permanent: false,
    }))
  },
}

export default nextConfig
