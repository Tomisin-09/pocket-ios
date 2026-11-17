# ADR 0306 — Red Moon's site moves into this repo, on a branch of its own

- **Status:** Accepted on 2026-11-17 by Tomisin, who chose the branch over a folder on `main` and to
  move before 1.4.1 (11) clears App Review, taking the risk of a support or privacy URL faltering
  during review. Built the same day: the `site` branch's root commit, and the import on
  `pocket-442-site-import` (D4). Going live waits on the Vercel project and the domain move (D3),
  which are dashboard steps for Tomisin.
- **Date:** 2026-11-17
- **Amends:** ADR 0217 — the copy that D1 exports and D2 forbids editing now lives in this repo's
  `site` branch, not `laundry-pickup-project@uk-site`, and the pages answer at `/manual/…`, not
  `/redmoon/manual/…`. D5's reasoning stands with `site` where it says `uk-site`, and a pull request
  into `site` is now the gate: a push to a work branch no longer publishes. D1–D4 otherwise stand.
- **Relates to:** ADR 0165 (the manual quotes the app; the site renders it) · ADR 0133 (why `main`'s
  CI must not grow a paths filter; this keeps the site out of `main` altogether instead) ·
  ADR 0292 (the Blood Moon tokens the site takes from the app)

## Context

Red Moon's website has lived in someone else's house. It is a Next.js app on the `uk-site` branch of
`laundry-pickup-project`, the Docket repository, beside Deco Operations' own site. One Vercel
deployment serves both companies: since 2026-11-16 (`uk-site` #79), `next.config.ts` rewrites
`www.redmoonpracticestudio.co.uk/support` to `/redmoon/support` by host, and `decooperations.co.uk`
keeps its own pages.

That arrangement has cost something each time the app changed what it says. Every product claim on
the site has to be carried across repos by hand, and the privacy text has drifted four times
(the site understating what the app sends, every time). The manual already crosses that gap by
export (ADR 0217), into a checkout of a repo named after a laundry service. And the shared
deployment couples the two companies: Red Moon's pages borrow Deco's stylesheet, and a change to
either site redeploys both.

`uk-site`'s own arrangement, a branch with no history in common with the application on `main`,
has worked. What changes is whose repository holds it.

## Decision

### D1 — the site lives in this repo, on a branch named `site`

`site` shares no history with `main`, as `uk-site` shares none with Docket's `main`. It holds the
Next.js app at its root and nothing of the iOS app; `main` holds nothing of the site. The site's
decisions are recorded here on `main`, with the others.

### D2 — `site` is production, and a pull request is the way in

Vercel deploys every push to `site`. Work reaches it by pull request from a `pocket-0XX` branch cut
from `site` (one ticket sequence for the repo), and the PR gets a Vercel preview. The branch's own
check (`Build · Check`, D6) runs on every PR into `site` and every push to it, and branch
protection on `site` requires it. That is a gate `uk-site` never had: there, a push was a release.

### D3 — its own Vercel project, and the domain moves to it

A new Vercel project builds this repo with `site` as its production branch. Its Ignored Build Step
is `[ ! -f package.json ]`, which skips any branch without a site in it, so the app's branches never
produce a failed preview. `www.redmoonpracticestudio.co.uk` and the apex (which redirects to `www`)
move from Deco Operations' project to this one. DNS at IONOS should not change; Vercel says so when
it does.

The order is fixed, because until the move Deco's project *is* the live Red Moon site: import →
Vercel project and preview → merge into `site` → move the domains → verify live with `curl` →
only then remove Red Moon from `uk-site` (D7).

### D4 — the pages answer at the root, and every public address still works

The import (`pocket-442-site-import`) takes Red Moon's files from `uk-site` @ `31cc52b` unchanged in
one commit, then adapts them in the next, so that diff is the whole of the move: `app/redmoon/*`
becomes `app/*`, the host rewrites go, and `globals.css` keeps only the rules Red Moon's pages use.
Every public path stays: `/`, `/support`, `/story`, `/privacy`, `/manual/…`, the beta guide and its
frozen section anchors. A `/redmoon/…` page address redirects to its clean path (307, as before).
Assets keep their `/redmoon/…` addresses, so the export's figure directory (`public/redmoon/manual/`)
and any asset URL already in the wild are untouched. Before it was committed, the import was checked
against the live site: every page route (the six top-level pages and all 19 manual pages) gives the
same status as live, the icons, share card, favicon,
logo and starter track are byte-identical, and nine pages at 1280 and 390 px wide differ from live by
zero pixels.

### D5 — the manual stays an export

`scripts/export-manual.py` writes into a checkout of `site` instead of `laundry-pickup-project`.
Nothing else in ADR 0217 changes: `main`'s manual describes the next release while the live site
describes the App Store's, so publishing stays a deliberate export, then a PR into `site`.

### D6 — the branch carries its own checks and instructions

- `scripts/check.sh`: the build (which already fails on a dead manual link or anchor, ADR 0217 D3),
  then two scans of the rendered HTML: words joined to a closing tag (`</strong>—`), and
  *Red Moon, never Pocket*. Each scan first checks it has pages to read. Both were shown to catch a
  planted fault before they were trusted.
- `.github/workflows/site.yml` runs it. A PR into `site` runs only the workflows on `site`, so
  `main`'s CI never sees the site and needs no change.
- `scripts/pre-push.sh`: the repo's hook runs `scripts/pre-push.sh` from whichever checkout pushes,
  so the site's own file is what runs for the site. Without it, every push from a `site` checkout
  would fail.
- `AGENTS.md` (and `CLAUDE.md`), so a session in a `site` checkout gets the site's rules, not the
  iOS checklist.

### D7 — what stays on Deco Operations' site, for good

After the move is verified, one PR into `uk-site` removes Red Moon's pages, styles, manual copy and
host rules. It keeps, permanently:

- the redirects from `decooperations.co.uk/redmoon/…` to the new domain, since the beta guide's
  link went to eight testers on that host. Asset paths redirect to the same path on the new domain;
- the stub section with `id="red-moon-practice"` in Deco's `/privacy`, because 1.4 and 1.4.1 link
  to `decooperations.co.uk/privacy#red-moon-practice` (`AboutSection.swift`), and a phone running
  either may never update;
- Deco's landing page card for Red Moon, with its own copy of the wordmark and a link to the new
  domain.

## Alternatives not taken

- **A `site/` folder on `main`, with a gated production branch.** It would let one PR change an app
  claim and the site's wording together, which is the drift this ADR names. But `main`'s CI would
  have to learn a third kind of change (ADR 0133's single rule in `docs-only.sh`), every app branch
  would carry a Node project, and release-gating the site would need a production branch anyway.
  Tomisin chose the separation `uk-site` already had.
- **Stay in `laundry-pickup-project`.** Works today; leaves the coupling in Context.
- **A new repository.** A third place to keep in step, with nothing gained over a branch here.
- **Keep the `/redmoon/` prefix for pages on the new host.** It would avoid the redirects, but the
  clean addresses are the ones the new domain has shown in the address bar since it went live on
  2026-11-16, so they are the ones people have copied.

## Consequences

- `main`'s CI, `docs-only.sh`, SwiftLint and the Xcode project are untouched.
- `docs/site/` on `main` is deleted. It held retired drafts that never deployed (its own `DEPLOY.md`
  said so), and with the real site in this repo a folder called `docs/site` that is not the site would
  mislead. Its one still-useful rule, the joined-word grep, is now a check (D6).
- **Push site work from a checkout of `site`.** Pushed from the app's checkout, the app's hook runs
  lint and the iOS build against it.
- One PR still cannot change an app claim and its site wording together. When an ADR changes what the
  app says or sends, the site PR is owed separately, as before.
- The fonts are still fetched from Google at build time (`next/font/google`), kept so the pixel
  comparison in D4 could hold. A cold fetch fails the build with one known message (1 of 6 builds on
  the day of the import), so `check.sh` retries once on that message and on nothing else. If it ever
  fails twice, host the fonts in the site as a change of their own.
- The beta guide's feedback still posts to Deco Operations' Formspree form, and the support address
  is still `support@decooperations.co.uk`. Neither is part of this move.
- `uk-site`'s history of these files stays in `laundry-pickup-project`. The import commit names the
  commit it came from.
- About 17 MB of images join the repo's objects (107 manual figures, 14 beta-guide shots, the landing
  page's captures, the starter track), and a full clone fetches them.
- Found during the import and fixed by it: the beta guide's `<meta name="description">` was Deco
  Operations' company blurb, inherited from the shared root layout.
