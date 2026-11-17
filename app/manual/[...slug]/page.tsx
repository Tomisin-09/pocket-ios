import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import ManualShell from '../ManualShell'
import { getManual } from '../manual'

/* One route for every manual page: `/manual/<slug>` and `/manual/reference/<slug>`,
 * one per markdown file (ADR 0165 D2). Only the pages the export copied in exist; anything else is a
 * 404 rather than a render attempt. */
export const dynamicParams = false

type Params = { params: Promise<{ slug: string[] }> }

export function generateStaticParams() {
  return [...getManual().pages.keys()].filter(Boolean).map((key) => ({ slug: key.split('/') }))
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const key = (await params).slug.join('/')
  const page = getManual().pages.get(key)
  if (!page) return {}
  return {
    title: `${page.title} — Red Moon Practice manual`,
    description: page.description,
    alternates: { canonical: `/manual/${key}` },
  }
}

export default async function RedMoonManualPage({ params }: Params) {
  const page = getManual().pages.get((await params).slug.join('/'))
  if (!page) notFound()
  return (
    <ManualShell title={page.title}>
      {page.sections.map((html, i) => (
        <section className="privacy-section" key={i} dangerouslySetInnerHTML={{ __html: html }} />
      ))}
    </ManualShell>
  )
}
