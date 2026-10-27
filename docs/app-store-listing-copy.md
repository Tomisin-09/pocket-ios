# App Store listing copy — Red Moon Practice Studio 1.4

> ## 1.4 is the release (2026-10-26): what's current
>
> One plan (ADR 0256): **£0.99 a month** (a free week first) **or £14.99 once** (ADR 0277), at the
> founding price (ADR 0274). The Song library, the song player with saved loops, the Metronome, the
> Journal and Practice log, and the Toolkit are free (ADR 0263). Practising is the plan.
>
> **Current, so paste from these:** Name, Subtitle, Promotional text, Keywords, Description (with
> its *One plan* block and the EULA line), *What's New — 1.4*, Price / availability, App Review
> notes, and the **1.4 pre-submission checklist**. Every other *What's New* draft and checklist
> below is history. Don't paste from it.
>
> **Don't copy from this file into App Store Connect.** Its blockquotes are wrapped and marked up for
> reading here, and App Store Connect's fields are plain text that keep every line break. Run
> `./scripts/export-listing.py --copy <field>` and paste. The fields are `subtitle`,
> `promotional-text`, `keywords`, `description`, `whats-new` and `review-notes`. The script checks each
> field's limit and the description's EULA link first, and copies nothing if one fails.

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
**Red Moon Practice Studio** — renamed in App Store Connect for 1.4, after ADR 0276's *practice
studio* (24 of 30 characters). It was **Red Moon Practice**, the qualifier that cleared the
"Red Moon Fitness" name collision. The subscription group *Red Moon* shows this name beside it in
Settings ▸ Subscriptions (ADR 0277).

## Subtitle — 30 char max
> **Loop, slow down, learn songs**  *(28)*

*Kept for 1.4 (Tomisin, 2026-10-27, ADR 0279 D5). "Loop & slow down guitar songs" was considered
and turned down, so "guitar" stays the first keyword.*

Alternates:
- `Slow down and loop any song` *(27)*
- `The guitar woodshed in your pocket` — too long (34); trim if you love it.

## Promotional text — 170 char max (editable anytime, no review)
> Work out the hard bar, build it up against a click, run it in a routine, and keep what you learn.
> A practice studio for guitar players who learn from everywhere. *(161)*

*1.4 (2026-10-27), chosen by Tomisin: the four verbs and the line (ADR 0279). Replace the live text in
App Store Connect with this. The field needs no review.*

*Considered for 1.4 the day before, from ADR 0276's candidate (trimmed from 171 to fit): "Loop the
hard bar in your own tracks and slow it down without dropping the pitch. Then line your loops up with
drills into a session that picks up where you left off." (166)*

*History. The text from 2026-08-16 was: "Loop the hard bar in your own tracks and slow it down without
dropping the pitch — then line those loops up with your drills into a session you press play on."
Reframed 2026-08-16 (`docs/positioning.md` §6). The promotional field is the **only**
listing layer editable while 1.1 is live — subtitle, keywords, description and
screenshots are locked until 1.2 — so it carries the intersection claim on its own for
now. It states both halves in one sentence: the audio engine on your own files, and the
session those loops feed. Deliberately **not** "we have routines" — nine other apps have
routines; the claim is holding both ends.*

**Locked until 1.2, then reframe (`docs/positioning.md` §7):**

- **Subtitle** stays *"Loop, slow down, learn songs"* even in 1.2. That is the
  acquisition layer working correctly — *"slow downer"* is a real search query and
  *"practice routine app"* is not. Do not trade a working keyword for a positioning
  statement.
- **Description**: ~~*"Build a session"* is currently the 4th block and routines are one
  bullet inside it. In 1.2 it moves up beside *"Loop and slow down"*, and the opening
  paragraph names both halves rather than only the waveform.~~ **Done in the free-release
  rewrite below (2026-10-02).**

## Keywords — 100 char max, comma-separated, NO spaces after commas
Don't spend keyword space on words already in the name ("practice") or subtitle.
> `guitar,looper,slow downer,metronome,tempo,scales,chords,arpeggio,riff,solo,transcribe,woodshed,bass`

*"guitar" must stay here: neither the name nor the subtitle carries it, so this field is the only
place search can find it.*

*(99 chars — verify in the field; ASC counts live.)*

## Description
> **Red Moon is a practice studio for guitar players who learn from everywhere.**
>
> A video lesson, a teacher, a tab, a record you love. Red Moon doesn't hand you another method. It
> gives you the tools to build your own from what you already learn from, and it keeps everything you
> do, so your practice adds up instead of starting over. Nobody is marking you.
>
> Built for guitar, with drills, chords and the fretboard at its heart. Bass gets its own four-string
> neck, tunings and shapes. Play something else? The song player, the metronome, routines and the
> journal work for any instrument.
>
> **Work it out**
> • Bring in songs you own from Files or iCloud Drive, or share audio in from another app
> • Loop the bar you can't play yet, as short as half a second, and let it go round
> • Slow it down while the pitch stays true
> • Count the notes, name them on the neck, and keep what you find as tab
> • A song is waiting the first time you open the app, with a three-step guide
>
> **Build it up**
> • Every drill runs against a click: scales, arpeggios, picking, legato, strumming, chord changes
> • A tempo ramp raises the speed a step at a time, holds it, and can back off
> • Click withdrawal thins the click, so you carry the pulse yourself
> • Scales and chords drawn on the fretboard, labelled by where your hand goes
>
> **Run it**
> • Chain loops, songs, drills and rests into a routine, and press play
> • Build one around the parts you find hard, for a gig, a lesson or just this week
> • Today's session builds one for you from three questions and your goals
> • A routine remembers when you last ran it, and never sets you a target
>
> **Keep it**
> • Record takes, and pin a note to a moment in one
> • Write down what you noticed, on a loop, a drill or a whole session
> • The practice log shows the days and minutes you played, and never scores them
> • Export a take or a song's audio to work on in your DAW
>
> **Your sources, your method**
> • Keep the lesson beside the part it's for: a link or a file on any song, loop or drill
> • Save to Red Moon from any app's share sheet
> • Send a routine to a teacher or bandmate, with its songs inside
> • A tuner for guitar and bass, a metronome, chord shapes, a placer that names any voicing, and a
>   glossary
>
> **One plan**
> Your songs and loops, the Metronome, the Journal and everything in the Toolkit are free. The plan
> is for practising: drills, routines, Today's session and the loop trainer.
>
> **£0.99 a month, or £14.99 once.**
> That's the founding price, and it's yours for as long as you keep the plan. Nothing you can do
> today will ever move behind a higher one.
>
> Red Moon plays audio files you own. It can't play Apple Music or Spotify streams.
>
> Nothing you play leaves your phone unless you send it yourself. There's no account.
> Your audio, recordings, notes and song names stay on your
> device, Red Moon doesn't count what you do in it, and it never uses the
> advertising identifier.
>
> Named after the Tom Misch track that started it all.
>
> The monthly plan is an auto-renewable subscription. Terms of Use (EULA):
> https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

*Restructured 2026-10-27 and approved by Tomisin the same day (ADR 0279), around four verbs, *work it out · build it up · run it · keep it*, under one roof, *your sources, your method*. The opening names the audience: the self-taught player who learns from everywhere. The 2026-10-24 version (seven feature groups, opening *"a practice studio, not a jukebox"*) is in git history. Before that: rewritten for the free release, 2026-10-02; re-voiced 2026-10-24 as a practice studio that adds up (ADR 0256):*

- *The opening names both halves, the loop on your own song and the session it feeds,
  and ends on "Nobody is marking you". The headline and the start of that paragraph
  are what show before "more".*
- *"Build a session" moves up beside "Loop and slow down" (the 1.2 reframe, landed now),
  and working a part out by ear gets one block. It never implies the app hears the notes
  for you.*
- *Sending follows ADR 0236 D1: it's about taking your work somewhere to work on it, never
  "share". A routine sent with its songs plays only for someone who also has Red Moon.*
- *The streaming line sets expectations before install, so nobody downloads it for Apple
  Music.*
- *"No ads" is gone (ADR 0240: it stays only in disclosures, the privacy policy and the
  review notes), the usage-counts sentence went with ADR 0239, and "free" is not a
  headline.*
- *1.4 (2026-10-26): the **One plan** block and the promise go in word for word (ADR 0256 D8, 0274
  D1), with the UK prices (ADR 0277). ADR 0145 D6's rule against hardcoded prices is about in-app
  help copy, not this field. Still name no trial length: the storefront shows it, and App Store
  Connect sets it.*
- *The prices are in pounds because this is the English (U.K.) text. If the app has no other English
  localization, every storefront reads £. An English (U.S.) description would use the US prices App
  Store Connect generated, so read them off the products first.*
- *The EULA line is back (Guideline 3.1.2), because the monthly is an auto-renewable subscription
  again. Paste the URL as bare text, at the very end. Its absence is what rejected 1.1 (3).*
- *Check the line-wrap in the field, and the length (4,000 characters at most).*

### History: the EULA line — REJECTED 2026-08-08 for its absence, retired by ADR 0237

> **Back for 1.4.** ADR 0256's monthly is an auto-renewable subscription, so the EULA line is in the
> description again (above). What follows was written for the free release, and still explains why.

**No longer applies.** Guideline 3.1.2 binds an app that offers auto-renewable
subscriptions, and since ADR 0237 Red Moon offers none, so the two closing lines
(*"Red Moon Pro is an auto-renewable subscription. Terms of Use (EULA): …"*) come out of
the description. Settings ▸ Help & About still links Apple's standard EULA, because the
licence applies to every App Store app. If the Oracle ever ships a subscription, the rule
below comes straight back. Kept for that day:

App Review returned 1.1 (3) automatically, before a human looked at it: *"The
submission offers auto-renewable subscriptions but does not include a functional
link to the Terms of Use (EULA) in the app's metadata."* (Guideline 3.1.2.)

The in-app half was already right — `PaywallView` and Settings ▸ About both link
Apple's standard EULA — but 3.1.2 asks for the link in **two** places, and the
App Store **description** is the one that was missing. It is a metadata-only
defect: paste the two lines above at the end of the Description field, resubmit
the same build. No archive, no upload, no version bump.

Paste the URL as bare text, not markdown — ASC's Description field is plain text
and renders no link syntax, and Apple checks the URL literally. Keep it on the
end of the description, after the sign-off, where it reads as boilerplate rather
than as a sales line.

We ship **no custom EULA**, so App Information ▸ License Agreement stays on
Apple's standard terms. Only if that ever changes does the link move into ASC's
own custom-EULA field instead of the description — and then all three surfaces
(description, paywall, Settings) must point at the custom one, not Apple's.

## What's New in This Version — 1.4 (paste this)

> Red Moon is now a practice studio with one plan. Your songs and loops, the Metronome, the Journal
> and the Toolkit are free, and practising is the plan, at the founding price.
>
> Also new:
> • The Practice hub is shelves: today's session, your routines, and your drills by kind
> • References: keep every lesson, video and file you learn from, and attach them where they belong
> • Save to Red Moon from any app's share sheet, and audio shared from Voice Memos or Files lands
>   as a song
> • The Practice log's month reads as a calendar, and tapping a day shows what you played

*Short on purpose. Hardly anyone has 1.1 installed, so this reads mostly as the product page's version
history. It names no price and no trial length. Each line is a CHANGELOG entry: the hub (ADR 0257),
References and Save to Red Moon (ADR 0264), audio shared in (ADR 0273), the month grid (ADRs 0268,
0269).*

## What's New — the free release (draft) — HISTORY, do not paste (ADR 0256)

The next version's notes carry everything built since 1.3; this is the part about
price, to merge in near the top. Paste-ready:

> Red Moon is now free. Everything in it is open to everyone, with nothing to buy:
> practise your songs and loops, build your own exercises and routines, and let
> Today's session plan one for you. Nothing you made has moved — your songs, loops,
> routines, notes and takes are where you left them.

Don't call it "free forever", and don't explain the change: the product page reads it
as *what the app is now*, which is the whole point.

## What's New in This Version — 4,000 char max (1.1) — history, do not paste

*Shipped with 1.1. Its subscription lines describe a tier that ADR 0237 removed.*

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
`https://decooperations.co.uk/redmoon/support`, live since 1.0 (the `uk-site` route
`app/redmoon/support/page.tsx`). It's already set in App Information. Open it once before
submitting.

## Marketing URL — optional
Leave blank for v1, or point at the same host's landing page.

## Privacy Policy URL — REQUIRED
`https://decooperations.co.uk/privacy`, the live policy (`uk-site` `app/privacy/page.tsx`). It's
already set in App Information. Settings ▸ About links to its Red Moon section,
`#red-moon-practice`, so keep that anchor's id if the heading changes (ADR 0278).
`docs/privacy-policy.md` is a draft, not the live text.

## App Privacy (nutrition label) — set by ADRs 0161 and 0183; analytics removed by ADR 0239
Not "Data Not Collected" — the contact form sends what the player writes. Declare
**three** types, matching `Pocket/Resources/PrivacyInfo.xcprivacy`:

- **Product Interaction is no longer declared.** It covered the Aptabase analytics
  (ADR 0120), and ADR 0239 removed them. If it was ever submitted, take it off.
- **Email Address**, **Other User Content** and **Other Diagnostic Data** → all used
  for **App Functionality** → all **linked**, and none used for tracking. These are
  the in-app contact form (ADR 0161 D6): the reply address the player types, their
  message, and the installation details shown to them in the sheet before they send.
  Linked is deliberate — they arrive attached to an address the player chose to give
  us, and declaring them unlinked would be the convenient answer rather than the
  right one.
- **Other Diagnostic Data also covers ADR 0183**: one bounded line summarising the
  crashes and freezes iOS reported, attached **only** when the player turns
  *Settings ▸ Help & About ▸ Diagnostics ▸ Include in support messages* on (off by
  default) and shown to them in full first. No call stacks, no logs. MetricKit needs
  no `NSPrivacyAccessedAPITypes` entry — it is not a required-reason API.
- **Purchases (1.4).** The plan is bought through StoreKit, and the app sends nothing about a
  purchase anywhere: `PlanStore` reads entitlements on the device. So *Purchases* stays not
  collected. Check that against Apple's current definitions when you answer.
- Everything else stays *not collected*. No identifiers, no location, no contacts.
- **"Do you or your third-party partners use data for tracking?" → No.** There is
  no IDFA and no ATT prompt, permanently (ADR 0120 §1), and no ad SDK in the app
  (one would need its own ADR first: ADR 0240), so no ATT purpose string is needed
  and `NSPrivacyTracking` stays `false`.

Note for App Review, if asked: the app contains **no analytics and no third-party
SDK**, and sends nothing on its own. The only data it sends is a support message the
player writes and taps Send on, with every attached detail shown first. Usage figures
come from App Store Connect (ADR 0239). The region-split usage counts ADRs 0120 and
0147 described no longer exist — don't mention them anywhere.

## Category
- **Primary:** Music
- **Secondary:** Education

## Age rating
Questionnaire answers are all "None" → **4+**.

## Price / availability
- **App price:** Free to download; one plan inside it (ADR 0256): **Monthly** (£0.99, with a free
  week as an introductory offer; product `click.decooperations.pocket.plan.monthly2` in the group
  **Red Moon**) or **Pay once** (£14.99, non-consumable; `…plan.payonce`). UK is the base storefront;
  the rest are App Store Connect's generated prices. `…plan.monthly` is spent (ADR 0277 D3). Family Sharing off (ADR 0259). The founding price is
  held for as long as a player keeps the plan (ADR 0274).
- **In-app purchases:** the two products above. *History, kept for the record:* the two auto-renewable subscriptions that ADR 0144
  set up (`click.decooperations.pocket.pro.annual` and `…pro.monthly`, group
  **"Red Moon Pro"**) were never sold and are **removed from sale** in App Store
  Connect; the app no longer links StoreKit at all. If the Oracle is ever priced,
  it is strictly additive (0237 D3) and gets new products.
- **Paid Applications Agreement:** needed again, because the app sells a plan (ADR 0256). Without it
  the products cannot be sold.
- **Availability:** All territories, unless you want a phased rollout.

## App Review notes (paste-ready)

Paste into **App Review Information → Notes**. Everything here is checked against the
shipping code, not aspiration.

> Red Moon Practice Studio is a guitar and bass practice tool. No account or sign-in is required —
> nothing is created on a server and there is no login to give you.
>
> **One plan, no advertising.** The Song library, the song player (saved loops and markers), the
> Metronome, the Journal and Practice log, and the Toolkit are free. Practising (exercises, routines,
> Today's session, the loop trainer) is the plan: a monthly auto-renewable subscription with a
> one-week free introductory offer, or *Pay once*, a non-consumable. Both can be bought with a
> sandbox account. To reach the plan screen, tap **Practice** on the home screen. Every practising
> screen leads to it until the plan is bought, and **Restore purchases** is on the same screen.
>
> **To try the song player, open the Song library and tap "Try the demo".** That adds a playable practice track so you can try the waveform, loop
> capture and speed control immediately. You can also import your own audio from the
> Files app; the app plays DRM-free local and iCloud Drive files only, and never
> Apple Music streaming audio. The app requests **no** access to your music library —
> it uses no MusicKit and no media-library API.
>
> **Microphone:** used for the tuner (detecting the pitch of a played string) and for
> optional practice recordings the player starts themselves. Audio is analysed and
> stored on the device and is never uploaded — the app has no audio upload path.
>
> **Notifications:** asked for only when the player switches on a practice reminder for
> one of their routines.
>
> **Privacy:** all practice data is stored locally on the device. There is no
> cross-device sync and no user account. The app collects no usage data and contains
> no analytics. No advertising identifier is collected and no third-party SDK of any
> kind is present.

**Before pasting, re-check each claim still holds** — a stale one is worse than no
note at all. For 1.4, confirm the plan sentence on the TestFlight build during the sandbox pass:
**Practice** on the home screen opens the plan screen, and *Restore purchases* is on it. In particular the free/plan line (ADR 0256, 0263), "no analytics"
(ADR 0239), and "Try the demo" ([`LibraryView.swift`](../Pocket/Features/Library/LibraryView.swift),
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
`docs/privacy-policy.md` as revised by **ADR 0239**: no accounts, data stored **on
the device** (there is no cross-device sync — `Pocket.entitlements` holds no iCloud
entitlement, only the App Group the share extension uses on the same phone (ADR 0264), and no
CloudKit database is configured, ADR 0145), your playing never transmitted, and **no
usage data collected** — no analytics, with usage figures coming from App Store
Connect. The region-split usage counts of ADRs 0120 and 0147, and Aptabase as a
processor, must come out of the live section. Give
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

## Screenshots — 1.4 (2026-10-27, ADR 0279)

Ten frames, one story: the four verbs twice, then the roof. Shot dark at 09:41 on the iPhone 17 Pro
Max simulator by the manual's harness, with the plan unlocked (no padlocks, no prices: Guideline
2.3.7), and captioned by `scripts/appstore-frames.swift`. The finished set is in
`~/Documents/Red Moon Screenshots 2/appstore-2026-10-27/`: **`6.9/`** (1320×2868) and **`6.5/`**
(1242×2688). Upload whichever size the iPhone slot asks for, in filename order.

| # | Verb | Headline | Capture (test → slug) |
|---|---|---|---|
| 1 | WORK IT OUT | Loop the bar you can't play. Slow it down. | `AppStoreShots.testWorkItOut` (Binta's *Chords* at 0.75×) |
| 2 | BUILD IT UP | Every drill runs against a click. | `exercises/run-live` |
| 3 | RUN IT | Line up the hard parts. Press play. | `AppStoreShots.testRunIt` (*Open mic, Friday*) |
| 4 | KEEP IT | Record a take. Note what you heard. | `journal/take-moments` |
| 5 | YOUR SOURCES | Keep the lesson beside the part it's for. | `references/section` |
| 6 | WORK IT OUT | Name the notes by ear. See them on the neck. | `reference/watch-on-neck` |
| 7 | BUILD IT UP | Ramp a loop up to full speed. | `reference/loop-automator` |
| 8 | RUN IT | Today's session, shaped by your goals. | `reference/practice-hub` |
| 9 | KEEP IT | See the days you played. Never a score. | `journal/progress` |
| 10 | YOUR METHOD | Your songs, drills and routines, in one place. | `reference/home` |

**To shoot them again:**
1. `POCKET_SIM="iPhone 17 Pro Max" POCKET_SHOT_OUT=build/shots-appstore POCKET_SHOOT_ONLY=AppStoreShots ./scripts/shoot-manual.sh`
   for frames 1 and 3. Their images land in `build/shots-appstore/export/`, named in its `manifest.json`.
2. `POCKET_SIM="iPhone 17 Pro Max" POCKET_SHOT_OUT=build/shots-appstore-manual POCKET_SHOOT_PASS="base player exercises map" ./scripts/shoot-manual.sh`
   for the rest (`filed-partial/`).
3. Write a `frames.json` from the table, then `swift scripts/appstore-frames.swift frames.json <out>`.
   A non-breaking space (`\u00a0`) keeps two words of a headline together.

*Watch-outs:* frame 4's take is on *I'd Rather Go Blind (Cover)*, one of the seed's covers credited to
Jack Trader, so a real song title is on screen. Frame 5's links read `example.com`. The practice log's
lower half (`journal/month-heatmap`) is unusable as a frame: its header ghosts under the navigation bar,
and it ends on *0 Mastered*.

## Screenshots — REVISED shoot guide (re-shoot, 2026-07-21) — history

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

### 1.4 (2026-10-26): work through this one

**App Store Connect**
- [x] The version record renamed from 1.2 to 1.4 (2026-10-26)
- [x] The new age-rating questions answered (2026-10-26). Since 2026-01-31, App Store Connect won't
      take an update without them
- [x] Paid Applications Agreement active (checked 2026-10-26)
- [x] Subscription group **Red Moon** created, with the display name *Red Moon* (English U.K.)
- [x] The monthly, `click.decooperations.pocket.plan.monthly2`, created in it: 1 month, £0.99
- [ ] The monthly's introductory offer: Free, 1 week, all countries, no end date
- [x] Pay once, `click.decooperations.pocket.plan.payonce`, created: non-consumable, £14.99
- [ ] Family Sharing **off** on both (ADR 0259). It can't be turned off once it's on
- [ ] Read the US prices App Store Connect generated for both products, and decide whether to keep
      them (ADR 0256 D1)
- [ ] A review screenshot of the plan screen on **both** products, from the TestFlight build
- [ ] The old *Red Moon Pro* products (`…pro.monthly`, `…pro.annual`) confirmed removed from sale.
      `…plan.monthly` is spent: never reuse it (ADR 0277)

**The build**
- [ ] #383 merged, and main's UI job green (`scripts/main-ui-green.sh`, ADR 0255)
- [ ] Archived from main in Organizer with **Xcode 26.5**, not `testflight.yml`, which is pinned to
      Xcode 16. Apple has refused uploads not built with the iOS 26 SDK since 2026-04-28. After
      `xcodegen generate`, re-tick automatic signing on **Pocket and PocketShare**
- [ ] 1.4 (8) processed, and attached to version 1.4

**On the phone (TestFlight, sandbox)**
- [ ] Purchases: never bought → the plan screen · the free week and Home's countdown · cancel ·
      Pay once · Pay once while the monthly renews → the cancel-the-monthly flow · reinstall and
      Restore purchases · lapsed. A sandbox account gets the free week once per group, so use a
      fresh tester to see it again
- [ ] Save to Red Moon from YouTube, Files and Photos: never bought, lapsed, on the plan
- [ ] Still owed from #379: Mail, Messages and AirDrop; a WhatsApp `.opus` voice note; the *Added*
      alert over a running routine
- [ ] Upgrade 1.3 (7) → 1.4 (8), on a device that doesn't hold your own practice history. 1.3 (7)
      expires from TestFlight in early December

**The listing**
- [ ] Name *Red Moon Practice Studio* (done), subtitle and keywords
- [ ] Promotional text replaced
- [ ] Every text field pasted through `./scripts/export-listing.py --copy <field>`, never from this
      file. The description carries the *One plan* block, the promise and **the EULA line at the end**
- [ ] The description's £ prices: if English (U.K.) is the only English localization, every
      storefront reads them. Decide whether to add English (U.S.)
- [ ] *What's New — 1.4* pasted
- [x] Screenshots: the 1.4 set is shot (see *Screenshots — 1.4*). No price, padlock or "free" in any
      of them (2.3.7)
- [ ] Screenshots uploaded to version 1.4, in filename order, after deleting the 1.1 set it carried
      over (which predates the hub, the sheets, References and the plan)
- [ ] App Privacy re-checked, *Purchases* included
- [ ] App Review notes pasted, after the sandbox pass confirms the plan sentence

**Submit and release**
- [ ] One submission: version 1.4 (8), the *Red Moon* group, the monthly and Pay once. A new group
      goes to review with its first subscription and a build that shows it (what cost 1.1 two
      cycles)
- [ ] Version release: **Manually release this version**
- [ ] On approval: release it, then **turn availability back on** (Pricing and Availability ▸ App
      Availability). It has been off since 2026-08-07, and nothing in App Store Connect warns you
- [ ] `uk-site`: the prices, the founding-price wording, the free line, *practice studio*, privacy
      §Purchases and the terms. Keep the `#red-moon-practice` anchor. Push at go-live, with the real
      App Store link
- [ ] Tag `v1.4` on main

### History: the free release and 1.1. Don't work from these

**For the free release (ADR 0237), before anything below:**
- [ ] Both `…pro.annual` and `…pro.monthly` and the **"Red Moon Pro"** group removed from
      sale in App Store Connect
- [ ] Description pasted from above, with **no** subscription or EULA lines, no usage
      counts, and no "no ads" as a selling line
- [ ] Promotional text and review notes carry no subscription wording
- [ ] No screenshot shows the paywall, a padlock or a PRO badge
- [ ] App Privacy: nothing declared under Purchases
- [ ] App Privacy: **Product Interaction removed** — there is no analytics (ADR 0239);
      the three contact-form types stay
- [ ] `decooperations.co.uk/privacy` Red Moon section: usage counts, the region split,
      *Settings ▸ Privacy* and Aptabase removed, matching `docs/privacy-policy.md` (ADR 0239).
      Written in `uk-site` PR #75, with the free-price and file-sending changes; merge it
      when the free build is live
- [ ] Paid Applications Agreement kept or dropped — the owner's call

**The 1.1 checklist, kept as history:**
- [ ] Subtitle, promotional text, keywords, description entered (above)
- [ ] ~~🔴 **Terms of Use (EULA) URL is in the Description**~~ — **no longer applies**:
      Red Moon sells no subscription (ADR 0237). The 1.1 note, for the record:
      `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`, bare text, at
      the end. **This is what rejected 1.1 (3) on 2026-08-08**, automatically and before
      any human review. Guideline 3.1.2 wants it in the metadata *as well as* in the
      binary; the binary half has been right since ADR 0144 (`PaywallView` + Settings ▸
      About), so the description is the only place that can fail. Re-check this on every
      version whose description is retyped — a locked, released version's description
      cannot be edited, so the mistake is only ever fixable *before* approval.
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
- [ ] ~~App Privacy answered: Product Interaction → Analytics → not linked, not tracking (ADR 0120)~~ — superseded: analytics removed by ADR 0239; see the free-release list above. The original line: **Unchanged by ADR 0147** — the nutrition label encodes collection type, linkage and tracking, none of which the region split moves
- [x] ~~`APTABASE_APP_KEY` set in `project.yml` from the real EU-region app key (done 2026-07-29)~~ — the key, the SDK and `AptabaseSinkTests` were all removed by ADR 0239
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
