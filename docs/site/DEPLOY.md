# Red Moon Practice — support / marketing / privacy deploy guide

Three public URLs App Store Connect needs, across your existing hosting.

**All three live on the same Vercel site (`decooperations.co.uk`) — decided 2026-08-07.**
Support was previously planned for AWS under `.click`; that split existed only to
echo the `click.decooperations.pocket` bundle id, which nobody sees and which is not
a hosting decision. One host means one repo, one deploy, and no chance of the
`.click` / `.co.uk` mix-up that already put a wrong support address in the docs.

| Purpose | URL | Host | Source file |
|---|---|---|---|
| Marketing (optional) | `https://decooperations.co.uk/redmoon/` | Vercel (`.co.uk`) | `docs/site/index.html` |
| Support (required) | `https://decooperations.co.uk/redmoon/support` | Vercel (`.co.uk`) | `docs/site/support.html` |
| Privacy (required) | `https://decooperations.co.uk/privacy#red-moon-practice` | Vercel (`.co.uk`) | add a section to the existing policy — **already live**, see §3 |

Contact email on the pages: **support@decooperations.co.uk** (Google Workspace).

---

## 1. Marketing page → Vercel (decooperations.co.uk)

The `.co.uk` site is on Vercel, so add the page as a static asset in that repo and
push — Vercel redeploys automatically.

1. Copy `docs/site/index.html` into the `.co.uk` project's **static/public output**
   at `redmoon/index.html`. For most Vercel setups that's:
   - Next.js / Vite / CRA / Astro: `public/redmoon/index.html`
   - a plain static site: `redmoon/index.html` in the published root
2. Commit + push. Vercel builds and deploys.
3. Verify: `https://decooperations.co.uk/redmoon/` loads.
4. The page's **Support** links point at the `.click` support page (absolute), and
   **Privacy** points at `/privacy#red-moon-practice` on the same `.co.uk` host.
5. TODO before/after launch: the hero "Download on the App Store" button is a
   placeholder `href="#"` — swap in the App Store URL once the app is live.

## 2. Support page → Vercel (decooperations.co.uk)

Same repo and same mechanism as the marketing page above — it's a second static
file in the same deploy.

1. Copy `docs/site/support.html` into the `.co.uk` project's static/public output at
   `redmoon/support/index.html` (the `folder/index.html` layout is what gives the
   clean extensionless `/redmoon/support` URL App Store Connect has been given).
   For a Next.js project that is `public/redmoon/support/index.html`.
2. Commit + push. Vercel redeploys automatically.
3. Verify `https://decooperations.co.uk/redmoon/support` loads **before** submitting —
   App Review checks the Support URL, and a 404 there is a straightforward rejection.

⚠ That repo **auto-deploys to production on every push, with no staging gate**, so
push deliberately and verify immediately after.

The page's own links are same-host relative (`/privacy#red-moon-practice`), so
nothing needs rewriting per environment.

## 3. Privacy → paste into the existing Vercel policy

Do **not** deploy `docs/site/privacy.html` (redundant — safe to delete). Instead
paste the "Red Moon Practice (iOS app)" section into the existing policy page at
`decooperations.co.uk/privacy`, matching the website/Docket section style. Content:
`Red Moon resources/privacy-section-for-decooperations.md`.

Verify the heading slugifies to the anchor: `https://decooperations.co.uk/privacy#red-moon-practice`
should jump to the new section.

## 4. Email → Google Workspace (support@decooperations.co.uk)

Pick one in Google Admin (admin.google.com):
- **Alias** on your existing user (simplest): Users → your account → Add alternate
  email → `support@decooperations.co.uk`. Mail lands in your existing inbox.
- **Group** (better if others help with support later): Groups → Create group →
  `support@decooperations.co.uk`, add yourself as a member. Acts as a shared inbox.

Send a test email to it and confirm it arrives before submitting.

## 5. Paste into App Store Connect
- **Marketing URL** → `https://decooperations.co.uk/redmoon/`
- **Support URL** → `https://decooperations.co.uk/redmoon/support`
- **Privacy Policy URL** → `https://decooperations.co.uk/privacy#red-moon-practice`

## Checklist
- [ ] `index.html` deployed to Vercel; `decooperations.co.uk/redmoon/` resolves
- [ ] `support.html` deployed to Vercel; `decooperations.co.uk/redmoon/support` resolves
- [x] Privacy section pasted — **live and ADR-0147-correct, verified 2026-08-07**
- [ ] Privacy §3's microphone paragraph still omits the **tuner** — replace it (paste-ready
      wording in `docs/app-store-listing-copy.md` ▸ Hosting ▸ Live-site check)
- [ ] `#red-moon-practice` anchor actually resolves (a page fetch can't confirm this —
      check in a browser)
- [ ] `support@decooperations.co.uk` created in Workspace + test email received
- [ ] all three URLs pasted into App Store Connect
- [ ] (post-launch) marketing page "Download" button points at the live App Store URL
