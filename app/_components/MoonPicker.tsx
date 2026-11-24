'use client'

import Image, { type StaticImageData } from 'next/image'
import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from 'react'

/** A logo (`mark`, `wordmark`, `logo`) in a moon. Blood Moon's are the site's own files, which are the
 *  app's byte for byte; the other seven are the app's recoloured copies (`derive-brand-svgs.py --themes`). */
function moonArt(art: string, moon: string) {
  return moon === 'blood' ? `/redmoon/${art}.svg` : `/redmoon/moons/${art}-${moon}.svg`
}

export type Moon = {
  /** `MoonTheme`'s raw value in the app: `blood`, `jade`, … It names the art in /redmoon/moons/. */
  id: string
  /** The short name under its swatch. The full name is "<name> Moon". */
  name: string
  home: StaticImageData
  icon: StaticImageData
}

/**
 * The app's eight moon themes (pocket-ios ADRs 0311, 0312, 0314), tried on the page. Picking one swaps
 * the phone to Home in that moon and the icon beside it, and the landing page wears it too: its accent
 * tokens follow `data-moon` on `.rm-land` (globals.css), and the logos marked `data-moon-art` take that
 * moon's copy. Nothing is stored, so a reload is Blood Moon again, like a fresh install.
 */
export default function MoonPicker({ moons, children }: { moons: Moon[]; children: ReactNode }) {
  const [current, setCurrent] = useState(0)
  const swatches = useRef<Array<HTMLButtonElement | null>>([])
  const moon = moons[current]

  useEffect(() => {
    const page = document.querySelector<HTMLElement>('.rm-land')
    if (!page) return
    if (moon.id === 'blood') delete page.dataset.moon
    else page.dataset.moon = moon.id
    document.querySelectorAll<HTMLImageElement>('img[data-moon-art]').forEach((img) => {
      const next = moonArt(img.dataset.moonArt ?? '', moon.id)
      if (img.getAttribute('src') !== next) img.src = next
    })
  }, [moon.id])

  // A radio group: one tab stop, and the arrow keys move the choice, as they do in any set of radios.
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key]
    let next: number | undefined
    if (step !== undefined) next = (current + step + moons.length) % moons.length
    else if (event.key === 'Home') next = 0
    else if (event.key === 'End') next = moons.length - 1
    if (next === undefined) return
    event.preventDefault()
    setCurrent(next)
    swatches.current[next]?.focus()
  }

  return (
    <section className="rm-moons" aria-labelledby="rm-moons-title">
      <div className="rm-moons-text reveal">
        {children}
        <div className="rm-moons-swatches" role="radiogroup" aria-label="Moons" onKeyDown={onKeyDown}>
          {moons.map((m, i) => (
            <button
              key={m.id}
              ref={(el) => {
                swatches.current[i] = el
              }}
              type="button"
              role="radio"
              aria-checked={i === current}
              aria-label={`${m.name} Moon`}
              tabIndex={i === current ? 0 : -1}
              className="rm-moon-swatch"
              onClick={() => setCurrent(i)}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={moonArt('mark', m.id)} alt="" width={22} height={32} />
              <span aria-hidden="true">{m.name}</span>
            </button>
          ))}
        </div>
        <p className="rm-moons-note">Blood Moon is free. The other seven come with the plan.</p>
      </div>

      <div className="rm-moons-media reveal">
        <div className="rm-phone">
          <div className="rm-phone-body">
            <div className="rm-moons-stack">
              {moons.map((m, i) => (
                <Image
                  key={m.id}
                  src={m.home}
                  alt={`Red Moon’s home screen in ${m.name} Moon.`}
                  aria-hidden={i !== current}
                  data-on={i === current ? '' : undefined}
                  sizes="(max-width: 820px) 72vw, 340px"
                />
              ))}
            </div>
          </div>
        </div>
        <div className="rm-moons-icon" aria-hidden="true">
          {moons.map((m, i) => (
            <Image key={m.id} src={m.icon} alt="" data-on={i === current ? '' : undefined} sizes="88px" />
          ))}
        </div>
      </div>
    </section>
  )
}
