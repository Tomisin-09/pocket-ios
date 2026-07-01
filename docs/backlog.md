# Backlog

Deferred work that's intentionally parked — known, but not scheduled. Each item
notes enough context to pick it up cold. Promote to a branch (and an ADR if it
closes off an alternative) when it's time to act.

## Release sequencing (decided 2026-06-24)

The order below reflects a deliberate scoping call, not just priority:

- **V1 (first release):** practice screen + library + a richer **creation
  experience** + **notes/journal**. **No planner.**
- **Planner → V2.** Routine generation and goal-driven selection (ADRs
  0014 / 0015 / 0016) are designed but deferred to the second version. Don't
  treat the planner as "next" — notes/journal comes first.
- **AI layer → late phase.** Every AI feature (note summaries, suggested
  automator settings, etc.) is built only once the rest of the app is solid
  and the foundations are in place: the Claude proxy backend (ADR 0002, still
  paper-only) and a settled pricing/cadence model. Cleanly separable from the
  user-editable foundations below — build those first, gate AI behind them.

## Launch readiness (pre-submission gate)

From a full pre-launch audit (2026-06-25). The code itself audited clean —
SwiftLint `--strict` 0 violations, build 0 warnings, 313 tests green, no
force-unwraps / `as!` / `fatalError` / debt markers, accurate privacy manifest,
minimal justified permissions. The gating work is **submission assets/config**,
not code. Re-run the audit any time with the `/ready-to-ship` skill.

**Hard blocker — must exist before a build can be submitted:**

- **App icon + asset catalog.** There is no `.xcassets` anywhere and no
  `AppIcon`; the built `.app` ships no icon/`.car`. Apple rejects any app
  without an icon and App Store Connect won't accept the build. Add
  `Pocket/Resources/Assets.xcassets` with an `AppIcon` set (1024px marketing
  icon min) and wire `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in
  `project.yml`. *Needs design artwork — that's the only blocker requiring a human.*

**Should-fix before submission (no code dependency):**

- **`ITSAppUsesNonExemptEncryption = false`** in `Info.plist` — app uses no
  custom crypto; setting this skips the export-compliance prompt on every upload.
- **Bump `MARKETING_VERSION` 0.0.1 → 1.0.0** in `project.yml` for a public release.
- **Delete `Features/Planner/HomeView.swift`** — dead "Phase 0 scaffold"; the app
  entry renders `LibraryView()`, `HomeView` is referenced only by its own preview.

**Robustness (optional):**

- **Audio-session errors are swallowed** (`PracticeAudioEngine` `configureSession`
  / `startEngineIfNeeded` use `try?`). For an audio-first app a failed session =
  silent no-sound with no user signal. Consider logging or a one-time
  "couldn't start audio" state.

**Standing dev guide — keep new features launch-ready as you build:**

- **Privacy manifest is a living file.** Any new required-reason API
  (file timestamps, system boot time / `mach_absolute_time`, disk space) or any
  off-device data send (e.g. the AI phase's Claude proxy) must add the matching
  `NSPrivacyAccessedAPITypes` / `NSPrivacyCollectedDataTypes` entry in
  `PrivacyInfo.xcprivacy` *in the same PR*. Today's manifest declares only
  UserDefaults (CA92.1); don't let it drift.
- **Permissions stay minimal & specific.** Add an `Info.plist` usage string only
  when a shipping feature exercises it (the parked pedal modeller's mic string is
  correctly absent). Vague strings cause rejection.
- **No live host in Release until the proxy exists.** The Release `POCKET_API_HOST`
  is a placeholder and nothing calls it (zero `URLSession` in V1). Before any
  networked feature ships, replace it and guard against the placeholder leaking
  into a release build.
- **The audit gate is the bar.** A feature isn't "done" if it adds a force-unwrap,
  a silent `try?` over real user data, a TODO marker, or a new entitlement/permission
  without justification. Run `/ready-to-ship` before calling V1 shippable.

## Branding & naming — "Red Moon" (workshopping, 2026-06-25)

Candidate rename of the product from "Pocket" to **Red Moon**, after *Red Moon*
by Tom Misch — the track that turned the idea into a working prototype, and the
song the build keeps getting tested against. The origin story is the moat; the
name carries it.

- **Brand = "Red Moon"** (spoken/marketing). Resist baking a descriptor into the
  brand itself; let an App Store **subtitle** do the functional work (e.g. "Loop,
  slow down, and learn any song"). Keeps the name ownable as the product grows
  past any one feature (it's practice + library + creation + notes, not just loops).
- **Logo:** simple red-moon disc. Colour **#C73818** (burnt vermilion) — not a
  compromise on "red", it's the *actual* colour of a blood/harvest moon, so lean
  into it. Keep one ownable detail that survives at icon size (soft blood-moon
  glow, or a faint crescent shadow so it reads as a moon, not a dot). Feeds the
  hard-blocker **App icon** item above.
- **Name-clearance findings (web search 2026-06-25):** the iOS music/practice
  lane is clear — no "Red Moon" practice/looper app exists. Flags, none fatal:
  1. **"Red Moon Fitness" already on the App Store** — different category (no TM
     issue), but Apple requires unique app *names*, so the bare string "Red Moon"
     may be partly encumbered; expect to need a qualifier to register.
  2. **"Red Moon Label" is an active record label** (+ a RedMoon DJ on
     SoundCloud) — music-services overlap (TM Class 41); not a software blocker,
     but "red moon music" SEO won't be ownable. Glance at this if filing a TM.
  3. **"Red Moon" (Android blue-light filter)** — dormant, Android-only,
     unrelated function; only muddies Google results.
  4. **The song itself** dominates search — a discoverability headwind, not legal;
     arguably on-brand.
- **Next action (do early — resolves flag #1 definitively):** log into App Store
  Connect and try to **reserve "Red Moon"** as the app name. If taken, that
  decides the qualifier (e.g. "Red Moon: Practice"). Reservation is free and
  immediate.

## Near-term (active, not parked)

These are scheduled to be picked up shortly — listed here so they're not lost.

- **Practice — exercise creation entry point (design experiment).** The create sheet now asks
  for **command tempo** explicitly (working floor + reach derive from it), which fixes the
  earlier mismatch where the entered "working" number resurfaced as "command" on the run screen
  (ADR 0046, branch `pocket-067`). Open question worth A/B-ing: is command the best single number
  to anchor an exercise on, or would starting from the **working** tempo (where you actually
  practise today) or the **target/reach** (the goal) read more naturally to a musician? Try the
  variants and pick the one that needs the least explanation.
- **Loop tags — show existing as well.** DONE (branch `pocket-055`): the tags
  already on a loop now render as removable chips matching the suggestion-chip
  language, in the loop edit sheet. Tags stay edit-sheet-only — no loop-row display
  (ADR 0034 gating holds).
- **Landscape — practice screen only.** DONE (ADR 0042, branch `pocket-056`):
  the practice screen rotates to landscape (waveform claims the width, loops/markers
  to a ~30% side rail); every other screen stays portrait. The bottom song-info
  panel was removed in the same pass.

## Notes & journal — DONE (ADR 0038)

Shipped in PR #50: a per-loop **practice journal** (dated entries snapshotting
mastery + command tempo at write time, immutable; typed entry kinds) opened from
a book icon on the loop row, plus **song notes** (free-text `Song.comment`)
editable inline in the song details sheet. Narrowed ADR 0012's three-scope
forecast to loop-only; markers get neither. AI summaries over the journal remain
in the AI phase (below).

## Loop experience (sense-check decided 2026-06-24)

Outcome of a UX review of loop properties + the loop-making flow. Numbering
matches the discussion thread.

**#2 + #4 — DONE (ADR 0039).** The loop row now surfaces **mastery** (dots) and
**command tempo** (a percent badge, the achievement) under the name, shown only when
set — last-practiced speed is *not* shown. The three judgment fields (**mastery,
command tempo, focus**) became Optional with an explicit "unset" state, so a default
never masquerades as a rating (the `1.0` command-tempo "100%" lie is gone). Existing
loops migrated to `nil` for free; `MasteryRollup` skips unrated loops; the edit sheet
gained set/clear affordances (dot walk-down, command-tempo Set/Clear, focus menu).

**#3 — DONE (ADR 0040).** Each loop now remembers the speed you last practised it at
(new `Loop.lastPracticedSpeed`, kept separate from `loop.speed` = automator ramp start to
avoid clobbering it). Persisted on leave via a single `activeLoopID` `didSet` choke point
(not per slider tick); arming a loop — tap or transport skip — restores its speed, falling
back to `loop.speed` when never practised. Session still opens clean (full song, 1×),
refining ADR 0029. The user-defined toggle (loop speed always = command tempo *vs* last
playback) stays V2.

**#6 A/B as the creation primitive — DONE (ADR 0041, branch pocket-054).** The
ephemeral A↔B span is now the single creation primitive: tap A/B to set A then B (or
hold-drag), the span loops with no ✓/✗ gate, its labelled A / B handles drag in place,
**Save as loop** persists it. Dragging a saved loop's edge lifts it back into A/B for a
range edit (**Save changes** writes back), dissolving the three-hop range edit. **Fine
mode and the capture/confirm system were retired** — the transport left column is now
A/B · Marker. Built in 5 slices (pure `ABSpan` state machine → play-along set → handle
adjust → range-edit lift → Fine retirement + hold-drag wiring).

**V2 / planner-era:**

- **#4 test-data seeding** to exercise the planner before real fill-rate exists.
  Validates planner *logic*, not fill-rate — only real usage shows whether users
  actually fill the fields.

**Parked — deliberate, leave as-is:**

- **#5 Multi-select loops:** parked until the friction is real. Useful for bulk
  delete / cleanup and batch re-tag / type / focus, but it's a *scale* feature —
  it only pays off with many loops, or once the planner makes bulk-focus a real
  workflow. At a handful of loops, one-at-a-time editing doesn't hurt, so building
  the selection-mode UI now is speculative. *Inheritance and duplicate were
  considered and rejected* — multi-select is the only bulk move we'd want.
  **Revisit when** one-at-a-time editing starts to hurt, or when the planner lands.
- **#1 Marker→loop bridge:** not needed as an explicit action. Markers already
  snap loop edges during creation (ADR 0021), and a marker is approximate, so an
  "exact marker→loop" would mislead. The passive snap is the right amount.
- **#7 Resume-to-last-loop:** leave as-is (ADR 0029 wipes the active loop on
  exit); revisit via A/B test. Could ride on the `lastPracticed` field cheaply if
  reconsidered.
- **#8 "Loop 1/2/3" naming:** deferred naming (ADR 0019) stays — if a loop's
  unclear you play it to remember, and the glanceable row (#2) lowers the cost
  further.

## Practice run-setup — persist loop ramp shape (parked, after Cluster 4)

Follow-up recorded in **ADR 0057**. The loop run-setup screen exposes four
ramp-shape controls — warm-up intermediate steps, reach steps, back-off steps,
reps per step — that **don't persist**: only `speed` (working) and `commandTempo`
(command) round-trip today, so **Save Changes** never appears for the four, and
they reseed to defaults each visit. Exercises already persist the full shape
(`rampStepBPM` / `rampIntervalCount` / `rampReachSteps` / `rampBackoffSteps`).

**Plan — add four *dedicated* `Loop` fields, decoupled from the legacy automator.**
Do **not** reuse the ADR-0013 automator fields (`automatorStepCount`,
`automatorLoopsPerStep`): they're the waveform-screen ramp with different
semantics ("steps to target" vs "intermediate stops between working and command"),
and coupling the two ramp systems to save four fields is a bug magnet. Add
`rampWarmupSteps` / `rampReachSteps` / `rampBackoffSteps` / `rampRepsPerStep` with
**declaration defaults** (CoreData 134110 rule → additive lightweight migration,
no store wipe). Then: `LoopSetupState` gains the four (so `isDirty` fires for
them), `seedIfNeeded` reads them off the loop, and the shared `persist()` writes
them back. Tests: persist round-trips all four; `isDirty` triggers per field.
**Gate:** it's a live schema change — must be device-verified against a store that
predates the fields (the SwiftData migration-crash lesson), not just in-memory
tests. Scheduled **after** the remaining Cluster 4 items land.

## Loop & marker creation

- **A/B ephemeral span ("not saved").** A transient A↔B selection the musician
  sets on the fly to rehearse **several consecutive saved loops together as
  one**, without persisting a new loop. Distinct from saved region loops
  (ADR 0006); think scratch/rehearsal span. Net-new. *Note:* the A/B span is now
  also the basis for **#6 (A/B as creation primitive)** above — build the span
  once, serve both the rehearsal and the save-as-loop use.
- **Loops accessible outside their song?** Open question. Today a `Loop`
  belongs to one `Song`. Cross-song access is largely what the **planner**
  delivers (pulling loops across songs into a session) and ties to cross-song
  filter-by-tag (deferred in ADR 0034). Revisit when the planner (V2) lands;
  decide whether anything is needed before then.

## Onboarding — "the art of creating loops" + musician voice

A coherent vision, captured for V1's creation experience:

- **Guided creation flow, onboarding-only and skippable.** An opinionated,
  3-step path layered over the free-form practice screen, shown during
  onboarding; the user can skip it. Implementation approach TBD (the point now
  is to capture intent, not design the mechanism):
  1. **Listen whole** — original tempo, no speed changes. Think about parts you
     liked / want to recreate. Add a **first journal entry** (goals, aims).
  2. **Mark sections** — replay (author suggests ~0.8–0.9× tempo, musician's
     discretion) and drop **markers** on sections of interest. Markers set
     automatically with a standardised name (see marker auto-naming above),
     renameable anytime.
  3. **Create loops** — with the song signposted by markers, build loops from
     those positions (author suggests 50% tempo, playback starting at 50%,
     zoomed in to a set level).
- **Musician voice / ritual (cross-cutting design principle).** Address users
  as *musicians* throughout; use language that helps them internalise the
  identity. Frame **completing the first loop** as a small ritual — the moment
  you "become" a musician — felt via tutorial guides and docs/copy. When acted
  on, this belongs in `docs/design-brief.md` as a voice/tone principle and
  should then govern copy app-wide.
- **Rotary haptic zoom mode (net-new interaction).** A zoom mode where finger
  rotation acts like a physical dial/knob — direction-sensed, reflected in
  haptics (rotate one way to zoom in, the other to zoom out). Alternative/
  complement to pinch-to-zoom (ADR 0010). Self-contained; could ship
  independently of the guided flow.
- **Method provenance guardrail:** this flow encodes a practice author's method
  ("the author recommends…"). Per the content strategy, encode the **method**,
  never ship his words — all copy must be ours.
- **User-guide note — mastery vs command tempo are different axes.** When we
  write user guides/help copy, make explicit that **command tempo measures
  speed** (the fastest fraction you own a loop at) while **mastery measures
  cleanliness** (how well you own it). They're deliberately separate fields
  because *for a lot of material the bottleneck isn't speed* — tone, feel,
  expression, a single hard change can be unmastered at full tempo, and a slow
  passage can be perfectly owned. Considered collapsing mastery into a
  derivative of command tempo (2026-06-25) and rejected it for this reason.

## AI phase (late — gated on backend + pricing)

Parked until the foundations above are solid (see Release sequencing). Captured
so the intent isn't lost:

- **AI note summaries** over the song/loop timestamped logs — user-editable
  stays; the AI proposes a summary on top.
- **AI-suggested automator settings** derived from a loop's notes/journal (the
  speed-trainer ramp). Loop notes reachable from the automator make this the
  natural surface.
- **Cadence & monetization question (open):** how often should an AI summary
  refresh? Candidate: ~24h (or weekly) on a free tier, daily/hourly behind
  pay — find the sustainable balance without burning backend cost. Decide
  alongside the backend build (ADR 0002).

## Haptics — configurable section (parked, build at finishing-touches)

Decided 2026-07-01. Two motion-tracking haptics are worth adding, but only as an
opt-in that stays out of the way by default. **Build these when putting the
finishing touches on the app**, not now — an empty Settings section with dead
toggles is exactly the scaffolding the launch-readiness gate warns against, so
the Settings UI and the mechanism ship together.

**Settings — dedicated "Haptics" section.** Today there's a single `Haptics`
toggle in the *Feel* section of `SettingsView`, governing gesture-confirmation
taps (`AppSettings.hapticsEnabled`, default **on**) — leave that as the master
switch. Promote it into its own **Haptics section** that gains the two toggles
below, each a new `AppSettings.Key` following the existing `resolvedBool`
default-resolution idiom. Both **default off** (opt-in), and both are gated by
the master `hapticsEnabled` switch.

1. **Playback-tracking haptic** — pulses on **bar-line (downbeat) crossings** as
   the song plays. Follows the real playhead, so it scales automatically with
   playback speed (slowing to 50% doubles the interval — a feature). **Gate it
   exactly like the gridlines toggle (ADR 0051): needs tempo + the "1" set** — a
   bar is meaningless without a downbeat anchor. Single medium-impact per bar for
   V1; no strength gradations. Silent during count-in (position-while-playing
   only) unless device testing says otherwise. *Not* a granularity picker
   (bars/beats/off) — bars-only is the opinionated default.
   - **Open sub-decision, revisit at build time:** a distinct heavier tap on the
     **loop wrap** ("I've heard this N times" by feel). Real value for looped
     practice; ship bars-only first and add as a fast follow if it feels missing.
2. **Scrubbing/drag haptic** — detents felt while **dragging the playhead** as it
   crosses bars/beats/markers (the tactile "notch" of scrubbing past a
   structural point). Distinct from the playback pulse; this one fires only
   during an active scrub gesture. Snap points already exist
   (`WaveformPracticeModel+Snap`), so reuse that geometry.

`Haptics.swift` (`Pocket/Features/Waveform/`) is the existing helper both would
route through.

## UI / polish

- **Fine-tune the song details sheet.** `SongDetailsSheet` (opened by holding the
  song title on the practice screen) currently stands up the read-first overview on
  a plain SwiftUI `Form`. It works, but the presentation is a first pass. Candidate
  refinements:
  - Richer header treatment (artwork? larger title, tighter artist/album/year line).
  - A more bespoke descriptive layout than a stock grouped `Form` — spacing,
    grouping, and typography tuned to the app's design tokens (brief §3).
  - ~~Decide the relationship with the scroll-area `SongInfoPanel`~~ — RESOLVED
    (ADR 0042): `SongInfoPanel` was removed; `SongDetailsSheet` is now the single
    home for the song's key / mastery / collections.
  - Consider inline editing vs. the current Edit → `SongEditSheet` hop.
  - Surface tempo precision / downbeat state if useful (currently shows rounded BPM).
