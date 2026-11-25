'use client'

import { createContext, useContext, useMemo, useState, type ComponentProps, type ReactNode } from 'react'

/**
 * The moon a visitor picks on the landing page (`MoonPicker`), kept for the rest of the visit.
 *
 * It lives in memory, in the root layout, which Next keeps mounted while you move between pages by
 * `<Link>`. So a visitor who picks a moon, reads the liner notes and comes back finds the landing page
 * still in their moon, and a reload or a new tab is Blood Moon again, like a fresh install. Nothing is
 * stored, on purpose: anyone opening a link, a preview or the press kit sees Blood Moon.
 *
 * Only the landing page wears it, by wrapping itself in `MoonPage`. Every other page stays Blood Moon,
 * nav included: the liner notes because they're the story of the song's red moon, the cream pages
 * (support, privacy, the beta guide) because they're for reading. They're not wrapped, so the logos
 * inside them read the default below.
 */

export const BLOOD = 'blood'

type Picked = { moon: string; pick: (id: string) => void }

const PickedMoon = createContext<Picked>({ moon: BLOOD, pick: () => {} })
/** The moon the page around a component wears: the picked one inside a `MoonPage`, Blood outside. */
const WornMoon = createContext<string>(BLOOD)

export function MoonProvider({ children }: { children: ReactNode }) {
  const [moon, pick] = useState(BLOOD)
  const value = useMemo(() => ({ moon, pick }), [moon])
  return <PickedMoon.Provider value={value}>{children}</PickedMoon.Provider>
}

export function usePickedMoon() {
  return useContext(PickedMoon)
}

/** The moon the page around a component wears: the picked one on the landing page, Blood elsewhere. */
export function useWornMoon() {
  return useContext(WornMoon)
}

/** A page that wears the picked moon: the landing page. Its accent tokens follow `data-moon`
 *  (globals.css, which defines them for `.rm-land` only); Blood Moon is no attribute at all. */
export function MoonPage({ className, children }: { className: string; children: ReactNode }) {
  const { moon } = usePickedMoon()
  return (
    <WornMoon.Provider value={moon}>
      <div className={className} data-moon={moon === BLOOD ? undefined : moon}>
        {children}
      </div>
    </WornMoon.Provider>
  )
}

/** A logo (`mark`, `wordmark`, `logo`) in a moon. Blood Moon's are the site's own files, which are the
 *  app's byte for byte; the other seven are the app's recoloured copies (`derive-brand-svgs.py --themes`). */
export function moonArt(art: string, moon: string) {
  return moon === BLOOD ? `/redmoon/${art}.svg` : `/redmoon/moons/${art}-${moon}.svg`
}

/** A logo in the moon its page wears. */
export function MoonArt({
  art,
  alt,
  ...img
}: { art: string; alt: string } & Omit<ComponentProps<'img'>, 'src' | 'alt'>) {
  const moon = useWornMoon()
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={moonArt(art, moon)} alt={alt} {...img} />
}
