# App Store listing copy — Red Moon Practice v1.0

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

Curated slots, ordered for the install sheet (first 3 carry the pitch):

| # | Subject | Verdict | Set-up |
|---|---|---|---|
| 1 | Loop trainer, Solo playing (1.00×) — hero, the moat | Re-shoot | import demo local file; loop playing |
| 2 | A–B loop + "Save as loop" (0.75×) — core gesture | Re-shoot | same session, save sheet up |
| 3 | A Minor Pentatonic (fretboard + ramp + journal) — "it teaches" | Re-shoot | Journal centralised (#157) — confirm/reframe panel |
| 4 | Red Moon Practice Routine — session spine | Re-shoot | UI ~unchanged; reshoot for clean-bar consistency |
| 5 | Metronome + Automator — trust/utility | Re-shoot | UI ~unchanged; reshoot for consistency |
| 6 | Custom chord placer — novelty | Re-shoot | chord authoring redesigned (#158/#160) |
| 7 | Chord run — chords in action | Re-shoot | same redesign |
| 8 | Library (clean) — where you live | Re-shoot | Home/nav regrouped (#159); fix "Dont"→"Don't" seed typo first |
| + | **Home (grouped sections)** — new hero look | Consider adding | #159 gave Home a real hero; candidate for slot 1 |
| + | **Hear / audio preview** — differentiator | Consider adding | once ADR 0097 lands |

Old set (superseded): `Documents/Red Moon Screenshots 2/appstore-final/` (01–08,
1242×2688, shot 2026-07-16).

## Pre-submission checklist
- [ ] Subtitle, promotional text, keywords, description entered (above)
- [ ] 8 screenshots re-shot on iPhone 17 Pro Max sim (native 1320×2868, clean 9:41 status bar) and uploaded in order — see revised shoot guide above; verify ASC slot size on sign-in
- [ ] `support@decooperations.co.uk` mailbox live — **the app now ships this address**
      (Settings ▸ About ▸ Contact Support, and in plain text inside an FAQ answer,
      ADR 0145), so a dead mailbox is now a bug in a shipped build, not just a
      broken link on a page
- [x] "Red Moon Practice" section added to decooperations.co.uk/privacy — **live and
      ADR-0147-correct as of 2026-08-07** (verified by fetching the page)
- [ ] Live site: replace §3's "Your recordings" paragraph with the **Microphone** wording
      above — it omits the tuner. See the live-site check in Hosting
- [ ] Live site: confirm the §3 heading's `id` is `red-moon-practice` so the anchored
      Privacy Policy URL actually lands
- [ ] `support.html` deployed to **decooperations.co.uk/redmoon/support** (Vercel,
      same repo as the marketing + privacy pages — decided 2026-08-07, supersedes
      the `.click`/AWS plan)
- [ ] Support URL + Privacy Policy URL pasted into the form
- [ ] App Privacy answered: Product Interaction → Analytics → not linked, not tracking (ADR 0120); everything else "not collected". **Unchanged by ADR 0147** — the nutrition label encodes collection type, linkage and tracking, none of which the region split moves
- [x] `APTABASE_APP_KEY` set in `project.yml` from the real EU-region app key (done 2026-07-29; `AptabaseSinkTests` pins that it resolves and is EU-region)
- [ ] Category: Music (primary) / Education (secondary)
- [ ] Age rating questionnaire → 4+
- [ ] Price: Free · Availability set
- [ ] `xcodegen generate` → Archive (Release, team 2L35PZ86GP — Deco Operations Ltd, paid; owns `click.decooperations.pocket`) → Upload
- [ ] Build finished processing and attached to version 1.0
- [ ] Add for Review → Submit
- [x] "Dont" → "Don't" in the seeded library — already fixed (no `Dont` remains in the source)
- [x] Permission audit: the app now requests **one** permission, the microphone.
      `NSAppleMusicUsageDescription` was removed (no MusicKit, no `MPMediaLibrary`;
      `SongRef.appleMusic` is test-only), and the mic string was rewritten to say
      "Red Moon" — not the internal target name "Pocket" — and to cover the **tuner**
      as well as recording. ADR 0115 §7 reused ADR 0069's string without widening its
      wording, and a purpose string that doesn't match actual use draws 5.1.1.
      **If any Apple Music browse path is ever built, re-add the string in that commit.**
