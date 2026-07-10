# Backlog

Deferred work that's intentionally parked — known, but not scheduled. Each item
notes enough context to pick it up cold. Promote to a branch (and an ADR if it
closes off an alternative) when it's time to act.

## Release sequencing (decided 2026-06-24)

The order below reflects a deliberate scoping call, not just priority:

- **V1 (first release):** practice screen + library + a richer **creation
  experience** + **notes/journal**. **No planner.**
- **Planner → V2, SHIPPED (2026-07-10).** Routine generation and goal-driven selection
  (ADRs 0014 / 0015 / 0016) shipped across Slices 1–4 plus the review-refinements pass, player
  polish, and the reps follow-up (ADR 0076). The planner is functionally complete and live. What
  remains is the deferred tail — **AI decomposition** (gated on the AI phase) and the
  **learned-target reach default** — neither scheduled. See **Practice planner** under "V2 vision".
- **AI layer → late phase.** Every AI feature (note summaries, suggested
  automator settings, etc.) is built only once the rest of the app is solid
  and the foundations are in place: the Claude proxy backend (ADR 0002, still
  paper-only) and a settled pricing/cadence model. Cleanly separable from the
  user-editable foundations below — build those first, gate AI behind them.

## V2 vision (logged 2026-07-05)

The V2 direction was set in a scoping session; the thinking lives in dedicated
docs so this stays a pointer list:

- **Practice planner — ADRs 0014 / 0015 / 0016 (Accepted; IN PROGRESS).** The
  goal-driven session generator: two pure functions — `deriveCandidates` (front-half,
  0015) → `buildSession` (back-half, 0014) — that produce a `Routine` (ADR 0066) run by
  the shipped player. Fully designed 2026-07-08; **cold-start build plan:
  `docs/plans/planner-build-plan.md`**. Decisions locked: self-rated `Exercise.mastery`
  / `lastPracticed` feeding a `dueScore` (no grading — ADR 0070); broad
  `ExerciseTemplate → [SkillID]` skill resolution (no new per-exercise tagging); two
  candidate paths (technique → exercise, repertoire → loop/song via `Goal.targetSong`);
  soft prereq staging (reconciles ADR 0016 with 0071); in-house goal templates; loop
  skill-tagging as a phase-2 slice; **AI suggester deferred** — the planner ships fully
  local-first, no backend. The substrate (routine model + player + presets, PR #102)
  has shipped.
  - **Slice 1 — back-half + mastery parity: DONE (branch `pocket-112-practice-planner`,
    ADR 0072).** `Exercise` gained self-rated `mastery` + `lastPracticed`; pure
    `DueScore` + `SessionBuilder.buildSession` + warm-up LRU (Foundation-only,
    unit-tested); impure `PracticePlanner` projects/materialises a `Routine`; "Quick
    session" ✨ button in the Routines library is the first surface (dueness-only).
  - **Slice 2 — front-half: goals + candidate derivation: DONE (branch
    `pocket-112-practice-planner`, ADR 0073).** `TechniqueTaxonomy` + `SkillFamilyMap`
    (pure tables), `Goal` `@Model`, pure `CandidateDeriver.deriveCandidates` (Path A
    technique→exercise via the family map, Path B repertoire→target-song loops+run,
    soft direct-prereq down-weight), `GoalTemplateLibrary` (4 curated templates), and
    `PracticePlanner.planGoalSession`/library projector + loop/song materialisation
    (songs keyed by a deterministic `PlannerID`). Front-half composes with the back-half
    end-to-end; unit-tested (ADR 0015 property list). No UI yet.
  - **Slice 3 — planner UI: DONE (branch `pocket-112-practice-planner`, ADR 0015/0073).**
    `PlannerView` (the live "Build today's session" entry in Practice): duration selector
    (`SessionLength`), goals list, **Generate** → provisional `Routine` review → shipped
    player, with a no-goals Quick-session fallback. `GoalEditorView`: template picker →
    name → priority (`GoalPriority` Low/Normal/High ↔ `weight`, pure + unit-tested) →
    skill-trim → optional target song → met toggle / delete. `RoutineDetailView`'s
    provisional init broadened to resolve loop/song blocks.
  - **Slice 4 — loop skill-tags: DONE (branch `pocket-112-practice-planner`, ADR 0074).**
    A `Loop.tag` matching a coarse `ExerciseTemplate` bucket (recognised by
    `SkillFamilyMap.recognizedTemplate(for:)`, offered as ✨ suggestions in the loop tag
    editor) lets a technique goal's Path A surface that loop alongside exercises;
    projected onto `PlannerLoop.templates`. Opt-in — untagged loops stay Path-B only;
    reuses ADR 0034 tags (no schema change); pure + unit-tested.
  - **Slices 1–4 complete the V2 planner (all shipped).** Plus the full review-refinements pass
    (R0–R5), player polish (P1–P3), and the reps authoring follow-up (ADR 0076, PR #117). The
    planner is functionally complete and live.
  - **Deferred (user, 2026-07-10), not now:** **Slice 5 (AI decomposition)** — still OUT OF SCOPE,
    gated on the AI phase; and the **learned-target reach default** fast-follow (its own future ADR;
    ADR 0075's manual pins are its data substrate).

- **Exercise content templates — ADR 0065 (Accepted).** A per-exercise "what to
  play" layer (`Exercise.kind` + a versioned `Codable` `templatePayload`, renderer
  switched in `ExerciseRunView`) *over* today's metronome/ramp engine — strumming
  arrow-lane, animated fretboard, chord/progression stepper — mapped from the
  taxonomy's `Default mode` column. Build order strumming → fretboard (shared with
  tab→fretboard Phase R + preset guides) → chords; vibrato/bends/palm-muting
  deliberately get no template. **COMPLETE & merged (PRs #95–#101):** strumming
  (incl. accents/mutes); fretboard renderer + runs + polish; scales & arpeggios on
  a shared CAGED box engine; **chords** (progression drill on a shared
  `ChordVoicing`, absorbed triads); **Strum & Chords** composition; exercise-audio
  seam; global animate toggle. `ExerciseKind`/`ExerciseTemplate` carry all six
  kinds. No template work outstanding.
- **CAGED + triads as a category — RESOLVED (folded into Chords, shipped).** Was
  floated as its own fretboard category, then parked in favour of folding triads into
  the **Chords** template — which has now shipped (PR #97) on a shared `ChordVoicing`.
  A triad is a 3-note chord voicing and the CAGED box engine generates arbitrary note
  sets, so the shape/inversion lives with chords as planned. No separate category.
- **Practice routine model — ADR 0066 (Accepted).** The multi-unit *session*
  container (distinct from the intra-exercise ramp staircase): `Routine` +
  `RoutineItem` (typed relationship to Exercise/Loop/Song or a rest block, explicit
  `order`), a player orchestrating the existing per-unit engines, pure budget/rest
  logic. Container + manual authoring + player first; the planner (ADRs
  0014/0015/0016) becomes just another producer of a `Routine`, deferred to its own
  ADR. Unblocks ADR 0014's open output type. **In progress:** branch
  `pocket-107-routine-model` (slice 1 = model + pure ordering/budget helpers + tests).
  **Cold-start build plan: `docs/plans/routines-build-plan.md`** (pick-up-cold; all
  slices, conventions, gotchas). Two decisions locked 2026-07-07: (i) routines live in
  the **Practice space** next to Exercises (Home cards later); (ii) the player
  **auto-advances** — aim is *controlled discomfort, not clean reps* (command tempo is
  a "just outside comfort" reference; pushing past it, where it won't be clean, is the
  point). This diverges from ADR 0016's clean-before-fast at the *session* level →
  capture as its own ADR when the player (slice 3) is built.
  - **Exercises-first direction (decided 2026-07-07).** Lean into exercises as
    first-class routine units, incl. **exercise-only routines** — the model already
    allows it (R4 makes Exercise/Loop/Song equal citizens; zero model change). The
    reasoning, to build with:
    - Exercises and loops are different practice *modes* — **technique** (audio-free,
      click/template-driven, portable) vs **repertoire** (a loop bound to one
      recording). Exercises are exactly the skill-building axis the planner's
      front-half already assumes (ADR 0015: goals → **skills** → exercises).
    - **Exercise routines are the shareable ones** (ADR 0064 §2: exercise is the
      shareable unit, loop never) — the teacher-persona win lives here.
    - **Cold-start unlock:** exercise routines work day one with an *empty library*
      (no imported song/loops needed) — the onboarding wedge loops can't provide.
    - **Presets = content:** now the ADR 0065 template axis is complete, an exercise
      carries *what to play*. Ship a `RoutinePresets` seeder mirroring
      `PracticePresets` (curated in-house ordered exercise sequences — "10-Min
      Warm-Up", "Alt-Picking Builder", "Chord-Change Bootcamp"; same one-time-flag,
      deletion-sticks pattern; encode the method, author all copy in-house).
    - **Build-order consequence:** ship **exercise + loop** routines first, **defer
      Song items.** Exercise/loop items run in the compact run screens; only a Song
      item needs the hard full-waveform-screen handoff (slice 3). Exercises-first
      therefore *shrinks* the risky slice. Keep the model **freeform** (any mix) — no
      rigid "routine type" enum; curate exercise-heavy routines via presets, not
      schema. Authoring: sectioned add-unit picker (Exercises / Loops / Songs) with
      exercises as a primary source. No new model ADR needed — lives inside 0066 R4;
      `RoutinePresets` is its own slice after the player works.
  - **`RoutinePresets` — SHIPPED (2026-07-08), folded into the routines PR #102.** Three
    curated in-house starter routines (Morning Warm-up, Picking Builder, Rhythm & Changes)
    seeded once on first launch. The earlier "parked — reintroduces a run-screen freeze" read
    was a **misdiagnosis, twice over**: after a machine reboot the flake reproduced at a
    *different* assertion than claimed — the 5 s wait for a seeded **exercise** cell, never the
    20 s run-screen freeze guard (which fired 0/12 runs). Isolated to seeding latency: `HomeView`
    ran `PracticePresets` then `RoutinePresets` seeding back-to-back on the main actor before
    first paint, so the routine seeder's fetch+insert+save delayed the exercise library
    rendering past the test's tight 5 s window. Fixed by yielding between the two seeders (order
    preserved for by-name resolution) + widening the test timeout 5 s→20 s. Now 5/5 green,
    matching the no-presets control. Lesson: check *which* assertion a UI test fails before
    trusting a stored freeze diagnosis.
- **Social layer boundaries — ADR 0064 (Accepted).** Local-first forever;
  exercises (never loops/audio) are the shareable unit; derived-stats-only
  leaderboards; Sign in with Apple; CloudKit personal sync vs AWS social rails
  kept separate; loop compensation explicitly closed until a rights framework
  reopens it. Backend sizing + data-classification strategy:
  `docs/research/v2-backend-and-data-strategy.md` (S0 recap slice is buildable
  now, with no backend).
- **Song splitting / stems:** `docs/research/feasibility-song-splitting-and-stems.md`
  — loop-region audio export is a cheap V2 win; on-device stem separation is a
  gated spike (server-side rejected on privacy/rights); pitch-shift is nearly
  free when wanted.
- **Practice-take recording — ADR 0069 (Proposed).** Mic-only "audio journal":
  record your playing, relisten, review; sits beside notes/journal. Feasibility in
  `docs/research/feasibility-practice-recording.md`. Deliberately mic-only (no
  mix-in of app playback — that bakes copyrighted audio into a user file, the ADR
  0001/0064 wall). Isolation over a loop is **free on headphones** (coupling is
  acoustic, not digital) and **messaged, not fought, on speakers** via output-route
  detection — no AEC/DSP. Costs: a specific `NSMicrophoneUsageDescription` +
  privacy-manifest review, a `.playAndRecord` session config kept separate from the
  shared `.playback` plumbing, and a new app-owned `Recording` model (AAC files in
  the container). Buildable now; small-to-medium.
- **Tab → fretboard animation:** `docs/research/feasibility-tab-to-fretboard.md`
  — build the animated-fretboard *renderer* over an internal notation model
  first (it powers preset guides and shares its clock/substrate with the
  strumming-pattern animation), ASCII-tab import second, Guitar Pro/MusicXML
  later (licensing-gated), OCR never-planned.
- **Strumming-pattern animation + preset expansion (near-term, buildable now):**
  an animated D/DU pattern lane accompanied by the metronome, plus presets from
  the exercise-inventory sheet (warm-ups/spider, hammer-on/pull-off/slide
  ladders, scale + arpeggio runs, open/barre/triad progression changes,
  strumming rhythms). Per the content strategy: encode the *methods*, all copy
  and exercises authored in-house.
- **Backing tracks:** a content-production decision before a code one —
  outsource vs self-record (start tiny: 3–5 first-party tracks, common keys /
  I–IV–V / 12-bar, recorded as owned work product). Technically trivial:
  bundled or downloadable DRM-free files ride the existing engine unchanged;
  needs only a "first-party content" bucket distinct from user imports.
- **Desktop bulk metadata/artwork editing:** door held open by ADR 0064 §7
  (keep metadata logic pure/portable); otherwise deliberately unplanned.

## Launch readiness (pre-submission gate)

From a full pre-launch audit (2026-06-25). The code itself audited clean —
SwiftLint `--strict` 0 violations, build 0 warnings, 313 tests green, no
force-unwraps / `as!` / `fatalError` / debt markers, accurate privacy manifest,
minimal justified permissions. The gating work is **submission assets/config**,
not code. Re-run the audit any time with the `/ready-to-ship` skill.

**Hard blocker — RESOLVED (ADR 0061, 2026-07-02):**

- ~~**App icon + asset catalog.**~~ **DONE.** `Pocket/Resources/Assets.xcassets`
  now exists with an `AppIcon` set — a single 1024×1024 universal iOS icon
  (`icon-1024.png`, no alpha, the crescent + Southern-Cross mark), wired via
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`. The catalog also
  holds the `RedMoonLogo`/`RedMoonWordmark` in-app marks and the semantic colour
  sets. The stale audit note (2026-06-25, "no `.xcassets` anywhere") predates the
  icon integration. No open code blocker remains for submission.

**Should-fix before submission (no code dependency):**

- ~~**`ITSAppUsesNonExemptEncryption = false`** in `Info.plist`~~ — **DONE**
  (branch `pocket-073`): added, skips the export-compliance prompt on every upload.
- ~~**Bump `MARKETING_VERSION` 0.0.1 → 1.0.0**~~ — **DONE** (branch `pocket-073`):
  bumped in `project.yml` for a public release.
- ~~**Delete `Features/Planner/HomeView.swift`**~~ — **N/A (already gone).** Stale audit
  note: there is no `Features/Planner/` directory, and the app entry now renders the real
  `HomeView()` home hub (ADR 0044), not `LibraryView()`. Nothing to delete.

**Robustness (optional):**

- ~~**Audio-session errors are swallowed**~~ — **DONE** (branch `pocket-097`, pre-V2
  audit): session/engine-start plumbing deduplicated into `AudioPlumbing`, which logs
  failures via `os.Logger`; bookmark-resolution / file-read failures now surface a
  "Couldn't load this song's audio" notice on both practice surfaces (and disable the
  loop run's Start), and a resolved-but-stale bookmark is re-minted and persisted on
  the spot. Remaining (deliberately not built): a user-visible state for a failed
  *audio session* itself — rare, and needs a design pass to avoid a scare banner.

**Standing dev guide — keep new features launch-ready as you build:**

- **Privacy manifest is a living file.** Any new required-reason API
  (file timestamps, system boot time / `mach_absolute_time`, disk space) or any
  off-device data send (e.g. the AI phase's Claude proxy) must add the matching
  `NSPrivacyAccessedAPITypes` / `NSPrivacyCollectedDataTypes` entry in
  `PrivacyInfo.xcprivacy` *in the same PR*. Today's manifest declares
  UserDefaults (CA92.1) and System Boot Time (35F9.1 — the metronome's
  `CACurrentMediaTime()` session/tick timing, added pocket-089); don't let it
  drift further.
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

- ~~**Bulk song import from local/iCloud files.**~~ **SHIPPED (PR #114, pocket-120, 2026-07-10).**
  Multi-select `fileImporter` on both entry points (home hub + library `+`); each file decoded off
  the main thread behind an "Importing N of M…" overlay, partial-failure tolerant (unreadable/DRM
  files skipped, good ones still import) with a summary alert. Home import navigates into the library
  afterwards; library stays put. Pure `SongImportSummary` unit-tested.
- ~~**Loop edit "blocked while playing".**~~ **FIXED (pocket-121, 2026-07-10.)** The real cause
  wasn't playback at all: in a loop's waveform edit sheet the **Focus** and **Type** rows were
  interactive `.menu` `Picker`s in a `LabeledContent` value slot, which need several taps to register and
  never commit their selection at the sheet's partial detent — so those two fields appeared frozen. Both
  are now a plain `Button` opening a `confirmationDialog` that writes the choice directly (a `Menu` of
  `Button`s was tried first but still needed multiple taps). Mastery/Command tempo always worked — not Pickers.

- ~~**Manual target override (loops, and likely exercises).**~~ **SHIPPED (PR #116, pocket-122,
  2026-07-10) — ADR 0075.** Applied to **both** loops (`Loop.targetSpeedOverride: Double?`, ×) and
  exercises (`Exercise.targetTempoOverride: Int?`, BPM) — additive optionals read through effective
  `targetSpeed`/`reachTempo` (`override ?? auto`). The reach is editable in place (run-setup Practice
  Settings + the exercise Tempo section) with **reset-to-auto**; a pin must stay above command, so
  `promoteCommand` **auto-clears** it once command catches up. `Exercise.targetTempo` went vestigial
  (retained, unwritten). Also dropped the redundant idle transport timecode. **Fast-follow deferred:**
  a per-user on-device *learned* reach default over the accumulated pins (own future ADR) — the pins
  are its data substrate; not built (no data to train on yet).

- ~~**Routine block repeats (reps authoring follow-up).**~~ **SHIPPED (PR #117, pocket-123,
  2026-07-10) — ADR 0076.** The R3 `RoutineItem.reps`/`effectiveReps` + reps-aware length estimate
  were infra-only; this added authoring (tap a unit block in edit mode → a `BlockRepsEditor` sheet
  with a stepper, 1–9; a tappable `×N` chip is the affordance) and player looping (a multi-rep block
  runs back-to-back with a "Rep N of M" counter, Done screen only after the last rep; Skip abandons
  remaining reps). Rep stepping lives in the pure `RoutineSessionCursor`.

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

## Journal authoring → Practice screen (ownership shape settled — ADR 0058)

**Ownership decided (ADR 0058, 2026-07-01):** one polymorphic `JournalEntry`
(owner = loop **XOR** exercise), reusing the existing list/undo/kind/sheet
machinery; exercises get a new honest `commandBpmAtEntry: Int?` snapshot (no
mastery, absolute BPM) rather than overloading the loop's song-fraction `Double`.
Additive schema (new optional `exercise` relationship + `commandBpmAtEntry`) —
device-verify the migration before merge. **Loops-first is an acceptable partial
ship** if the exercise side slips.

**Built (2026-07-02).** Model layer + full UI: `JournalOwner`/`JournalWriter`
shared write path, `JournalSheet(owner:readOnly:)` generalised from the loop-only
sheet, book button on both run screens, waveform journal made read-only, old
waveform write helpers retired. 531 tests green. **Remaining: on-device migration
verification before merge.**


Relocate journal **authoring** to the Practice run screens; make the waveform
journal **read-only** (history view only). Rationale: ADR 0046 makes Practice
*the* run surface — the moment right after a run, where you just felt the
difficulty, is the truthful place to write a note; the waveform screen is
edit/create. A "+" / add-note affordance lives in the run screen's top-right
(where the empty nav slot is today).

- **No data migration / no erasing entries.** This is a UI relocation, not a
  schema change — existing `JournalEntry` rows stay. (Corrects the 2026-07-01
  sense-check premise: the journal never captured automator settings — only
  `masteryAtEntry` + `commandTempoAtEntry`, snapshot unchanged.)
- **Snapshot stays** mastery + command tempo at write time, now read off the
  loop from the run screen instead of the waveform model.
- **Extend to exercises (net-new).** Exercises have *no* journal today —
  `JournalEntry` only relates to `Loop`. Add an `Exercise` journal from scratch:
  new model relationship (`JournalEntry.exercise` or a shared owner), authored
  from `ExerciseRunView`, with its own snapshot (command BPM / mastery-equivalent
  at write time). New ADR — decide the ownership shape (one polymorphic entry vs
  two) before building. Loops-first is acceptable if exercises slip.

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

## Practice run-setup — persist loop ramp shape — DONE (2026-07-01, ADR 0057 follow-up)

Shipped on `pocket-083`: four dedicated `Loop` fields (`rampWarmupSteps` /
`rampReachSteps` / `rampBackoffSteps` / `rampRepsPerStep`, declaration defaults,
additive migration), decoupled from the ADR-0013 automator. `LoopSetupState` now
tracks all six persisted fields (ramp edits arm Save Changes), `seedIfNeeded`
restores them, shared `persist()` writes them. Original spec below, for record.

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

- **Swappable themes (design-system extension, roadmap).** `DesignTokens.swift`
  was built for this from day one — every colour is a semantic role, and the file
  calls out the seam explicitly ("each role becomes a `Theme` property; the current
  values become the 'teal' theme"). Light/dark already ship (ADR 0062/0063); a
  user-selectable **`Theme`** (beyond appearance) is the natural next step. Shape
  when built: a `Theme` protocol/struct whose properties are the current
  `PocketColor` roles, `PocketColor` reading from the active theme, and a Settings
  picker persisted like `AppearancePreference`. Prerequisite already enforced: every
  view (and every ADR-0065 exercise template, rule **T10**) must draw from semantic
  tokens, never literal hex, so themes reskin the whole app — templates included —
  for free. The template-gallery preview demonstrates the payoff (Red Moon / Light /
  Blood Moon, one control reskins all five templates live). Candidate themes to
  explore: the shipped Red Moon dark/light, and a **Blood Moon** register built on
  the brand vermilion `#C73818` (branding note above). Not scheduled; captured so the
  token discipline that keeps the door open is treated as load-bearing, not optional.

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

## Transport bar — deferred pieces of V1 feedback #1 (parked 2026-07-04)

Branch `pocket-093` enlarged the Loop/Marker controls into big circular buttons flanking the
transport while **idle** — **Marker far-left, Loop far-right** — and, on device review, **reverts to
the original compact bar once a loop is active** (small stacked Loop/Marker column + ✕ strip), since
the running loop already reads on the existing Loops panel below. So the mock's "dedicated
active-loop Loops panel" is **resolved by reuse** — no new panel needed. One follow-up remains:

- **Home-settings toggle to swap Loop/Marker sides.** The user wants the left/right placement of the
  idle Loop and Marker controls to be user-configurable from the **Home settings** (Settings screen),
  not hardcoded. Add a persisted preference (e.g. `AppStorage`) and thread it into `TransportBar` so
  the two flanking controls swap sides. Default stays Marker-left / Loop-right.
