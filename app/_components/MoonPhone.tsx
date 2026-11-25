'use client'

import type { StaticImageData } from 'next/image'
import { Phone } from './brand'
import { BLOOD, useWornMoon } from './moon'

/** One screen, shot in each of the app's eight moons, keyed by `MoonTheme`'s raw value. */
export type MoonShots = Record<string, StaticImageData>

/**
 * A screenshot in the phone frame, in the moon its page wears. The landing page's screens follow the
 * moon picked there; everywhere else they're Blood Moon.
 *
 * Only the picked moon's image is in the page, so a visitor downloads the moons they try, not all
 * eight. The `<img>` keeps its place and changes its source, so the browser goes on showing the last
 * moon's screen until the next one has loaded.
 */
export default function MoonPhone({
  shots,
  ...phone
}: { shots: MoonShots } & Omit<Parameters<typeof Phone>[0], 'src'>) {
  const moon = useWornMoon()
  return <Phone src={shots[moon] ?? shots[BLOOD]} {...phone} />
}
