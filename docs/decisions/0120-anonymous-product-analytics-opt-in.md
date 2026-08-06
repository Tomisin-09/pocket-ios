# ADR 0120 — product analytics are anonymous, opt-in, and can never carry what you played

- **Status:** Accepted — **§2 and §3 superseded in part by ADR 0147**; §1, §4–§7 stand
- **Superseded in part by:** **ADR 0147** (2026-08-06). UK statute moved: DUAA 2025 Sch A1 para 5, in
  force 5 Feb 2026, exempts first-party service-improvement analytics from PECR reg 6 given clear
  information and a simple means of objecting. So §2's **opt-in default** and §3's **ask after a first
  practice** now apply to the **EEA + CH only**; the UK and rest of world get inform-and-object with
  the default on, and the disclosure moves into the first-run intake.
  **Read this before reopening the argument:** §2 below already concedes that Aptabase's anonymity is
  real *and* that it is not the unlock — the binding test is ePrivacy Art 5(3) / PECR reg 6, which
  applies irrespective of whether the data is personal. That reasoning is unchanged and 0147 does not
  rest on it. §1 (Tier 3 closed permanently), §4 (closed vocabulary + its SwiftLint rule), §5, §6 and
  §7 are untouched — and §4 in particular is *load-bearing for* 0147, whose legal basis is conditional
  on the vocabulary staying narrow.
- **Date:** 2026-07-29
- **Extends:** ADR 0092 (AI strategy — "your playing never leaves your device" is load-bearing there
  too), ADR 0112 (freemium — the paywall gates this now reports on)
- **Number note:** 0120 was reserved for this ADR while ADRs 0121–0127 shipped ahead of it (see the
  note in ADR 0127). This closes the gap.
- **Ratifies:** the decision taken 2026-07-28 during marketing-strategy work and recorded in
  `docs/backlog.md` §Slice 8, and the earlier 2026-07-16 "v1 = Apple-only" entry it supersedes.

## Context

Red Moon Practice v1.0 is approved by App Review and deliberately held from distribution. Until this
change the app collected nothing at all: an empty `NSPrivacyCollectedDataTypes`, no network calls of
any kind, and a repo-wide grep for `analytics|telemetry|consent` returning zero hits.

That purity has a cost, and it is now the binding one. Every product decision is being made on
conviction rather than evidence. The sharpest example is already in the backlog: the proposed
five-song import cap on free was scrapped because "the slow-downer is the strongest acquisition
hook" — a belief nothing in the app observes. The same is true of the free-vs-Pro line, of whether
the seeded first-run set actually shortens time-to-first-practice, and of which of the thirteen
exercise templates anybody uses.

Launch week is the only cohort that can answer "does a cold install reach a first practice", and it
is unrepeatable. Shipping without instrumentation would forfeit it permanently. So this lands
**before** distribution rather than as a 1.0.1 fast-follow.

The constraint is that the privacy posture is not marketing garnish. It is the durable claim the
product rests on, it is what ADR 0092 needs to remain true when the Oracle AI tier arrives, and it is
something the gamified competition structurally cannot say. Analytics has to be built so that claim
survives being read carefully by someone hostile.

## Decision

### 1. Anonymous product analytics, and nothing beyond it — Tier 3 is banned permanently

The agreed ladder, restated so it is not re-litigated:

- **Tier 1 — anonymous, unlinked product analytics.** What this ADR builds.
- **Tier 2 — attribution via AdAttributionKit and Apple Search Ads.** The ceiling. Campaign-level
  CAC with no ATT prompt and no IDFA. Not built here; a separate slice with no code overlap.
- **Tier 3 — IDFA, the ATT prompt, MMPs, ad SDKs. Ruled out, permanently.**

Tier 3 is not deferred, it is closed. The ATT prompt converts at roughly a quarter industry-wide, so
it would cost the privacy claim outright in exchange for a fraction of the signal — while Tier 2
already yields campaign-level attribution for free. This is a boundary of the same character as
ADR 0070 (Pocket never grades playing) and ADR 0092 (AI limits): a thing we don't do, not a thing we
haven't got round to.

Rejected alongside it: Firebase, Amplitude and Mixpanel, all of which contradict the ethos and drag
in identity graphs we would then have to explain.

Marketing-site ad pixels remain permissible behind a consent banner. That is a web decision about a
separate repo and does not touch the app's privacy manifest; the two were explicitly separated.

### 2. Opt-in, defaulting to off — because of ePrivacy, not GDPR

> **Superseded in part by ADR 0147 — now EEA + CH only.** The ePrivacy reasoning below is unchanged
> and still governs the EEA. The UK left it by statute (DUAA 2025 Sch A1 para 5), so UK and
> rest-of-world default to on with a disclosure and an objection control.

Analytics is **off** until the player explicitly turns it on.

The reasoning matters, because the obvious argument points the other way. Aptabase's data is
irreversibly anonymised rather than pseudonymised, which genuinely does take it outside GDPR proper
— GDPR governs personal data, and this isn't. Aptabase says so, and it is right.

But **ePrivacy Article 5(3) / PECR regulation 6 is the stricter test here**, and it governs storing
or accessing information on a user's terminal equipment *irrespective of whether that information is
personal*. Product analytics has never qualified for the "strictly necessary" exemption — the ICO's
published position is explicit — and EDPB Guidelines 2/2023 read "gaining access" broadly enough to
catch an SDK reading device characteristics. The conservative reading is consent, and for a product
whose entire differentiator is this posture, the conservative reading is the only defensible one.

Worth recording so the boundary of the exemption is clear: the strictly-necessary carve-out *does*
cover everything the app already stores — the `UserDefaults` preferences, the SwiftData library, and
the analytics consent flag itself. Those deliver a service the user explicitly asked for. Only the
new analytics needs an ask. And there are no cookies anywhere in this: it is a native app, and the
cookie-banner question belongs entirely to the marketing site.

**The cost is accepted and should not be forgotten:** at typical consent rates, absolute numbers
become meaningless. Only *ratios* survive. That is tolerable precisely because every question below
is posed as a ratio between two event counts.

This is not legal advice and the area is contested; a professional check is cheap and worth doing
before there is any real scale.

### 3. The ask comes after a first practice, not at first run

> **Superseded in part by ADR 0147 — now EEA + CH only.** Where the model is inform-and-object, the
> disclosure is a footnote in the first-run intake instead, which reclaims the "permanently
> unmeasurable" cost recorded below. The objection to a fifth intake *step* still stands: 0147 adds a
> footnote that asks nothing, not a screen with a decision in it.

The consent prompt is the **last rung** on the existing first-run ladder in
`HomeView+ProfileMoment.swift`, after the curation intake (ADR 0113) and the earned-a-name
invitation, and it is gated on `AppSettings.hasPracticed`.

The alternative — a fifth step in `ArtistIntakeView` — was rejected on its own terms. Analytics
exists to measure whether a cold install reaches a first practice; putting another screen in front
of that flow would tax the exact metric it is there to observe, and would ask for trust before the
player has any reason to extend it. Asking afterwards, when they have felt what the app does, is
both kinder and better-converting.

Two consequences are accepted deliberately:

- **The intake flow and the first session are permanently unmeasurable.** No event may be buffered
  before consent and flushed afterwards — that would defeat the point of asking. What we recover
  instead is the `since_install` bucket on every later `practice_started`, which is also the closest
  an identifier-free pipeline can get to a retention curve.
- `hasPracticed` is set when a run **starts**, not when one finishes. A player who always stops a
  ramp early would otherwise never be asked at all.

Declining is a full-width, equally reachable target, and consent defaults to `false`, so every other
exit from the sheet — including any dismissal path added later — leaves analytics off by
construction. A consent screen that nudges makes the privacy claim a lie.

### 4. The vocabulary is closed, and the type system is what closes it

`AnalyticsEvent` is an enum whose associated values are **only other enums, `Int`s and `Bool`s**.
There is no `String` parameter anywhere in the type, so emitting a song title, a file name, an
artist name or a journal note is *structurally impossible* rather than merely discouraged. One pure
`payload` computed property is the only place an analytics string is constructed, and every text
value is an enum's `rawValue`.

Backed by the repo's first SwiftLint `custom_rules` entry, scoped to the vocabulary file, which
fails the build on a labelled `String` associated value. The type system holds the line today; the
lint rule stops it being dissolved in six months by someone adding "just one" string.

Two further rules the vocabulary obeys:

- **Event names are a frozen wire format.** A Swift case can be renamed freely; an emitted string
  cannot, because there is no way to stitch an old and new dashboard series together afterwards.
  `AnalyticsEventTests` pins every name and payload key for exactly that reason.
- **Nothing that grades playing.** No mastery ratings, no achieved tempo, no accuracy. ADR 0070
  holds, and telemetry must not become a back door into it.

Thirteen events, deliberately: a larger set goes unread, and the hosted free tier is 20k
events/month. Nothing fires per-beat or per-tap.

### 5. Aptabase Cloud, EU region

Chosen over TelemetryDeck, the other serious candidate, for one reason that outlives the choice:
Aptabase is MIT-licensed and self-hostable, and its Swift SDK accepts a custom host, so moving the
data onto our own infrastructure later is a configuration change rather than a rewrite.

**Building our own was considered and rejected**, despite the AI proxy (ADR 0002) meaning we will
have a backend eventually. A Claude proxy is stateless request forwarding; an analytics service is a
data store with retention, deletion handling, dashboards, query and uptime. One does not justify the
other, and writing bespoke ingest is a project rather than a slice — for a product whose whole
differentiator is not needing a backend. If the data ever must live on our own box, the answer is
self-hosted Aptabase, not bespoke code.

What Aptabase can and cannot do, recorded so nobody builds toward the wrong thing:

- **It cannot do cross-session user metrics.** No identifier means no retention curve and no
  "hit the paywall Tuesday, bought Friday". Its dashboard is event counts with breakdowns, not a
  funnel or path tool.
- **Division of labour:** Aptabase answers which features get used and ratios like opened-vs-created.
  ASC App Analytics and StoreKit answer installs, retention, sessions and all revenue. Crash
  reporting stays with Xcode Organizer — free, no SDK, no consent.

### 6. The app key is the one carve-out to "no API keys in the client"

AGENTS.md says no API keys in the client, ever. Aptabase's App Key is a **write-only ingest key**: it
can post events and grants no read access to the dashboard, and it must ship in the client by
design. That is the carve-out, and it is narrow. The rule stands unchanged for the Claude proxy
credential (ADR 0002), which is a real secret and never leaves the backend.

One key, not one per configuration: the SDK's `TrackingMode.readFromEnvironment` stamps `isDebug`
from `#if DEBUG` and the dashboard separates debug traffic on its own.

### 7. There is no "off-the-grid mode" — dropped, deliberately

The backlog called for one. It was conceived while the plan was still opt-out, where a distinct
master switch would have been needed to turn everything off. **Opt-in makes off-the-grid the default
state**, and since the app makes no other network calls, such a mode would govern exactly one flag
while implying a far broader guarantee — the opposite of what this ADR is for. It would also be dead
scaffolding for the future Oracle tier, which ADR 0092 already binds to its own opt-in.

The **withdrawal control stays**: a plain toggle in Settings ▸ Privacy, required by ePrivacy and
promised in the consent copy. Consent is re-read on every single event, so switching it off stops
collection on the next event with no relaunch. It is a control, not a mode, and it should not be
rebuilt as one.

## Consequences

- **The public claim changes, and four artefacts move together.** "No account, no ads, no tracking,
  nothing sent anywhere" is no longer true and is replaced everywhere by the durable, defensible
  **"your playing never leaves your device"**: `PrivacyInfo.xcprivacy`, the ASC nutrition label,
  `docs/app-store-listing-copy.md`, `docs/privacy-policy.md` and the `decooperations.co.uk/privacy`
  Red Moon section. Any future change to what is collected must move all of them again.
- **A right-to-erasure request has nothing to erase.** There is no identifier, so there is no record
  to find. That is a genuine consequence of the design, not a dodge — and it is worth stating in the
  policy.
- **Offline sessions are under-counted.** The SDK's queue is in-memory only: it flushes every 60s and
  once on backgrounding and retries on failure, but events are lost if the app is killed while
  offline. Red Moon is built to work with no network and people practise with the phone face-down,
  so this bias is real and must be remembered when reading the numbers. The upside is that nothing
  is written to disk.
- **There is no kill switch.** With no backend, a runaway emitter can only be fixed by shipping a
  build. This is why the vocabulary is small and why every event whose host can re-appear
  (`TunerView.begin()` from `.onAppear`, `EarTrainingView`) carries a fire-once latch.
- **Delivery is flushed explicitly, per event, and must stay that way.** The SDK's `initialize` only
  *registers* an observer for `willEnterForegroundNotification` — it never calls `startPolling()`.
  Because we initialise lazily, with the app already in the foreground, that transition never
  arrives and the flush timer is never created; events would queue in memory until the app was
  backgrounded. Found on device (consent given, events emitted, dashboard empty until backgrounding).
  The fix is an explicit `flush()` after each `trackEvent`, which is an acceptable trade at a handful
  of events per session. Anyone removing it "to restore batching" re-introduces the bug.
- **Withdrawal is immediate for new events, but at most one already-queued batch may still flush.**
  Those events were collected while consent was live. The SDK offers no runtime disable.
- **A new binary means a new App Review.** v1.0 was approved as an app that collects nothing;
  re-review with a network-calling SDK is a slightly higher-variance profile. Low risk, but it now
  sits between us and release.
- **The repo has a third-party dependency for the first time**, pinned to an exact version because
  this is the one component that can send data off-device. CI has no SPM cache step, so it resolves
  from the network on every run, and Aptabase pulls `swift-docc-plugin` transitively.
- **`PaywallTrigger` gained associated values** and is no longer `String`-raw or `CaseIterable`.
  Thirteen gate call sites had collapsed into six cases; the template picker and the five routine
  producers now carry what was actually reached for, which is the evidence behind any future
  free-vs-Pro decision. The paywall copy is deliberately unchanged — it sells the capability, and
  "Build your own scales exercises" would be a narrower promise than Pro makes.
- **Two vocabulary cases were dropped during the build rather than shipped dead.**
  `PracticeSource.planner` could never fire (a planner session materialises an ordinary `Routine`
  and plays through `RoutinePlayerView` like any other), and `practiceFinished(ending:)` became
  `practiceCompleted` because a stop arrives by three different paths and an explicit "manual" event
  would double-fire or miss depending on the route. Abandonment is read as the gap between started
  and completed — a ratio of two counts, which is what the dashboard can actually answer.
- **The pipeline is live.** The EU app key is configured, so an opted-in player's events reach
  `eu.aptabase.com`. `AptabaseSinkTests.testTheBundledKeyIsPresentAndEURegion` pins both halves: that
  the key resolves out of the Info.plist at all (a blanked one would make analytics silently inert
  for everyone who consented) and that it is **EU-region** — the SDK derives its ingest host from
  that segment, so a US key would quietly route EU users' events to the wrong region and break the
  data-residency claim the privacy policy makes.
- **Unaffected:** ADR 0070 (no grading) — the vocabulary is deliberately free of mastery, tempo and
  accuracy. ADR 0092's audio boundary — no audio, no recording, no waveform data is ever sent.
  ADR 0112's entitlement logic — `AccessPolicy` is untouched; only the reporting axis changed.
