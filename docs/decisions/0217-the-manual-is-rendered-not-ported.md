# ADR 0217 — the manual is rendered, not ported

- **Status:** Accepted — built (2026-09-11): `scripts/export-manual.py` on `pocket-321-manual-pipeline`,
  the route on the site repo's `decops-062-manual-pipeline`. Live once that merges into `uk-site`.
- **Date:** 2026-09-11
- **Amends:** ADR 0165 — D1's *port* becomes a build-time render of an exported copy rather than a
  hand-written route per page (D1, D2 here), and D7's figures publish only once reviewed (D4 here).
  D2–D6, the marker grammar and every check stand.
- **Relates to:** ADR 0133 (why the site's publish step is a person, not a CI job — the same
  no-staging reasoning, from the other side)

## Context

ADR 0165 made the site a rendering target and left *how* it renders open. The first page went
across on 2026-09-01 as hand-written JSX (`app/redmoon/manual/references/page.tsx`, site PR #73),
and the page showed what that costs:

- **It was twice the size of its source** — 15KB of JSX for 8KB of markdown — for one page of
  twenty.
- **It needed re-porting the same day.** ADR 0185 changed the prose hours after the port, and the
  JSX had to be edited by hand to follow. A hand-kept copy is a second writer, which is the thing
  0165 D1 exists to prevent; it only moves the second writer from the site's prose to its markup.
- **It never merged.** Ten days later #73 was still open and nothing of the manual was live.

The figures had the matching problem. The shoot filed a `references/section` image that was
correct when taken and wrong a week later, and the only thing that kept it off the site was
somebody remembering to leave it out of the port by hand.

## Decision

### D1 — the site renders a copy of `docs/manual/`, at build time

`scripts/export-manual.py <site-checkout>` writes every published page (all of `docs/manual/`
except `README.md` and `shots.md`) into the site's `content/manual/`. One route family renders all
of them: `app/redmoon/manual/page.tsx` (the contents) and `app/redmoon/manual/[...slug]/page.tsx`
(every page, one per file, as 0165 D2 requires). Markdown becomes HTML with `marked`, during the
build only; every page is static and nothing is parsed in a browser.

### D2 — the copy is never edited in the site

The export replaces `content/manual/` wholesale, so a hand edit there is overwritten by the next
one. The contents page's order and grouping come from `index.json`, which the export parses from
the `| Page |` tables in `docs/manual/README.md` — still the one place the order lives. `index.json`
records the commit the copy came from, so what is live can always be traced to a source.

### D3 — the build is a check

The site build fails on a link to a page that does not exist, on an `#anchor` that names no heading,
and on any page that `index.json` and the files disagree about. Anchors use GitHub's heading-id
rule, so a link that works on GitHub works on the site. The first build found one broken anchor
that had been live in the markdown since it was written (`routines` → `toolkit#the-tuner`; the
heading is `Tuner`). `check-manual.py` does not check anchors, so today this surfaces at export
rather than at push.

### D4 — a figure publishes by review, and text does not wait for it

A `<!-- shot: -->` marker renders as an image only when its PNG is present in the site's
`public/redmoon/manual/`; otherwise it renders as nothing. The export touches that directory only
when given `--figures FILE`, and then makes it hold exactly the slugs listed: taken from
`shots/figures/`, narrowed to 640px and never widened. The list holds figures somebody has
compared against the current app. So a page goes live as text and gains its figures as they are
reviewed, and withdrawing a figure is deleting a line.

### D5 — going live stays a person's step

The export commits nothing and pushes nothing, in either repo. `uk-site` deploys to production on
every push with no staging gate, so publishing remains a deliberate push of a reviewed branch, and
a pull request gets a Vercel preview to read first.

## Alternatives considered

- **Keep hand-porting.** Rejected for the three reasons in Context. Its one argument, no new
  dependency on a branch that deploys to production, is answered by D1: `marked` is exact-pinned,
  has no dependencies of its own, and runs only in the build.
- **MDX.** It would turn the canonical markdown into site syntax, or need a second copy that is —
  and the marker comments are already the grammar the shoot and `check-manual.py` read.
- **Fetch from GitHub at request time.** The app repo is private, so the site would hold a token,
  and every page view would depend on another service being up.
- **A CI job that exports and pushes.** It would write to a production-deploying branch with no
  person in the loop — D5's whole point.

## Consequences

- One dependency in the site, `marked` 18.0.12, exact-pinned, build-time only.
- 0165 D7's `call:` callouts (SVG at port time) and theme-paired `<picture>` output are **not built**.
  No marker carries `call:` today, and every figure is `theme: dark`; the first figure to need
  either adds it to the renderer.
- Only the `screen` role has a display width in the site's CSS. Each other role gets one when its
  first figure publishes — the rule the hand-port already followed.
- Site PR #73 closes unmerged; this renders `references` too.
- The `CHANGELOG.md` entry 0165 deferred until *the manual ports* lands with this.
- A later candidate: an anchor check in `check-manual.py`, so D3's failure surfaces at push, where
  a docs-only change is checked, instead of at export.
