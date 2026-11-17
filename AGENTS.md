# Working on this branch

This is Red Moon Practice Studio's **website**, on the `site` branch of `pocket-ios`. It is a Next.js
app, not the iOS app: none of `main`'s Swift, Xcode or SwiftLint rules apply here, and none of this
branch's files belong on `main`. The two branches share no history and never merge into each other.
The decision is ADR 0306 on `main`. Read `README.md` for the layout.

## Before you push

1. **`scripts/check.sh`**: the build, then two scans of the rendered pages (joined words, and
   *Pocket* in copy). CI runs the same script as `Build · Check` on every PR into `site`.
2. **Look at it.** A green build says nothing about how a page looks. Screenshot what you changed
   at 1280 and 390 px wide (scroll the page first: `.reveal` sections stay invisible until they
   are scrolled into view, so a one-shot capture shows them black), and check that
   `scrollWidth - innerWidth` is 0 at 390 px.

## Conventions

- **Branches:** `pocket-0XX-short-title` (the repo's one sequence), cut **from `site`**, PR **into
  `site`** (`gh pr create --base site`). Don't push or open PRs unless asked.
- **Merging is publishing.** Vercel deploys every push to `site` to production, with no staging. After
  a merge, check the live site with `curl` (README ▸ *After a merge*), not a preview.
- **Push from a checkout of `site`.** The repo's pre-push hook runs `scripts/pre-push.sh` from the
  checkout that pushes; from the app's checkout it would run the iOS build.

## Rules this site has broken before

- **The site makes claims about the app, and nothing checks them.** When an app change alters what
  the app says, sends, asks permission for, costs or is called, grep all three claim pages:
  `app/page.tsx`, `app/support/page.tsx`, `app/privacy/RedMoonPrivacyBody.tsx`. The privacy text has
  drifted from the app four times, always understating what is sent. The canonical policy is
  `docs/privacy-policy.md` on `main`. Diff in both directions, because the canonical has been wrong too.
- **Describe the app that is in the App Store**, not the one on `main`. A page about a feature waits
  for the release that ships it.
- **There is no iCloud sync.** Practice content stays on the device that made it. Picking a file
  *from* iCloud Drive is a file picker. The site promised sync in three places once.
- **Red Moon, never Pocket.** `Pocket` is the app's internal target name. `check.sh` fails on it.
- **A practice studio**, never a practice *space*.
- **Write the character, not the entity.** `</strong> —` keeps its space; `</strong> &mdash;` loses it
  and renders `word—word`. `check.sh` catches the result.
- **`/support` and `/privacy` are opened by App Review.** A change that breaks either can fail a
  review. Check them live after every merge.
- **The manual is exported, never edited here** (`content/manual/`, `public/redmoon/manual/`). Change
  `docs/manual/` on `main`, then export (README ▸ *The manual*).
- **Frozen addresses:** the beta guide's URL and its section anchors (`before-you-start`,
  `what-this-is`, `first-session`, `holds`, `build-a-drill`, `planner`, `the-rest`, `feedback`,
  `checklist`, `routines`, `journal`, `progress`, `toolkit`, `metronome`, `settings`, `help-faqs`) went
  to testers. Asset paths under `/redmoon/` stay where they are.
- **Copy the logo SVGs from the app** (`scripts/derive-brand-svgs.py` on `main`); don't edit them here.
