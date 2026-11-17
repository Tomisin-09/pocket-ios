'use client'

import { useEffect, useRef, useState, type ReactNode } from 'react'

/**
 * A row of screens you swipe through (or step with the arrows on a desktop). Scrolling and snapping are
 * plain CSS; this only drives the two buttons and greys them out at either end.
 */
export default function ShotRail({
  heading,
  label,
  children,
}: {
  heading: ReactNode
  label: string
  children: ReactNode
}) {
  const rail = useRef<HTMLUListElement>(null)
  const [atStart, setAtStart] = useState(true)
  const [atEnd, setAtEnd] = useState(false)

  useEffect(() => {
    const el = rail.current
    if (!el) return
    const update = () => {
      setAtStart(el.scrollLeft <= 4)
      setAtEnd(el.scrollLeft + el.clientWidth >= el.scrollWidth - 4)
    }
    update()
    el.addEventListener('scroll', update, { passive: true })
    window.addEventListener('resize', update)
    return () => {
      el.removeEventListener('scroll', update)
      window.removeEventListener('resize', update)
    }
  }, [])

  const step = (direction: 1 | -1) => {
    const el = rail.current
    if (!el) return
    const first = el.querySelector('li')
    const gap = parseFloat(getComputedStyle(el).columnGap) || 0
    const by = first ? first.getBoundingClientRect().width + gap : el.clientWidth * 0.8
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    el.scrollBy({ left: direction * by, behavior: reduce ? 'auto' : 'smooth' })
  }

  return (
    <>
      <div className="rm-rail-head">
        {heading}
        <div className="rm-rail-btns">
          <button type="button" onClick={() => step(-1)} disabled={atStart} aria-label="Previous screens">
            <Chevron flip />
          </button>
          <button type="button" onClick={() => step(1)} disabled={atEnd} aria-label="Next screens">
            <Chevron />
          </button>
        </div>
      </div>
      <ul ref={rail} className="rm-rail" aria-label={label}>
        {children}
      </ul>
    </>
  )
}

function Chevron({ flip = false }: { flip?: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width="18"
      height="18"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      style={flip ? { transform: 'scaleX(-1)' } : undefined}
    >
      <path d="M9 5l7 7-7 7" />
    </svg>
  )
}
