# ADR 0239 — Red Moon counts nothing

- **Status:** Accepted. Built on `pocket-349-remove-aptabase` (2026-10-02). Still owed: the App Store
  Connect privacy label and the `uk-site` privacy section, both outside the repo (Consequences), and
  the reshoot.
- **Date:** 2026-10-02
- **Supersedes:** ADR 0120 — §2 to §7. Analytics, its consent and its withdrawal toggle, the closed
  event vocabulary and its lint rule, Aptabase as processor, and the write-only-key carve-out all go
  (D1, D2). **§1 is not superseded.** What it says about Tier 2 and Tier 3 is about attribution and
  advertising, not about counting, and this ADR decides nothing about either.
- **Supersedes:** ADR 0147 — all of it. With nothing collected there is no default to split by
  region, no disclosure to give and nothing to object to.
- **Amends:** ADR 0214 — **D7** goes: there is no `review_requested` event. **D2**'s ladder loses
  the analytics rung, so the review ask is the fourth rung, after the intake and the naming
  invitation. Every gate in D3–D6, and D8's permanent door, stand.
- **Amends:** ADR 0162 — **D2**'s *Privacy* row and its screen are removed, and **D7** with them.
  The hub has eight destinations.
- **Relates to:** 0237 (free — the paywall events had already gone, and the question changed) ·
  0161 (the contact form, now the only thing the app sends) · 0183 (MetricKit, which never went near
  analytics) · 0128 (the one insert path, which stands without its event) · 0149, 0220 (the
  activation measure, which this gives up) · 0187 (the Oracle's events had a vocabulary to join;
  parked by 0211, and not decided here)
- **Schema:** none. No `@Model` change. Four `UserDefaults` keys go inert (D4).

## Context

ADR 0120 put anonymous analytics into the app on 2026-07-29, so that product decisions would rest on
evidence rather than conviction. Most of the questions it named were about the paywall: where the
free-versus-Pro line should sit, and which gates players reached. ADR 0147 split the default by region
on 2026-08-06: off until asked in the EEA and Switzerland, on with a disclosure everywhere else.

ADR 0237 made Red Moon free on 2026-10-01. It is a portfolio piece, not a business, and the paywall
events left with the paywall. That changed the question from conversion to something simpler: is
anybody using the app, and do they come back?

A review of the analytics on 2026-10-02 found the vocabulary had fallen behind the app:

- **Practice inside a routine never completed.** Every block sent `practice_started`, but completion
  was wired only on the standalone path, so the started-to-completed ratio made every routine block
  look abandoned.
- **Most practice was not counted as practice.** Song play-along, ear-training loops, improvise loops
  and freeform blocks all write to the practice log and sent nothing. `PracticeKind.song` and
  `.earLoop` were declared and never sent.
- **`loop_created` meant two things.** The song map (0232) sent it once for every loop it made, and
  Undo did not take it back, so it no longer measured the hand-drawn loop it was chosen to measure.
- **ADR 0220 skipped its activation measure for a reason that wasn't true** for most players: it
  assumed nothing in the first session was observable, when under 0147 the UK and the rest of the
  world counted from install.
- Snags, the song map, versions, naming the notes, the journal and the starter song sent nothing.

Making the numbers answer the new question would have meant an instrumentation pass, and upkeep with
every feature after it.

**The cost of analytics was almost all fixed, not per event.** Adding or removing an event was one
enum case and a test. The cost sat in having analytics at all: the region split, the consent sheet,
the intake footnote, the Settings screen, the privacy text in the policy, the manual, the FAQ and the
company site, the App Privacy label, an SDK dependency, Aptabase's paid tier beyond 20,000 events a
month, and the professional legal check 0120 asked for and 0147 turned into a review of published
text. Cutting fifteen events to one would have kept every item on that list.

**And the question the owner asked, "just measure new sessions", already has an answer that costs
nothing.** App Store Connect's App Analytics reports installs, sessions, daily active devices,
retention by install date and crashes, with no code at all, and the App Store reports page views and
downloads. Its usage figures come only from people who agreed to share data with app developers, and
it shows that opt-in rate itself.

## Decision

### D1 — There is no analytics in the app

Red Moon does not count what a player does in it. There is no analytics SDK, no event, no consent
state and no setting. Usage questions are answered by App Store Connect.

The app makes no network call on its own. The only thing that leaves it is a support message the
player writes and taps Send on (0161), or a file they send themselves (0236).

### D2 — Everything that existed for analytics goes

- **The SDK and its wiring:** the Aptabase package, the only one the project had; its app key in
  `project.yml` and `Info.plist`; the Product Interaction entry in `PrivacyInfo.xcprivacy`.
- **The module:** `Pocket/Core/Analytics/` (`AnalyticsEvent`, `Analytics`, `AnalyticsPolicy`, the
  three sinks) and `AppSettings+Analytics.swift`.
- **The send sites:** all 32 of them, with the once-only latches in the tuner, ear training and
  improvise that existed only to stop an event repeating, and the abandonment tracking on the
  new-exercise sheet.
- **The surfaces:** `AnalyticsConsentSheet`, the footnote under the first-run questions, the
  analytics rung of Home's one-time ladder, and *Settings ▸ Privacy*, whose only control was the
  analytics switch.
- **The local bookkeeping that fed it:** `installDate`, `hasPracticed` and the install-age bucket.
- **The guard rails:** the `analytics_event_no_free_strings` lint rule and three test suites.

**Settings ▸ Privacy is removed rather than kept with nothing on it.** A screen with no control
would only label a fact. The privacy policy link stays in *Settings ▸ Help & About*, and the FAQ
answer *"Does Red Moon listen to or send my playing?"* says what is true now.

### D3 — What this gives up, stated plainly

- **Anything inside the app.** Whether people practise rather than just open it, which features they
  reach, and how long a new install takes to make a first loop (0149 §8's activation measure).
- **The launch-week group** 0120 landed analytics early to catch. It cannot be measured later.
- **Coverage.** App Store Connect sees only players who share with app developers.

Accepted. The activation gap of September 2026 was found by watching testers and reading the code,
not on a dashboard, and that is the kind of evidence this app has actually been moved by.

### D4 — The stored keys stay, inert, and their names are never reused

`analyticsEnabled`, `analyticsPromptSeen`, `installDate` and `hasPracticed` are left on upgraded
installs and never read. The only installs that have them are beta testers', since there has been no
public release. This is 0237's choice for its retired keys, for its reason: a sweep would be code
running on every launch to delete three booleans and a date nobody reads. A future key must not
reuse one of these names, or it would inherit a beta tester's old value.

### D5 — What the app says about it

The claim gets simpler: **Red Moon doesn't count what you do in it.** "Your playing never leaves
your device" still stands beside it.

Apple's figures are disclosed rather than left out. The FAQ, the manual and the privacy policy name
the iPhone's own switch, *Settings ▸ Privacy & Security ▸ Analytics & Improvements ▸ Share With App
Developers*, because "we collect nothing" would be true of the app and still leave out where the
totals the owner reads come from.

The line *"Red Moon does not use the advertising identifier or the App Tracking Transparency prompt,
and it never will"* is kept word for word. That is 0120 §1, which this ADR leaves alone.

### D6 — Bringing analytics back would be a new decision

If in-app counting is ever wanted again, it starts as a new ADR, not a revert. 0120 and 0147 are the
place to start: ePrivacy Art 5(3) for the EEA, DUAA 2025 Sch A1 para 5 for the UK, and a closed
vocabulary that cannot carry a player's text. Git history keeps the code. `c5a0ceb` is the last
commit on `main` with all of it.

The parked Oracle (0187, closed by 0211) expected its events to join that vocabulary. If it is ever
reopened, how it is measured is a question for that reopening. It is not decided here.

## Alternatives rejected

**Keep Aptabase and send one event, a session.** This was the question that started it. It keeps
every fixed cost above. Aptabase already stamps every event with a session that renews after an hour
idle, so a session event would add nothing it could not derive. App Store Connect answers the same
question for nothing.

**Freeze: keep the fifteen events and add none.** The cheapest option today, but it keeps the legal
check, the consent apparatus and four places of privacy text. Its numbers already misled in at least
one place (routine completions), and would drift further from the app with every feature.

**Instrument it properly.** The review's list was real work with upkeep after it, for a free app with
no paid media to attribute and no conversion to measure.

**Switch to TelemetryDeck, or self-host Aptabase.** Either keeps the same fixed costs with a different
name on them.

## Consequences

- **The public texts moved together, in this change:** `docs/privacy-policy.md`; the manual's
  privacy, settings, getting-started and home pages; the FAQ answer in `FAQEntry.swift`;
  `docs/app-store-listing-copy.md` (privacy label, review notes, hosting note, checklist);
  `docs/app-store-license-obligations.md`; `docs/design-brief.md` §4.3; `PROJECT.md`;
  `docs/architecture.md`; `AGENTS.md`.
- **Owed outside the repo, each on the owner's go-ahead:**
  - App Store Connect ▸ App Privacy: remove **Product Interaction**. The three contact-form types
    stay.
  - The `uk-site` privacy section (`app/privacy/page.tsx`): remove the usage counts, the region
    split, *Settings ▸ Privacy* and Aptabase as a processor. It belongs with the free release's site
    change.
  - The Aptabase app at `eu.aptabase.com` can be deleted once no build that sends to it is still in
    testers' hands. **Build 1.3 (7) still sends** for testers whose analytics was on, until they
    update.
  - The Marketing Foundation lists *"we say what we count"* among its five disciplines. It now reads
    *"we count nothing"*.
- **The professional check on the analytics lawful basis**, owed since 0120, is moot: there is
  nothing collected for it to review.
- **The project has no third-party packages.** CI no longer resolves one from the network on every
  run. `SWIFT_TREAT_WARNINGS_AS_ERRORS` stays on the target, Debug-only, because its reason holds
  for any package added later.
- **Figures.** `reference/settings-privacy` and `privacy/settings` are retired with the screen.
  `reference/settings-hub` (eight rows now) and `getting-started/first-run` (no footnote) are stale
  and go on the list for the one reshoot.
- **0128's single insert path stands.** It now exists because the preset seeder shares the factory,
  which was always half its reason. It no longer has an event to protect.
- **Unaffected:** 0070 (no grading), 0092's audio boundary, 0161's contact form and its three
  declared data types, 0183's diagnostics, and 0120 §1.
