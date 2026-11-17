import fs from 'node:fs'
import path from 'node:path'
import { Marked } from 'marked'

/* The Red Moon Practice user manual, rendered from its markdown (ADR 0217, amending ADR 0165 D1).
 *
 * **The canonical copy lives in the app repo at `docs/manual/`.** `content/manual/` here is a
 * copy written by that repo's `scripts/export-manual.py`, and it is never edited by hand: a change
 * made here is overwritten by the next export, and until then the live page disagrees with its
 * source. `index.json` (page order and grouping) comes from the same script, parsed from the
 * manual's README, which is where the order lives.
 *
 * Figures follow their markers. A `<!-- shot: -->` comment becomes an image only when its PNG is in
 * `public/redmoon/manual/`, and the export puts one there only once it has been compared against
 * the current app. So a page ships as text and gains its figures as they are reviewed: a stale
 * figure contradicting the sentence beside it is worse than no figure.
 *
 * All of this runs at build time. Every page is static HTML, and `marked` never reaches a browser.
 */

export const BASE = '/manual'
/* Figures keep the address they had when this site shared a deployment with Deco Operations', so
 * the app repo's export writes them where it always has, and an old figure URL still resolves. */
const FIGURE_BASE = '/redmoon/manual'
const CONTENT = path.join(process.cwd(), 'content', 'manual')
const FIGURES = path.join(process.cwd(), 'public', 'redmoon', 'manual')

export type ManualPage = {
  key: string // 'looping', 'reference', 'reference/practice'
  route: string
  title: string
  description: string
  sections: string[] // HTML, one per `## ` section; the first may be the untitled intro
}

export type ManualGroup = {
  title: string
  pages: { route: string; title: string; goal: string }[]
}

export type Manual = { pages: Map<string, ManualPage>; groups: ManualGroup[] }

type IndexFile = {
  groups: { title: string; pages: { key: string; goal: string }[] }[]
}

type Link = { key: string; anchor: string }

/* Per-page state the renderer writes into while one page is being parsed. Rendering is synchronous
 * and one page at a time, so a module-level slot is enough. */
let current: { dir: string; key: string; ids: Set<string>; links: Link[] }

/* GitHub's heading-id rule, so the anchors the markdown already links to (`#the-kinds`) resolve
 * here as they do on GitHub: lower-case, drop everything but letters, digits, `_`, `-` and spaces,
 * then each space becomes a hyphen — which is why an em dash between two words leaves `--`.
 * Built with the constructor because the `u` flag is past this project's compile target. */
const NOT_IN_SLUG = new RegExp('[^\\p{L}\\p{M}\\p{N}\\p{Pc} -]', 'gu')

function headingId(html: string): string {
  const base = decode(html.replace(/<[^>]+>/g, ''))
    .toLowerCase()
    .replace(NOT_IN_SLUG, '')
    .replace(/ /g, '-')
  let id = base
  for (let n = 1; current.ids.has(id); n++) id = `${base}-${n}`
  current.ids.add(id)
  return id
}

function decode(text: string): string {
  return text
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
}

function escapeAttribute(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')
}

/** `looping.md` → `looping`, `reference/README.md` → `reference`, `README.md` → `` (the index). */
function keyFor(file: string): string {
  return file.replace(/\.md$/, '').replace(/(^|\/)README$/, '')
}

function routeFor(key: string): string {
  return key ? `${BASE}/${key}` : BASE
}

/* A link between pages is written as the relative `.md` path GitHub resolves, and becomes the
 * route it names. One that leaves the manual (an ADR, the app-store copy) has no public page, so it
 * keeps its words and loses the link rather than shipping a 404. */
function resolve(href: string): string | null {
  if (/^[a-z][a-z0-9+.-]*:/i.test(href)) return href
  const hash = href.indexOf('#')
  const file = hash < 0 ? href : href.slice(0, hash)
  const anchor = hash < 0 ? '' : href.slice(hash + 1)
  if (file === '') {
    current.links.push({ key: current.key, anchor })
    return `#${anchor}`
  }
  if (!file.endsWith('.md')) return null
  const target = path.posix.normalize(path.posix.join(current.dir, file))
  if (target.startsWith('../')) return null
  const key = keyFor(target)
  current.links.push({ key, anchor })
  return routeFor(key) + (anchor ? `#${anchor}` : '')
}

const marked = new Marked({
  gfm: true,
  renderer: {
    heading({ tokens, depth }) {
      const inner = this.parser.parseInline(tokens)
      return `<h${depth} id="${headingId(inner)}">${inner}</h${depth}>\n`
    },
    link({ href, tokens }) {
      const inner = this.parser.parseInline(tokens)
      const to = resolve(href)
      return to === null ? inner : `<a href="${escapeAttribute(to)}">${inner}</a>`
    },
  },
})

/* A marker reads `shot: slug | role: … | alt: … | state: …`, across as many lines as it likes. Only
 * `role` and `alt` matter here; `state`, `crop` and `device` are instructions to the shoot. */
function figureFor(comment: string): string | null {
  const fields = comment.split('|').map((field) => field.replace(/\s+/g, ' ').trim())
  const slug = /^shot: *(\S+)$/.exec(fields[0])?.[1]
  if (!slug) return null
  const file = `${slug.replace(/\//g, '-')}.png`
  if (!fs.existsSync(path.join(FIGURES, file))) return null
  const field = (name: string) =>
    fields.find((f) => f.startsWith(`${name}:`))?.slice(name.length + 1).trim() ?? ''
  const role = field('role') || 'screen'
  return (
    `<figure class="rm-manual-figure rm-manual-figure-${escapeAttribute(role)}">` +
    `<div class="rm-manual-shot"><img src="${FIGURE_BASE}/${file}" alt="${escapeAttribute(field('alt'))}" loading="lazy"></div>` +
    `</figure>`
  )
}

function plain(markdown: string): string {
  return markdown
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/[`*]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function summarise(text: string): string {
  if (text.length <= 160) return text
  return `${text.slice(0, 157).replace(/\s+\S*$/, '')}…`
}

function renderPage(file: string): { page: ManualPage; ids: Set<string>; links: Link[] } {
  const key = keyFor(file)
  const source = fs.readFileSync(path.join(CONTENT, file), 'utf8')

  // Comments go before marked sees the text: a shot marker becomes a placeholder paragraph (swapped
  // for its figure after rendering) or nothing, and every other comment — the `not-in-source:`
  // hatches, the count tripwires — is an instruction to a check, not prose.
  const figures: string[] = []
  const text = source.replace(/<!--([\s\S]*?)-->/g, (_, body: string) => {
    const figure = figureFor(body)
    if (!figure) return ''
    figures.push(figure)
    return `\n\n@@figure-${figures.length - 1}@@\n\n`
  })

  const lines = text.split('\n')
  const titleLine = lines.findIndex((line) => line.startsWith('# '))
  if (titleLine < 0) throw new Error(`manual: ${file} has no "# " title`)
  const chunks: string[][] = [[]]
  for (const line of lines.slice(titleLine + 1)) {
    if (line.startsWith('## ')) chunks.push([])
    chunks[chunks.length - 1].push(line)
  }

  current = { dir: path.posix.dirname(file), key, ids: new Set(), links: [] }
  const sections = chunks
    .map((chunk) => chunk.join('\n').trim())
    .filter(Boolean)
    .map((markdown) =>
      (marked.parse(markdown, { async: false }) as string)
        .replace(/<table>/g, '<table class="privacy-table rm-manual-table">')
        .replace(/<p>@@figure-(\d+)@@<\/p>/g, (_, i: string) => figures[Number(i)]),
    )

  const intro = chunks[0]
    .join('\n')
    .split(/\n\s*\n/)
    .map((paragraph) => paragraph.trim())
    .find((paragraph) => paragraph && !/^(@@|\||>|[-*] )/.test(paragraph))

  return {
    page: {
      key,
      route: routeFor(key),
      title: plain(lines[titleLine].slice(2)),
      description: summarise(plain(intro ?? '')),
      sections,
    },
    ids: current.ids,
    links: current.links,
  }
}

function markdownFiles(dir: string, prefix = ''): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const rel = prefix ? `${prefix}/${entry.name}` : entry.name
    if (entry.isDirectory()) return markdownFiles(path.join(dir, entry.name), rel)
    return entry.name.endsWith('.md') ? [rel] : []
  })
}

let cache: Manual | null = null

/* Renders every page once, then refuses to build a manual with a broken link, an anchor that names
 * no heading, or a page the index and the files disagree about — the build failing is the check. */
export function getManual(): Manual {
  if (cache) return cache
  const index = JSON.parse(fs.readFileSync(path.join(CONTENT, 'index.json'), 'utf8')) as IndexFile

  const pages = new Map<string, ManualPage>()
  const ids = new Map<string, Set<string>>()
  const links: (Link & { from: string })[] = []
  for (const file of markdownFiles(CONTENT)) {
    const rendered = renderPage(file)
    pages.set(rendered.page.key, rendered.page)
    ids.set(rendered.page.key, rendered.ids)
    links.push(...rendered.links.map((link) => ({ ...link, from: rendered.page.key })))
  }

  const problems: string[] = []
  for (const link of links) {
    if (link.key === '') continue
    const target = ids.get(link.key)
    if (!target) problems.push(`${link.from} links to "${link.key}", which is not a page`)
    else if (link.anchor && !target.has(link.anchor))
      problems.push(`${link.from} links to ${link.key}#${link.anchor}, which is not a heading there`)
  }
  const listed = new Set(index.groups.flatMap((group) => group.pages.map((page) => page.key)))
  for (const key of pages.keys()) if (!listed.has(key)) problems.push(`${key} is not in index.json`)
  for (const key of listed) if (!pages.has(key)) problems.push(`index.json lists ${key}, which has no page`)
  if (problems.length) throw new Error(`The manual does not render cleanly:\n  ${problems.join('\n  ')}`)

  const groups = index.groups.map((group) => ({
    title: group.title,
    pages: group.pages.map((entry) => {
      const page = pages.get(entry.key) as ManualPage
      return { route: page.route, title: page.title, goal: entry.goal }
    }),
  }))
  cache = { pages, groups }
  return cache
}
