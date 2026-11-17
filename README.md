# Red Moon Practice Studio — website

The site at **https://www.redmoonpracticestudio.co.uk**: the landing page, the story, support, the
privacy policy, the user manual and the closed-beta guide.

This is the `site` branch of `pocket-ios`. It shares no history with `main`, which holds the iOS app,
and the two never merge. Why it lives here, and how it got here from `laundry-pickup-project@uk-site`,
is ADR 0306 on `main` (`docs/decisions/0306-the-site-lives-on-its-own-branch.md`).

## Stack

- **Next.js 16** (App Router), TypeScript, plain CSS (`app/globals.css`). Every page is static.
- **Fonts** via `next/font/google`: Jost (the web fallback for Futura, which Apple devices have),
  plus Cormorant Garamond and DM Sans for a few shared prose rules.
- **`marked`** (exact-pinned) renders the manual at build time only.
- **Formspree** takes the beta guide's feedback (Deco Operations' form, `mbdweqar`).
- **Vercel** hosts it, deploying every push to `site` to production.

## Working on it

```sh
git worktree add ~/Documents/pocket-site site   # once, from any checkout of pocket-ios
cd ~/Documents/pocket-site
git switch -c pocket-0XX-short-title             # branch from site, never from main
npm ci
npm run dev                                       # http://localhost:3000
scripts/check.sh                                  # what CI runs
```

Open the pull request **into `site`** (`gh pr create --base site`). Merging it publishes. Push from
this checkout: the repo's pre-push hook runs `scripts/pre-push.sh` from whichever checkout pushes, so
here it runs this site's check, and from the app's checkout it would run the iOS build.

## Pages

| Path | Source |
|---|---|
| `/` | `app/page.tsx`: dark landing page, App Store captures from `app/_media/` |
| `/story` | `app/story/page.tsx` |
| `/support` | `app/support/page.tsx`: App Review opens this |
| `/privacy` | `app/privacy/page.tsx` + `RedMoonPrivacyBody.tsx`: App Review opens this too |
| `/manual`, `/manual/…` | `app/manual/`, rendered from `content/manual/` (below) |
| `/beta/14675668e46224e5773801fc` | `app/beta/…/BetaGuide.tsx`: unlisted; section anchors are frozen |

Old `/redmoon/…` page addresses redirect to these (`next.config.ts`). Images, the starter track and
the manual's figures are served from `/redmoon/…` on purpose: that is where they have always been.

## The manual is exported, never edited here

`content/manual/` and `public/redmoon/manual/` are written by `scripts/export-manual.py` on `main`,
from `docs/manual/` (ADR 0217). A hand edit here is overwritten by the next export. To publish:

```sh
cd ~/Documents/pocket-site && git switch -c pocket-0XX-manual-export site
cd <a checkout of main> && ./scripts/export-manual.py ~/Documents/pocket-site [--figures FILE]
```

then commit here and open a PR into `site`. `index.json` records the commit the copy came from.

## Design tokens

Red Moon's pages take the app's Blood Moon values (pocket-ios ADR 0292) as `--rm-*` tokens in
`app/globals.css`. Change them in the app first, then here.

| Token | Value | Use |
|-------|-------|-----|
| `--rm-red` | `#C24A2C` | The logo, byte for byte: marks and large type only |
| `--rm-ember` | `#E07E57` | Terracotta (dark): kickers and links on black |
| `--rm-rust` | `#B0391B` | Terracotta (light): links on cream |
| `--rm-cream` | `#F0E3D8` | Reading pages' background (the app's light background) |
| `--rm-ink` | `#000000` | Landing and story background; the app captures sit on it |

The landing page and the story are dark (`.rm-dark`); support, privacy, manual and the beta guide are
cream. `.rm-page` re-points the shared `--accent` and `--stone-*` tokens, so the prose classes
(`.privacy-*`, `.section-*`) take Red Moon's colours. The nav, footer, store button and phone frame
are shared, in `app/_components/brand.tsx`. The logo SVGs in `public/redmoon/` are the app's
(`scripts/derive-brand-svgs.py` on `main`): copy them, don't edit them.

## After a merge

Vercel deploys within a minute or two. Check the live site, not a preview (previews sit behind
Vercel's login, and are a different deployment):

```sh
for p in / /support /story /privacy /manual /beta/14675668e46224e5773801fc; do
  curl -s -o /dev/null -w "%{http_code} $p\n" "https://www.redmoonpracticestudio.co.uk$p"
done
```

A phrase grepped in the live HTML appears twice: once in the page, once in the RSC payload. That is
normal.
