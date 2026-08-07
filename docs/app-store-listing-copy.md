# App Store listing copy — Red Moon Practice v1.1

> ## ⚠ 1.0 is RELEASED, not held (discovered 2026-08-07)
>
> App Store Connect shows **"1.0 Ready for Distribution"** — approved *and released*.
> The long-standing note in this project that v1 was "approved, release held on
> purpose, therefore no users" is **no longer true**, and everything that rested on
> it needs re-reading. Most importantly: **a shipped schema now exists in the field,
> so every future `@Model` change owes a real migration.** Per
> `docs/swiftdata-gotchas.md` that is precisely the class of failure that never
> reproduces in in-memory tests and only bites on device.
>
> A released version is **locked** — its description, keywords, screenshots and build
> can never be edited. Only promotional text stays editable. This submission therefore
> goes out as a **new version, 1.1**, created with the **+** beside "iOS App".
>
> Note also what the live 1.0 build contains: it predates the subscription, the
> paywall, Help & FAQs, ADR 0148's import rework, and the permission fix — so anyone
> downloading today gets a build that still asks for Apple Music access, stores
> imports as bookmarks (a restore-from-backup gives them a silent library — the very
> bug ADR 0148 exists to fix), and has **no paywall at all**: the whole app free.
>
> ### 🔴 DECIDED 2026-08-07: 1.0 is REMOVED FROM SALE while 1.1 is prepared
>
> Taken deliberately, to stop anyone else landing on that build and to avoid a cohort
> who had the full app free and then meet a hard paywall on update.
>
> **⚠️ THE APP IS THEREFORE INVISIBLE ON THE STORE RIGHT NOW.** Availability must be
> turned back on when 1.1 is approved, or 1.1 clears review and nobody can download
> it — a silent failure with no error anywhere to tell you. This is the single easiest
> thing in this whole document to forget. It is repeated as the **last item** of the
> pre-submission checklist on purpose.

Draft copy for the App Store Connect submission. Tweak freely; character limits
are Apple's hard caps. Honesty guardrail: Red Moon practises against **your own
local / iCloud audio files** — never imply Apple Music / Spotify streaming (see
[ADR 0001](decisions/0001-audio-source-local-first.md)).

---

## Name (reserved)
**Red Moon Practice** — already reserved in App Store Connect (the qualifier that
clears the "Red Moon Fitness" name collision).

## Subtitle — 30 char max
> **Loop, slow down, learn songs**  *(28)*

Alternates:
- `Slow down and loop any song` *(27)*
- `The guitar woodshed in your pocket` — too long (34); trim if you love it.

## Promotional text — 170 char max (editable anytime, no review)
> Bring your own tracks and loop the hard bar until it's yours — slow it down,
> keep the pitch, and drill scales, chords and routines between takes. *(140)*

## Keywords — 100 char max, comma-separated, NO spaces after commas
Don't spend keyword space on words already in the name ("practice") or subtitle.
> `guitar,looper,slow downer,metronome,tempo,scales,chords,arpeggio,riff,solo,transcribe,woodshed,bass`

*(99 chars — verify in the field; ASC counts live.)*

## Description
> **Red Moon is a practice room, not a jukebox.**
>
> Drop in your own recordings — local files or anything in iCloud Drive — and
> turn the part you can't play yet into the part you own. Set a loop over the
> tricky bar, slow it down without dropping the pitch, and run it until your
> hands catch up.
>
> **Loop and slow down**
> • Draw a loop on the waveform and repeat it hands-free
> • Slow the tempo while the pitch stays true
> • Stack loops across a song and jump between them
>
> **A real metronome**
> • Precise, steady tempo you can trust
> • Use it on its own or under any exercise
>
> **Exercises that show you the neck**
> • Scales and arpeggios drawn as fretboard boxes, labelled by where your hand
>   goes
> • Chords as diagrams — open shapes, movable barre grips, or a custom placer
>   for any voicing you can imagine
> • Picking, legato and strumming drills with a tempo ramp
>
> **Build a session**
> • Chain loops, songs and exercises into a routine and press play
> • Keep a private journal of how a passage is coming along
>
> Your playing never leaves your device. No account, no ads, no advertising ID —
> your audio, recordings, notes and song names stay with you, on your device and
> your own iCloud. Anonymous counts of which features get used can be switched off
> in Settings at any time.
>
> Named after the Tom Misch track that started it all.

## What's New in This Version — 4,000 char max (1.1)

**Who actually reads this:** nobody is upgrading. 1.0 had zero downloads and is
off sale, so there is no installed base to write a diff for. This field is read
by (a) App Review and (b) new visitors on the product page, where Apple shows it
alongside the description. So it should read as *what the app is now*, not as a
changelog against a build nobody has. Keep the first two lines strong — Apple
truncates the rest behind "more".

Paste-ready:

> Red Moon Practice 1.1 makes the practice room sturdier.
>
> • Songs you import are now kept inside the app on your phone, so they ride along
> in your phone's own backup. Restore to a new phone and your library comes back
> playing, with its loops, markers, takes and notes intact. Your original file stays
> where it is, untouched.
> • If a song ever does come up silent, you can point it at the file again and keep
> everything attached to it — no re-importing, no lost work.
> • Help & FAQs now lives in the Toolkit: sixteen answers, searchable, free whether
> or not you subscribe. You can email us from inside the app.
> • The Toolkit and the Journal are free forever — tuner, metronome, chord and
> theory tools, and your own notes, takes and progress. Everything else is Red Moon
> Pro, free for a month before you pay anything, and what you wrote and recorded
> stays yours either way.
> • The app no longer asks for access to your music library. It never used it.
>
> Something missing or broken? support@decooperations.co.uk — we read every one.

Shorter alternative, if the list feels heavy for a first impression:

> Songs you import are now kept inside the app on your phone, so they ride along in
> your phone's own backup: restore to a new phone and your library comes back
> playing, with its loops, markers, takes and notes intact. A song that can't find
> its audio can be pointed at the file again without losing any of that.
>
> New: Help & FAQs in the Toolkit, searchable and free, with a way to email us from
> inside the app. The Toolkit and the Journal are free forever; everything else is
> Red Moon Pro, free for a month first.
>
> The app no longer asks for access to your music library — it never used it.
>
> support@decooperations.co.uk

**Never write that imported songs "belong to Red Moon"** or any other ownership
phrasing, however true it is of the storage location. On a product page, with no
surrounding context, it reads as *uploaded to our cloud* — and there is no cloud.
Anchor both halves on the device instead: kept *inside the app on your phone*,
riding along in *your phone's own* backup. Every claim above is about local
storage and the user's own device backup; nothing here should imply a server.

**Don't** write "bug fixes and performance improvements" — Apple's own guidance
calls it out, and with no installed base it says nothing to the only people
reading. **Don't** mention 1.0 being pulled, ADR numbers, or CI/test work.

## Support URL — REQUIRED
Needs to resolve to a real page. Cheapest route: a single static page (GitHub
Pages, Notion public page, or a Carrd) with a contact email. Placeholder:
`https://<host>/red-moon-practice/support`

## Marketing URL — optional
Leave blank for v1, or point at the same host's landing page.

## Privacy Policy URL — REQUIRED
Host `docs/privacy-policy.md` (rendered) somewhere public and paste the URL.
GitHub Pages renders Markdown directly, which is the zero-effort option.

## App Privacy (nutrition label) — CHANGED by ADR 0120
No longer "Data Not Collected". Declare exactly one type, matching
`Pocket/Resources/PrivacyInfo.xcprivacy` and the manifest the Aptabase SDK ships:

- **Product Interaction** → used for **Analytics** → **not linked to the user's
  identity** → **not used for tracking**.
- Everything else stays *not collected*. No contact info, no identifiers, no user
  content, no diagnostics.
- **"Do you or your third-party partners use data for tracking?" → No.** There is
  no IDFA, no ATT prompt and no ad SDK, permanently (ADR 0120 §1), so no ATT
  purpose string is needed and `NSPrivacyTracking` stays `false`.

Note for App Review, if asked: collection is **anonymous, unlinked and not used for
tracking**, and there is a single switch in Settings ▸ Privacy that stops it. It is
**opt-in and off by default in the EEA and Switzerland** (ePrivacy Art. 5(3)) and
**on by default with a disclosure at first run elsewhere, including the UK** (Data
(Use and Access) Act 2025, Sch. A1 para. 5) — see ADR 0147. The app is fully
functional with it off. **Do not describe it as "opt-in" unqualified** — that was
true under ADR 0120 and is now true only inside the EEA.

## Category
- **Primary:** Music
- **Secondary:** Education

## Age rating
Questionnaire answers are all "None" → **4+**.

## Price / availability
- **App price:** Free to download. The app itself is never paid — everything is
  sold through the subscription below (ADR 0144 retired the free *tier*, not the
  free *download*).
- **In-app purchases:** two auto-renewable subscriptions in the **"Red Moon Pro"**
  group — `click.decooperations.pocket.pro.annual` (£49.99/yr, the default the
  paywall leads with) and `click.decooperations.pocket.pro.monthly` (£5.99/mo).
  Both carry a **1-month** introductory free trial.
  ⚠ **The live price and trial length are whatever App Store Connect says**, not
  what this file or `Configuration/RedMoonPro.storekit` says — the `.storekit`
  file only drives local and simulator testing. Never treat either as the source
  of truth, and note the app *derives* the trial length from StoreKit rather than
  hardcoding it (ADR 0144 A4), so ASC is the only place it needs changing.
  ⚠ Both products must be **"Ready to Submit"** before submission — sandbox will
  not vend a draft.
- **Paid Applications Agreement:** required now that there is IAP, and **active**
  (Tide GBP bank + W-8BEN-E both confirmed Active). The old note here said the
  base ADPLA was enough because v1 shipped no IAP — that stopped being true with
  ADR 0144.
- **Free surface for App Review:** the Toolkit (tuner, metronome, saved chords,
  glossary, Help & FAQs) and the Journal are free forever and need no purchase to
  evaluate. A hard paywall draws 2.1 / 3.1.2 scrutiny and this is the mitigation —
  paste-ready wording in **App Review notes** below.
- **Availability:** All territories, unless you want a phased rollout.

## App Review notes (paste-ready)

Paste into **App Review Information → Notes**. Everything here is checked against the
shipping code, not aspiration.

> Red Moon Practice is a guitar practice tool. No account or sign-in is required —
> nothing is created on a server and there is no login to give you.
>
> **You can evaluate a large part of the app without any purchase.** The Toolkit and
> the Journal are free permanently, not a trial: the chromatic tuner (guitar and
> bass), the metronome, the chord and theory tools, the glossary, and the in-app Help
> & FAQs; plus the Journal — your written practice notes, your recordings, and the
> Progress screen. All reachable from the home screen with no subscription.
>
> **To evaluate the subscription features, open the Song library and tap "Try the
> demo".** That adds a playable practice track so you can try the waveform, loop
> capture and speed control immediately. You can also import your own audio from the
> Files app; the app plays DRM-free local and iCloud Drive files only, and never
> Apple Music streaming audio. The app requests **no** access to your music library —
> it uses no MusicKit and no media-library API.
>
> **Subscription:** one group, "Red Moon Pro", offering the same thing at two
> durations — monthly or annual — each with a one-month free trial. There are no
> other in-app purchases, no consumables and no advertising. The trial length shown
> in the app is read live from App Store Connect rather than hardcoded.
>
> **Microphone:** the only permission the app requests. Used for the tuner (detecting
> the pitch of a played string) and for optional practice recordings the player starts
> themselves. Audio is analysed and stored on the device and is never uploaded — the
> app has no audio upload path.
>
> **Privacy:** all practice data is stored locally on the device. There is no
> cross-device sync and no user account. Anonymous, aggregate usage counts are
> collected to improve the app; in the EEA and Switzerland these are off until the
> player opts in, and elsewhere they are on with a clearly signposted way to object
> in Settings → Privacy. No advertising identifier is collected and no third-party
> ad or attribution SDK is present.

**Before pasting, re-check each claim still holds** — several of these lines are the
mitigation for a 2.1 review, so a stale one is worse than no note at all. In
particular the free surface (ADR 0144 D2), the region-split analytics default (ADR
0147), and "Try the demo" ([`LibraryView.swift`](../Pocket/Features/Library/LibraryView.swift),
`LibraryEmptyState.onTryDemo` → `Song.sample()` — the *generated* tone song, which is
why it survives ADR 0148 §7 deleting the bundled demo track).

## Export compliance
Auto-skipped — `ITSAppUsesNonExemptEncryption = false` is already set.

---

## Hosting (support + privacy pages)

**Privacy Policy — reuse the existing company policy.** Add a "Red Moon Practice
(iOS app)" section to the existing per-service policy at
`decooperations.co.uk/privacy` (Vercel), matching the Docket/website section style
— see the paste-ready section text in chat / commit. It must match
`docs/privacy-policy.md` as revised by ADR 0120 **and 0147**: no accounts, data
stored **on the device** (there is no cross-device sync — `Pocket.entitlements` is
empty and no CloudKit database is configured, ADR 0145), your playing never
transmitted, and anonymous usage counts whose **default depends on region** —
**off until asked** in the EEA and Switzerland, **on with a simple way to object**
everywhere else. The older "collects nothing" wording is no longer accurate, and
neither is describing the counts as opt-in unqualified. Give
Apple the anchored URL so the reviewer lands on the relevant section:
- **Privacy Policy URL** → `https://decooperations.co.uk/privacy#red-moon-practice`
  (verify the heading slugifies to that anchor).

### ⚠ Live-site check, 2026-08-07 — one correction still owed

Fetched `decooperations.co.uk/privacy` and read §3 "Red Moon Practice (iOS app)" in
full. **The ADR 0147 region split is live and correct** — "in the EEA and Switzerland
the counting is off until you turn it on, and everywhere else — including the UK — it
starts on" — and the lawful-basis paragraph correctly scopes the consent wording to
the EEA/CH rather than claiming opt-in everywhere. Subscriptions, Aptabase-in-the-EU
and the no-IDFA line are all accurate. Nothing there needs undoing.

**What is wrong: the microphone paragraph is incomplete.** It reads only —

> **Your recordings:** Practice takes you record with the microphone are saved
> locally on your device. They are never uploaded or shared.

— which never mentions the **tuner**, the app's other (and for most players *first*)
microphone use. A privacy policy linked from the App Store listing that omits a
disclosed permission's actual purpose is a real gap, and it's the same omission the
`NSMicrophoneUsageDescription` string carried until it was fixed here. Replace with:

> **Microphone:** The microphone is used for two things: the tuner, which listens to
> a played string to work out its pitch, and the practice takes you choose to record,
> which are saved locally on your device. Neither is ever uploaded or shared — the app
> has no audio upload path. The microphone is the only system permission the app
> requests; it does not ask for access to your music library.

⚠ `uk-site` **auto-deploys to prod on every push — there is no staging gate**, so make
this edit deliberately. Also confirm in a browser that the §3 heading actually carries
an `id` of `red-moon-practice`; the fetch could not see one, and the Privacy Policy URL
above depends on it.
- `docs/site/privacy.html` is now **redundant** — delete once the section is live.

**Support URL — DECIDED 2026-08-07: `decooperations.co.uk`, not `.click`.**
`https://decooperations.co.uk/redmoon/support`, served from the same Vercel site as
the marketing page and the privacy policy. This supersedes the earlier plan to put
it on AWS under `.click` (which had only ever been chosen to echo the
`click.decooperations.pocket` bundle namespace — a bundle id is not a hosting
decision, and it isn't visible to anyone).

Everything now lives on **one host, one repo, one deploy**: support, marketing and
privacy. That removes the split-brain that already produced one real bug — the
support *mailbox* is `@decooperations.co.uk` while the page was to be hosted on
`.click`, and this file previously printed the address as `support@decooperations.click`,
which would have shipped a dead support address. With a single domain that class of
typo has nowhere to live.

- Source file: `docs/site/support.html` → route `/redmoon/support`
- Marketing page's Support links are now **same-host relative** (`/redmoon/support`)
  rather than absolute `.click` URLs
- Zero-deploy fallback if the route slips: point Support URL at the existing
  `decooperations.co.uk/contact` form (loses the iOS-17 / your-files expectations
  the dedicated page sets)

Contact email: `support@decooperations.co.uk` (Google Workspace — see
`docs/site/DEPLOY.md`). It is what `support.html`, `redmoon-privacy.html`,
`docs/privacy-policy.md` and — since ADR 0145 — the app itself all use. Confirm it
exists / receives before submission. Marketing URL: leave blank for v1 (full
marketing site is a post-launch project; point the Marketing URL at it later — no
new build needed).

## Screenshots — REVISED shoot guide (re-shoot, 2026-07-21)

**Why re-shoot:** the `appstore-final/` set was shot **2026-07-16** and now predates
a batch of UI-changing merges (all Jul 20–21): Home regrouped into titled sections
(ADR 0102 / #159), search-first chord picker (ADR 0103 / #160), centralised Journal
(ADR 0100 / #157), 9th-chord grips (#158), pinch-zoom focal + loop-edge snap
(ADR 0098/0099), plus the net-new **Hear** audio surfaces (ADR 0097). Sequence the
shoot **after** Hear merges so the build and the shots match.

**Target size — CONFIRMED 6.5" / 1242×2688 (2026-07-22).** ASC rejected a 1320×2868
upload ("dimensions should be 1242×2688 / 1284×2778 …") — this listing exposes the
**iPhone 6.5" Display** slot only. Workflow that worked: shoot on the **iPhone 17 Pro
Max simulator** at native **1320×2868**, then **downscale** to 1242×2688 with
`sips -z 2688 1242` (downscaling stays crisp — unlike the old 16 Pro 1206×2622 set that
was *upscaled* → soft; the 0.4% aspect difference is invisible). Final upload set lives
in `Documents/Red Moon Screenshots 2/appstore-2026-07-22/upload-6.5/`.

### Verified working recipe (2026-08-07) — start here

Every line below was run and confirmed on the day. Device: **iPhone 17 Pro Max**
(`93C716BA-F669-4E25-92BD-0D76411B4203`), native capture **1320×2868**.

```bash
DEV=93C716BA-F669-4E25-92BD-0D76411B4203
xcrun simctl boot $DEV
xcodebuild build -scheme Pocket -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -derivedDataPath /tmp/shots-dd
xcrun simctl install $DEV /tmp/shots-dd/Build/Products/Debug-iphonesimulator/Pocket.app
xcrun simctl launch $DEV click.decooperations.pocket -seedScreenshots -appearance dark
# re-apply after EVERY launch — a relaunch resets it
xcrun simctl status_bar $DEV override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularMode active --cellularBars 4 \
  --dataNetwork wifi --wifiMode active --wifiBars 3
xcrun simctl io $DEV screenshot raw/01-hero.png
swift scripts/prep-shot.swift raw/01-hero.png upload/01-hero.png   # 1242×2688, opaque
```

⚠ **`xcrun simctl ui $DEV appearance dark` DOES NOT WORK.** `simctl` reports `dark`
and the app still renders the cream light theme, across a relaunch. Pass
**`-appearance dark`** as a launch argument instead: `AppearancePreference` is an
`@AppStorage("appearance")` value, and iOS reads `-key value` launch arguments as
UserDefaults, so this sets the app's *own* preference and sidesteps the system one
entirely. The final set is dark by decision, so getting this wrong wastes a whole shoot.

⚠ **Alpha must be flattened — ASC rejects a PNG with an alpha channel, and `sips`
will not reliably remove one.** `scripts/prep-shot.swift` downscales and flattens in a
single pass by drawing into an opaque `noneSkipFirst` CGContext. Verify with
`sips -g hasAlpha`.

⚠ **Seed audio is not in the repo and has been lost once already** (the July shoot's
files were gone by August). It now lives outside git at
`~/Documents/Red Moon Screenshots 2/seed-audio/`. `ScreenshotSeed` reads the
**filename** as the song title, and only `Red Moon`, `I Don't Trust Myself With Loving
You` and `I'd Rather Go Blind` have artist/BPM/key/loop metadata written for them.
The simulator's `AVAudioFile` decodes AAC but **silently fails on mp3** — convert
first: `afconvert in.mp3 out.m4a -d aac -f m4af`.

**Clean status bar (don't crop — normalise):** slots demand exact pixel dimensions,
so you can't crop the clock/battery/signal off and submit a shorter image. Instead
override the Simulator status bar to Apple's canonical clean state before every shot:
```bash
# boot the sim, then override once per boot:
xcrun simctl status_bar booted override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 \
  --dataNetwork wifi --wifiMode active --wifiBars 3
# navigate to each screen, then capture:
xcrun simctl io booted screenshot 01-hero-loop.png
```
Loop-trainer shots (#1/#2) need a **local audio file** imported into the sim first
(Apple Music can't be tapped); everything else runs off seeded content.

**FINAL SET — SHOT 2026-08-07.** Ten frames, dark, 1242×2688, alpha flattened, at
`~/Documents/Red Moon Screenshots 2/appstore-2026-08-07/upload-6.5-dark/`
(raw 1320×2868 masters beside it in `raw-1320x2868/`). Upload in filename order.

| # | File | What it shows |
|---|---|---|
| 1 | `01-hero-waveform` | Red Moon playing, 92 BPM, three saved loops with target speeds — the moat |
| 2 | `02-save-as-loop` | A–B drawn, **Save as loop**, at 0.75× — and 92 BPM has become 69, so the pair shows the tempo following the speed |
| 3 | `03-tuner` | "You're in tune!", needle centred on E². **Free surface** — the 2.1 mitigation, and the most legible frame at thumbnail size |
| 4 | `04-home` | Grouped hero with **Jump back in** populated (an app in use, not freshly installed) |
| 5 | `05-scale-drill-running` | A Minor Pentatonic mid-run: 80 BPM · Andante · **quarters** (ADR 0121's note rate) and the **command** stage lit |
| 6 | `06-routine` | Seven blocks mixing exercises with **loops from the user's own song** + rests — the "chain it into a session" claim, shown |
| 7 | `07-metronome-automator` | Automator By Bars, +5 every 4 bars to 110, staircase and Step 1/5 |
| 8 | `08-chord-placer` | Custom chord editor, "Looks like" resolving to **Cmadd9/D♯ 2nd inv** live |
| 9 | `09-chord-run` | Current grip large, **Next** ghosted beside it |
| 10 | `10-library` | Sorted by **Mastery**, so sections read *Polished · Solid · Needs work* rather than A–Z |

Notes for whoever reshoots next:
- **Sort the library by Mastery, not Title.** Alphabetical gives section headers of
  "F", "I", "L" — an index. Mastery gives *Polished / Solid / Needs work*, which says
  something about practice.
- **Shoot run screens mid-run.** The idle version truncated the exercise title ("A Minor
  Pentato…"); during a run the 4/4 chip disappears and the full name fits.
- **Watch the translucent nav bar.** A row caught half-scrolled under it smears behind
  the title and reads as a rendering glitch. Scroll so a header or a gap sits under it.
- Slot 3 leads with the tuner deliberately: only the first three appear on the install
  sheet, and a free, instantly-readable tool earns that place over a third loop screen.
  ASC ordering is drag-and-drop, so this is cheap to change without reshooting.

Old set (superseded): `Documents/Red Moon Screenshots 2/appstore-final/` (01–08,
1242×2688, shot 2026-07-16).

## Pre-submission checklist
- [ ] Subtitle, promotional text, keywords, description entered (above)
- [x] **10 screenshots re-shot 2026-08-07** on iPhone 17 Pro Max, dark, clean 9:41 bar,
      downscaled to 1242×2688 and alpha-flattened — every file verified `hasAlpha: no`.
      At `~/Documents/Red Moon Screenshots 2/appstore-2026-08-07/upload-6.5-dark/`
- [ ] Upload those ten to the **6.5" slot** in filename order (ASC keeps the previous
      version's screenshots when you create a new version, so **delete the July set
      first** — otherwise 1.1 ships 1.0's images)
- [ ] `support@decooperations.co.uk` mailbox live — **the app now ships this address**
      (Settings ▸ About ▸ Contact Support, and in plain text inside an FAQ answer,
      ADR 0145), so a dead mailbox is now a bug in a shipped build, not just a
      broken link on a page
- [x] "Red Moon Practice" section added to decooperations.co.uk/privacy — **live and
      ADR-0147-correct as of 2026-08-07** (verified by fetching the page)
- [x] Live site: §3 microphone wording — **DONE 2026-08-07**, see the item above
      ⚠ Editing that page is JSX, not HTML: a plain space between `</strong>` and the
      next word does **not** survive the build. Use `{' '}`. Four words on the live
      privacy policy were joined to the ones before them ("own copy**inside**",
      "practice takes**you**", "counts**Unless**", "counts**these**") — two of them
      pre-existing. All fixed; every built page was swept for the pattern.
- [ ] Live site: confirm the §3 heading's `id` is `red-moon-practice` so the anchored
      Privacy Policy URL actually lands
- [x] **Support page is LIVE at `decooperations.co.uk/redmoon/support`** — verified
      2026-08-07. It was already deployed and this checklist never knew: the real page
      is a **Next.js route** (`app/redmoon/support/page.tsx` on the `uk-site` branch),
      not the static `docs/site/support.html` this file kept pointing at. Its content
      was checked against the shipping app and is accurate — free surface per ADR 0144,
      analytics wording per ADR 0147, and "Today's session" really does ship (Pro-gated
      `PlannerView`). ⚠ `docs/site/support.html` is therefore **redundant**, exactly
      like `privacy.html`: the live page is richer and diverged long ago. Edit the
      route, never the local copy — and delete the local copy so nobody edits the
      wrong one.
- [x] Live site: §3's microphone paragraph now covers the **tuner** as well as practice
      takes, and states the mic is the only permission requested (2026-08-07). The
      audio-files bullet also gained ADR 0148's "we keep our own copy" fact, which it
      predated
- [ ] Support URL + Privacy Policy URL pasted into the form
- [ ] App Privacy answered: Product Interaction → Analytics → not linked, not tracking (ADR 0120); everything else "not collected". **Unchanged by ADR 0147** — the nutrition label encodes collection type, linkage and tracking, none of which the region split moves
- [x] `APTABASE_APP_KEY` set in `project.yml` from the real EU-region app key (done 2026-07-29; `AptabaseSinkTests` pins that it resolves and is EU-region)
- [ ] Category: Music (primary) / Education (secondary)
- [ ] Age rating questionnaire → 4+
- [ ] Price: Free · Availability set
- [x] **Archived and uploaded 2026-08-07 — "Pocket 1.1 (3) uploaded".** Done in **Xcode**,
      not the CLI: only *Apple Development* certificates were installed, and an App Store
      upload needs an *Apple Distribution* one, which only automatic signing creates.
      ⚠ The repo checks in `CODE_SIGN_STYLE: Manual` for CI determinism and `xcodegen
      generate` rewrites the project — so **re-tick "Automatically manage signing" +
      team 2L35PZ86GP after every regenerate**, and set the destination to *Any iOS
      Device (arm64)* or Archive stays greyed out. ("Pocket" in the upload dialog is the
      internal `PRODUCT_NAME`; `CFBundleDisplayName` is Red Moon.)
- [ ] Build finished processing and attached to **version 1.1**
- [ ] **What's New** filled in — paste-ready copy is in the section above. Required for a
      new version, and read by App Review and by new visitors on the product page
- [x] **Add for Review → Submitted 2026-08-07 15:30**, submission
      `b4535945-c425-4de7-8d58-fbc4b1bb4aaf`, four items: iOS App 1.1 (3) · Red Moon Pro
      Annual · Red Moon Pro Monthly · **Red Moon Pro (Subscription Group)**.
      ⚠ **The first-subscription rule, in full** — it cost two cycles today. A first
      auto-renewable subscription must be reviewed *with an app version binary that
      surfaces the purchase* **and** *with its subscription group*. The group is a
      separate reviewable object with its own display-name localization; adding only the
      two products leaves "must be submitted with its subscription group" and no obvious
      next step. Pulling the app version out strands the subscriptions as well.
      ⚠ **Withdrawing before review is free** — not a rejection, no mark on the account,
      no queue penalty. And **App Review Information stays editable while Waiting for
      Review**, so a forgotten note can still be pasted after submitting (unlike the
      binary). Save, then reload to confirm it stuck — ASC discards unsaved fields
      silently.
- [ ] 🔴 **TURN AVAILABILITY BACK ON once 1.1 is approved.** 1.0 was removed from sale
      2026-08-07 (done) while 1.1 is prepared, so the app is currently **not on the
      store at all**. Nothing will remind you: an approved 1.1 with no availability
      just sits there, downloadable by no one, with no warning anywhere in ASC.
      Pricing and Availability ▸ App Availability ▸ Manage ▸ re-select the territories
- [x] "Dont" → "Don't" in the seeded library — already fixed (no `Dont` remains in the source)
- [x] Permission audit: the app now requests **one** permission, the microphone.
      `NSAppleMusicUsageDescription` was removed (no MusicKit, no `MPMediaLibrary`;
      `SongRef.appleMusic` is test-only), and the mic string was rewritten to say
      "Red Moon" — not the internal target name "Pocket" — and to cover the **tuner**
      as well as recording. ADR 0115 §7 reused ADR 0069's string without widening its
      wording, and a purpose string that doesn't match actual use draws 5.1.1.
      **If any Apple Music browse path is ever built, re-add the string in that commit.**
