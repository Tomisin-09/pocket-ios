import { ImageResponse } from 'next/og'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'

// Social share card for all Red Moon pages: the blood-moon lockup on a warm night sky.
// Text-free by design, so no font loading is needed. The lockup is the app's own vector
// (pocket-ios scripts/derive-brand-svgs.py), 512 × 450.
export const alt = 'Red Moon — give practice a home'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image() {
  const logo = await readFile(join(process.cwd(), 'public/redmoon/logo.svg'))
  const logoSrc = `data:image/svg+xml;base64,${logo.toString('base64')}`

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'radial-gradient(90% 90% at 50% 45%, #2A120A 0%, #0D0604 48%, #000000 100%)',
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={logoSrc} width={420} height={369} alt="" />
      </div>
    ),
    size,
  )
}
