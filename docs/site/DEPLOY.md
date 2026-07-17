# Red Moon Practice — support / marketing / privacy deploy guide

Three public URLs App Store Connect needs, across your existing hosting.

| Purpose | URL | Host | Source file |
|---|---|---|---|
| Marketing (optional) | `https://decooperations.co.uk/redmoon/` | Vercel (`.co.uk`) | `docs/site/index.html` |
| Support (required) | `https://decooperations.click/redmoon/support/` | AWS (`.click`) | `docs/site/support.html` |
| Privacy (required) | `https://decooperations.co.uk/privacy#red-moon-practice` | Vercel (`.co.uk`) | add a section to the existing policy — see `Red Moon resources/privacy-section-for-decooperations.md` |

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

## 2. Support page → AWS (decooperations.click)

Deploy the same way your other `.click` pages publish. If that's S3 + CloudFront,
from `docs/site/`:

```bash
BUCKET=your-decooperations-click-bucket    # bucket behind decooperations.click
DIST=YOUR_CLOUDFRONT_DIST_ID               # if CloudFront fronts it

# folder/index.html layout gives the clean extensionless URL
aws s3 cp support.html "s3://$BUCKET/redmoon/support/index.html" --content-type text/html

# invalidate CloudFront cache so the new file is served
aws cloudfront create-invalidation --distribution-id "$DIST" --paths "/redmoon/*"
```

Console alternative: in the S3 bucket, create `redmoon/support/`, upload
`support.html` renamed to `index.html`, set `Content-Type: text/html`.

Verify: `https://decooperations.click/redmoon/support/` loads.

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
- **Support URL** → `https://decooperations.click/redmoon/support/`
- **Privacy Policy URL** → `https://decooperations.co.uk/privacy#red-moon-practice`

## Checklist
- [ ] `index.html` deployed to Vercel; `decooperations.co.uk/redmoon/` resolves
- [ ] `support.html` deployed to AWS; `decooperations.click/redmoon/support/` resolves
- [ ] Privacy section pasted; `#red-moon-practice` anchor resolves
- [ ] `support@decooperations.co.uk` created in Workspace + test email received
- [ ] all three URLs pasted into App Store Connect
- [ ] (post-launch) marketing page "Download" button points at the live App Store URL
