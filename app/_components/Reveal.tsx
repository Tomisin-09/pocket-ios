'use client'

import { useEffect } from 'react'

/**
 * Wires up the shared `.reveal` scroll-in observer (same mechanism as the main site) for the Red
 * Moon landing page and the story's essay. Renders nothing.
 */
export default function Reveal() {
  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const reveals = Array.from(document.querySelectorAll('.reveal'))
    if (reduce || !('IntersectionObserver' in window)) {
      reveals.forEach((el) => el.classList.add('in'))
      return
    }
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add('in')
            io.unobserve(e.target)
          }
        })
      },
      { rootMargin: '0px 0px -12% 0px', threshold: 0.08 },
    )
    reveals.forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [])

  return null
}
