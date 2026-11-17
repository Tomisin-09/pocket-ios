import type { Metadata } from 'next'
import Link from 'next/link'
import ManualShell from './ManualShell'
import { getManual } from './manual'

/* The manual's contents page. Its order and grouping are not written here: they come from
 * `index.json`, which the export generates from the manual's own README (see `manual.ts`). */
export const metadata: Metadata = {
  alternates: { canonical: '/manual' },
  title: 'Red Moon Practice manual',
  description:
    'How to use Red Moon Practice, one task at a time, and a reference that names every control on every screen.',
}

export default function RedMoonManualIndexPage() {
  const { groups } = getManual()
  return (
    <ManualShell title="The manual" isIndex>
      <section className="privacy-section">
        <p>
          How to use Red Moon Practice, one task at a time. The reference pages at the end name every
          control on every screen.
        </p>
      </section>

      {groups.map((group) => (
        <section className="privacy-section" key={group.title}>
          <h2>{group.title}</h2>
          <ul>
            {group.pages.map((page) => (
              <li key={page.route}>
                <Link href={page.route}>{page.title}</Link> — {page.goal}
              </li>
            ))}
          </ul>
        </section>
      ))}
    </ManualShell>
  )
}
