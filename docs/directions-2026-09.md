# Directions, September 2026

*Written 2026-09-06, out of one sitting in which four questions were raised together. It
records decisions that were taken, not options that are open — where something is still
open, it says so in those words. Line counts and file references were verified against
the tree on 2026-09-06; they will drift, and they are here to show that a claim was
checked rather than to be maintained.*

**No ADR is written here.** Each section ends with the ADR it would become when the work
is picked up, so nothing is lost by not writing them today. Section 6 is the order the
work is recommended in, ranked by cost.

---

## 0. The four questions, and where they collide

1. **The Oracle should be a multiplier, not a feature** — clarifying goals, building
   routines and exercises, acting as a mirror as the journal accumulates, and being a
   learning resource.
2. **Home feels like something is missing**, and the scroll is the symptom. Separately:
   *Jump back in* should be able to prefer a routine or an exercise, not only a song.
3. **Notation against the playhead** — seek the song from the tab, or at least read it as
   the song plays. Probably iPad. And what the iPad should be more broadly.
4. **Android** — what it would cost, and whether it is a second repository.

They are not independent. Question 2's structural answer (*stop making Home a menu*) and
question 3's iPad answer (*the root becomes a sidebar*) are **the same decision seen from
two sides** — ADR 0102 deferred it once already, explicitly *"deferred, not foreclosed."*
Questions 1 and 3 collide too: `docs/backlog.md` files tab → structured song metadata as
an AI-phase feature, so what the Oracle is allowed to become decides whether notation ever
gets rhythm it was not told.

**Four decisions were taken and are settled below, not re-argued:** Home is option A; the
iPad is option B; the Oracle's learning-resource job is the grounded explainer only; and
Android is research now, decide later — with CloudKit flagged as the thing that must not
be decided by accident.

---

## 1. The Oracle as a layer

Three principles, then the map.

**1. The Oracle never owns anything.** Everything it produces is an ordinary app object
created through the path that already exists — `NewExercisePlan.finalise(in:)` for an
exercise (ADR 0128: *"put new creation behaviour here and nowhere else"*),
`PracticePlanner.materialise` for a session (ADR 0187 D7), `GoalAuthoringSections` for a
goal. Delete the Oracle tomorrow and nothing it made disappears. That is what makes it a
multiplier rather than a dependency, and it is ADR 0092 §A2 (*"never a foundation"*) made
structural instead of promised.

**2. One room, many doorways — but only the room speaks in paragraphs.** ADR 0187 D16
gives the Oracle one door; the ask is reach. The reconciliation: entry points may
multiply, but `OracleReadingText` renders in `OracleView` and nowhere else. Everywhere
else the Oracle arrives as a **pre-filled sheet** plus at most one tone-guarded rationale
line — which is already D9's rule, generalised. It is greppable, and it is a UI test.

**3. Every new surface routes through `OracleCoordinator`, never around it.** The tone
guard is scoped to readings today. A routine's rationale and a goal's restatement are both
text addressed to the player, and both can judge.

### The five jobs, ranked by leverage

| Job | Surface | Output | Local fallback (0092 §A2) |
|---|---|---|---|
| **Clarify a goal** | `GoalEditorView` / `LongTermGoalEditorView`, via the shared `GoalAuthoringSections` | a `Goal` proposal — title, skill trim, priority, optional target song | `GoalTemplateLibrary` (10 curated templates), the incumbent — **and, since ADR 0216, each skill's reach line and fix**, which a model's proposal would pre-fill rather than replace |
| **Propose an exercise** | ADR 0187 D9's prompt box | a `NewExercisePlan` pre-fill; `ExerciseTemplate` stays closed | none needed — the control is simply absent offline |
| **Explain a session** | `RoutineDetailView`, on a generated routine | one tone- and focus-guarded paragraph over a session `SessionBuilder` already built | none needed — the session stands without it |
| **Mirror** | `OracleView` — **shipped** | the weekly reading | `LocalOracle` — **shipped** |
| **Propose a session** | `PlannerView` ▸ Generate | `[SessionBlock]` → `PracticePlanner.materialise` | `SessionBuilder.buildSession` — not a degraded fallback, the shipping product |

**Goals go first, ahead of ADR 0187's own S3 ordering.** It is the cheapest call, the most
structured output, and it has the strongest fallback already built — but the real argument
is that every downstream feature is bounded by goal quality: `DueScore` is
`goalWeight × dueness × (1 − mastery/5)`, so a vague goal degrades the entire planner. And
`GoalTemplateLibrary` carries ten templates; the long tail is exactly what a model is for.

> **Settled 2026-09-10 by ADR 0187 D24, which this paragraph won.** The two documents disagreed:
> D21's stage table had S3 as *"structured output ×2"*, both suggesters together. S3 is now **the
> goal clarifier alone**, with the exercise proposer and the session explainer as **S3b**. The
> reasoning above is quoted in D24 as the deciding argument.

**Amended 2026-09-07 — the ranking below is a re-ranking, and generation drops to last.**

1. **Clarify a goal** — unchanged, and for the reason already given.
2. **Propose an exercise** — the safest output in the plan (a closed vocabulary, a sheet the
   player edits, one insert path) against real friction: the gap between knowing what you want to
   practise and having built it is where people stop. **One rule it needs before it ships:** *"no
   template fits that"* is a first-class outcome with its own copy, never a fall-through to the
   nearest match. A near miss is worse than a refusal, because the player cannot tell the
   difference and will go and practise the wrong thing believing it is what they asked for. A
   validator rule, not prompt advice.
3. **Explain a session** — new, and it is the job that was missing. The reason a generated routine
   gets abandoned is that its shape is opaque: why three blocks and not one, why the hardest thing
   is not first. `SessionBuilder` knows all of that and says none of it. One paragraph over a
   session the deterministic planner already built is cheap, grounded in our own output, and is
   the honest answer to *what does £9.99 buy that £2.99 does not* (ADR 0187 D20) — because a
   marginally different generated session is not.
4. **Mirror** — shipped.
5. **Propose a session** — last, and possibly never. See below.

### Why session generation goes last, and may never go at all

The tempting version of this is *"same logic, but with AI."* It is not the same logic, and the
planner is the wrong organ to replace.

- **The logic is arithmetic over the whole library, not judgement.** `DueScore` is
  `goalWeight × dueness × (1 − mastery/5)` with `dueness = 1 − e^(−elapsed/7 days)`, applied to
  every candidate and ranked. Consistent numeric ranking across dozens of items, reproduced
  identically every week, is the thing language models are worst at — and an approximation is
  indistinguishable from the real thing by inspection. Nothing would tell us it had drifted.
- **The invariants are decisions with tests behind them.** The 60-minute ceiling (ADR 0014 R7),
  the U-shape that puts the most-due item **last**, R2 block sizes, the R4 micro-rest cadence, and
  `SessionBuilder`'s deliberate inversion where a block's share sets an item's minutes rather than
  the reverse. Handing those to a model does not delete the decisions; it converts tested
  invariants into unwritten ones.
- **We have no evaluation function, by design.** ADR 0070 means the app never measures whether a
  session was good. So a model-built planner could not be hill-climbed, A/B'd, or even shown to
  have regressed — we would be making untestable changes to a tested system. This is the decisive
  argument, and it is a permanent one.
- **It would delete its own fallback.** ADR 0092 §A2 requires a deterministic local fallback for
  every AI surface. `SessionBuilder` *is* that fallback. Replacing it leaves the requirement with
  nothing to point at, and turns a free, offline, instant, every-tier feature into a metered,
  networked, latency-bound, Oracle-tier one — against ADR 0144's free floor.

**Where the leverage actually is: the inputs to the formula, not the formula.** `goalWeight`
comes from goals, and a vague goal degrades every session forever — which is why job 1 is job 1.
A richer library from job 2 gives the ranking more to choose between. Better session *names*
(`QuickSessionNaming`) and the explanation of job 3 change what the player understands without
changing what the planner decides. Improve the fuel, not the engine.

The one honest opening for a model — that the U-shape and item count are one-size-fits-all and
could in principle be personalised — is closed by the third bullet, not the first two. It is not
that a model could not do it better. It is that we could never find out.

### The fifth job, scoped: the grounded explainer

The Oracle explains **what the app already knows** — a chord `ChordNamer` named, a scale
from `ScaleReference`, the shape a generated routine took and why. It never answers from
its own knowledge of the guitar. Where the player wants to *learn* the thing, it points at
their own saved references (ADR 0167), which is `docs/positioning.md` §1 executed rather
than restated.

The line, written once: **the Oracle may explain the app; it may not teach the
instrument.** That keeps ADR 0092 §A5 intact, keeps cost bounded, and keeps the app off
the lesson platforms' turf, where `docs/positioning.md` §2 already places them as *the
resources a multiplier multiplies*. Lands after ADR 0187 S4, as its own slice.

### Five things that must move as the Oracle grows

1. **A third capability is a third protocol**, not a widened one — the same reasoning D4
   gives for splitting `OracleReading` from `OracleRoutineSuggesting`: different fallbacks,
   different quota costs, different on-device feasibility.
2. **The DTO must not grow to carry app-authored tables.** `OracleContext` caps free text
   at 8,000 characters and deliberately never fetches `Profile`. A goal suggestion needs
   the skill taxonomy and the goal templates — those are **our tables, not player data**,
   so they belong in the *prompt*. Say so, or `OracleContextBudget` erodes one feature at
   a time.
3. **Analytics has no Oracle events at all.** The vocabulary is closed and `.swiftlint.yml`
   forbids a free `String`, so the cases have to land in the same change as the first
   surface — or the first metered feature ships unmeasured.
4. **ADR 0187 D20's two tiers are not in `Configuration/RedMoonPro.storekit`**,
   `StoreManager.swift` ~~ORs the beta grant into `isPro`, and~~ unlocks everything under
   `UITestRuntime.isActive`. (The beta grant was removed 2026-09-10; the `UITestRuntime` unlock is
   the half that remains, and it is the half that mattered.) The tier is untestable until
   `UITestHooks` gains a seam.
5. ~~**ADR 0092 still reads *Proposed*** while ADR 0187's Consequences say it moved to
   Accepted. Two files disagree about what happened.~~ **Stale — this was already fixed.**
   0092's status line has read **Accepted** since 0187 shipped, with both amendments
   written into it. Checked 2026-09-10 while settling D24; nothing to do.
6. **The DTO's shape fields are a floor, not a ceiling** (ADR 0187 D22, built 2026-09-10).
   `Unit.runsInCurrentSpan`, `SpanEdit.runsInPreviousSpan` and `OracleContext.sittings`
   are derived by joining the practice log against `LoopSpanChange` epochs — no schema
   change, and none of them is a rate. A future field that needs a *rate* is a comparison
   and does not cross; see D22's own test before adding one.

**It also answers the cadence question the backlog left open:** the reading stays weekly
because it reads a week (ADR 0187 D15). The suggesters are not periodic at all — they fire
on a tap, so what S4 must build is a **quota, not a cadence**.

**Would become:** one ADR per job as it is picked up, goals first; plus the explainer's own
slice after S4.

---

## 2. Home: option A now, option B at the iPad

### Why A

Home is a launcher: six navigation rows that are static for the life of the app, so the
scroll never pays. **Option A** collapses them to a 2-up hue tile grid inside the existing
`HomeSection` groups and spends the reclaimed height on content that changed since
yesterday. Mocked up, light and dark, at
<https://claude.ai/code/artifact/d6603125-218d-4790-9946-222a00447b06>.

It reverses only ADR 0102's tile-grid rejection — a call made when there were four cards —
and it un-parks work already built: ADR 0117 designed a Home summary tier, and
`Pocket/Features/Home/PracticeStatsCard.swift` has sat with **no call site** since the card
it was meant for stopped existing.

### The build

- **`HomeTile`** beside `HomeNavCard` in `Pocket/Features/Home/HomeCards.swift` — icon,
  title, tint, `cardWash`, `circleWash`, `locked`. Same six-hue triple pattern; no new
  tokens.
  ⚠ **Keep the accessibility label byte-identical to today's**
  (`"Toolkit, Tuner, your chords & a glossary"`). ADR 0102 §1 makes labels the UI-test
  contract and `ToolkitUITests` matches `BEGINSWITH "Toolkit,"`. A subtitle leaving the
  screen does not make it a wrong *description*.
- **`HomeStatsStrip`** over the existing pure
  `PracticeProgress.summarize(records:inventory:)` (`Pocket/Core/Stats/PracticeProgress.swift`).
  Three tiles: **minutes this week · days · notes**. Prefer this to reusing
  `PracticeStatsCard`'s four tiles — *mastered* is a self-rating count and reads as a
  score; minutes and days are effort facts (ADR 0070, and ADR 0176's *record, not verdict*).
- **Empty state:** hide the strip entirely when `PracticeProgress.hasNoHistory`. Three
  zeros on a fresh install is the exact objection recorded at
  `JournalTabView+PracticeLog.swift:10-14`.
- `HomeView.swift` is close to SwiftLint's 400-line cap, so the tiles land in a new
  `HomeView+Map.swift`, following the `HomeView+Learn.swift` precedent.

### Jump back in — independent of the layout, and cheaper than it looks

`Routine.lastPracticed` (`Routine.swift:33`, written at `RoutinePlayerView.swift:89`) and
`Exercise.lastPracticed` (`Exercise.swift:263`) are **both already persisted and neither is
read on Home** — `HomeView.swift` consults songs only. So this needs **no schema change**,
which is what makes it cheap under ADR 0189's criteria.

- **`HomeFeed.resumeTarget(...)`** — pure, returns a kind enum, generalising the existing
  `HomeFeed.mostRecentlyPracticed(_:practicedAt:)`. Unit-tested beside `HomeFeedTests`.
- **Four values:** most recent (default) · song · routine · exercise. `Loop` has no
  `lastPracticed` at all — excluded, and this doc says so rather than proposing a field.
- **Default bound to one constant** — `AppSettings.jumpBackInPreferenceDefault`, with a
  pure `resolved…(storedValue:)` in the shape of `TempoChangeWarning`
  (`AppSettings.swift:39, :186-193`). An `@AppStorage` literal does not mirror its
  accessor; that trap is documented at seven sites.
- **Where it lives:** a row in `PracticeSettingsView` — **not** an eleventh hub row,
  because `check-manual.py` C1 counts exactly ten. Plus a hold menu on the card itself
  (ADR 0163), with the Settings row kept, which is 0163 D2's load-bearing half.
- **Destinations differ by kind:** song → `WaveformPracticeView`, routine →
  `RoutineDetailView` (detail, not one-tap replay — the 2026-07-11 device finding that
  superseded ADR 0066), exercise → its run screen. The card's body changes shape; the
  eyebrow does not.
- Join the `-uiTesting` reset list beside `AppSettings.resetJournalFilters()`.

### What moves with it

`docs/manual/reference/home-and-library.md` quotes Home's copy verbatim under ADR 0165 —
same commit, or `check-manual.py` fails. Home figures get reshot through
`PocketShootUITests`. `docs/design-brief.md` §4.2 still describes the **V1** home hub and
is already stale; it is corrected there. Plus `CHANGELOG.md`, and `PROJECT.md`'s
`Features/Home/` row.

⚠ **Batch anything that touches Home.** A `PocketShootUITests` run takes ~6 minutes and the
harness has five recorded traps. Land the resume preference, the stat strip and the tile
grid on **one** branch and shoot once.

**Would become:** an ADR — *a map you read once* — reversing 0102's tile-grid alternative
on the stated grounds that it was decided at four cards; and a second, small one for the
resume preference.

> **Built** — `docs/decisions/0197-a-map-you-read-once.md` (2026-09-07), together with the resume
> preference (ADR 0193) and the stat strip (ADR 0196) that landed ahead of it. Four corrections to
> the sketch above, all found by building it:
>
> - **`HomeTile` did not land *beside* `HomeNavCard` — it replaced it.** Once all six call sites
>   were tiles the strip had no caller, and a shared component nothing draws is dead code with a
>   doc comment. The whole map moved into `HomeView+Map.swift` and `HomeView+Learn.swift` was
>   deleted into it, because the six had been split across three files for no reason but the
>   400-line cap and nothing could see the map whole.
> - **The accessibility label to keep is `"Toolkit, tuner, your chords and a glossary"`** — lower
>   case *tuner*, and *and* rather than `&`. The warning above quotes the *subtitle*'s casing; the
>   label is a separate literal and always has been. Keeping the wrong one byte-identical would
>   have broken the exact test the warning exists to protect.
> - **One subtitle was an instruction, not a description.** `Song library`'s was count-aware and
>   read `Add a song to get started` on an empty library — the only thing on Home that pointed at
>   the toolbar's **+** for a player with ADR 0112's first-run state (no song). It survives as a
>   caption on that one tile, and goes as soon as it is followed. Dropping all six would have been
>   a silent onboarding regression that no check could see.
> - **The tile says `Red Moon Oracle`, not the mockup's `Oracle`.** It wraps to two lines and the
>   row equalises height, which costs nothing; a tile that calls a place something the place does
>   not call itself is a map with a mistake on it.
>
> `check-manual.py` C9 named the five broken manual backticks by name the moment the subtitles
> left — which is the machinery working, and the reason the manual moved in the same commit rather
> than a follow-up.

---

## 3. Notation on a timeline, and the iPad

### The honest starting position

Nothing in the app is time-aligned to song audio except the waveform, the beat grid,
`Marker`, loop bounds and take moments. **Every notation surface is driven by a different
clock**: `FretboardView`, `ChordChangeView`, `StrummingLaneView` and `StrumChordsView` all
reconstruct a beat from `StandaloneMetronomeEngine.currentBeat`; none has ever seen
`PracticeAudioEngine.currentTime`. Two clocks, no bridge. And Phase R of
`docs/research/feasibility-tab-to-fretboard.md` shipped *narrowed*, as `FretboardDrill` —
evenly gridded, `beat = index / notesPerBeat`, arbitrary-beat events explicitly deferred.
T1 (ASCII import) never started.

### Three steps, and the first two need no notation at all

1. **A bar ruler you can seek from.** The real ask — *"control the position from the tab"* —
   is mostly *"take me to bar 33"*. `BeatGrid.beats(bpm:duration:anchors:beatsPerBar:)`
   already emits every beat and restarts the bar count at each anchor (ADR 0154). A
   tappable, draggable bar-and-beat ruler above the waveform delivers most of the value
   **on a phone**, with no notation, no parsing and no licensing — and it lets a marker
   read *bar 33* instead of *1:47*. It must adopt ADR 0153's split: only a leaf that draws
   a moving playhead may read one.
   **Descoped 2026-09-07 — see §6 Tier 3.** What was chosen is the readout half only: bar numbers
   in `TimeRuler`'s existing slots, behind a setting. The seekable ruler described here is parked.
2. **A tempo map** — the parked ADR 0168. One BPM per song is the wall. Anything that
   follows audio through a tempo change drifts, and 0154's half-interval invariant is the
   mechanism that would fight it. This is a prerequisite, not a nicety.
3. **Then notation — and a chord/section lane before tab.** A per-song, bar-indexed lane of
   chord symbols scrolling under the playhead reuses `ChordVoicing` and `ChordNamer`, stays
   readable at phone width, and is closer to what players want during a play-along than six
   strings of numbers.

Full tab against the playhead is an iPad-class feature and sequences there. Three
constraints, written down now:

- **Licensing.** Mature Guitar Pro parsers (alphaTab, TuxGuitar-derived) are LGPL/GPL-family;
  static linking into an App Store binary is a licensing decision, not a technical one.
  **MusicXML is XML and parses with Foundation directly** — that is the clean route. And
  never ship someone else's tab: the player brings the material, as ADR 0001 and ADR 0167
  already have it.
- **alphaTab has no native iOS target** (web/.NET/Android only), so adopting it means a
  `WKWebView` — a different product decision, and its bundled `alphaSynth` would fight the
  engine.
- **Soundslice is the tempting shortcut and the wrong one.** Syncing notation to your audio
  there means uploading your audio to their service — ADR 0092 §A4 and ADR 0001 in a single
  move.

### iPad

Current position, stated plainly: `TARGETED_DEVICE_FAMILY: "1"`, **zero** runtime
size-class branches, **zero** `NavigationSplitView`, **zero** idiom checks. The five
`horizontalSizeClass` hits are all inside `#Preview` blocks. The only real adaptivity is
`readableWidth()` — a 700pt cap at 15 call sites. ADR 0105 wrote the caps and deferred the
root split, saying it *"is worth its own ADR at flip time."*

The job, ranked:

1. **Root `NavigationSplitView` — this is option B.** A sidebar is a tab bar at regular
   width, which is why B and the iPad are one decision and should be paid for once.
2. **The practice screen is the real work.** A vertical cockpit tuned to phone height with
   a single landscape variant gated on `verticalSizeClass == .compact`. iPad wants two
   columns — and the second column is where the notation lane from step 3 above actually
   fits.
3. **~79 sheet call sites** want `presentationSizing(.page)`; 22 use `presentationDetents`,
   which behave differently at regular width.
4. **Submission mechanics:** flipping the flag needs `UIRequiresFullScreen = YES` (or all
   four orientations) to dodge validation **90474**, plus iPad screenshots and a
   re-submission.
5. `OrientationGate` is portrait-by-default with exactly one caller; multitasking reopens it.

**Would become:** the ADR 0105 flip-time ADR, carrying option B's root; ADR 0168 for the
tempo map; and a third for the bar ruler, which is independent of both and could ship first.

---

## 4. Android

### What is actually portable

About **~205 Foundation-only files, ~23,700 lines — roughly 30% of the app**.
`Core/Theory` is 100% pure (908 lines); `Core/Planner` 2,404; the notation and shape
generators (`ChordGrip`, `CAGEDShape`, `ScaleLayout`, `ScaleRun`, `FretboardDrill`,
`StrumPattern`) ~2,500; the audio maths (`BeatGrid`, `TempoMath`, `WaveformGesture`,
`ABSpan`, `CommandRamp`, `Automator`) ~2,000; `Core/Oracle` 1,531. Behind it, 31,299 lines
of tests — **which are the thing that makes a port provable.**

**But purity here is a convention, not a boundary.** One app target, no SPM package,
nothing mechanically stopping a SwiftUI import. **Recommendation independent of Android:
extract those directories into a local SPM target.** It costs almost nothing today and is
the difference between *we think it's pure* and *it cannot import SwiftUI*.

### The repo question: yes, separate

`project.yml`/XcodeGen, `PocketShootUITests`, `check-manual.py`, the CI matrix and the
pre-push hook are all iOS-shaped. A second platform in the same repo doubles every check
for no shared build. What gets shared is not code: **the ADR corpus, the test cases, and
`.redmoonpractice`** — ADR 0188's format, with its `schemaVersion`, is already the
cross-device contract and is the cheapest possible iOS↔Android bridge, requiring no backend
at all.

### Approaches, and why one wins

- **Skip (skip.tools)** — transpiles SwiftUI to Compose. **Ruled out:** no SwiftData, and
  the engine (`AVAudioEngine` + the `'tmpt'` time-pitch unit, ADR 0140) has no equivalent.
  The app is overwhelmingly Apple-framework by line count; the 30% that ports is the 30%
  Skip is least needed for.
- **Kotlin Multiplatform** — shares *Kotlin*, so the pure core gets rewritten in Kotlin and
  iOS either duplicates it or migrates onto it. Migrating iOS is the expensive half and
  buys nothing today.
- **The Swift SDK for Android** — preserves the Swift investment with Compose on top.
  Youngest and most interesting; the one to re-evaluate in a year, not to bet on now.
- **A Kotlin/Compose build driven by the ported test suite** — the recommendation if it
  happens. Port the test cases first, re-implement against them, and parity becomes
  provable rather than asserted.

### The decision that must not be made by accident

`PROJECT.md` says *"SwiftData, with CloudKit sync planned (Phase 4)."* **CloudKit is
Apple-only.** Sync is unbuilt, so choosing now is free; choosing after it ships means
abandoning it or running two sync systems. This is the single highest-value line in this
section, and the reason `PROJECT.md` § *Architecture (V1)* carries a pointer back here.

**Other Android-specific costs, recorded so they are not discovered late:** time-stretch is
a licensing decision there too (Rubber Band is GPL/commercial, SoundTouch LGPL); Room
replaces SwiftData; Play Billing replaces StoreKit including ADR 0187 D20's two-level
group; Play Vitals replaces MetricKit; and the manual + screenshot machinery becomes
two-headed.

**Would become:** nothing yet — this is research. The one thing that is not deferred is the
CloudKit question, which belongs in the sync ADR whenever sync is picked up.

---

## 5. Player-experience threads

Four raised in review. Three are close enough to decide; the fourth is a ranked list of
what else would move the needle, each already sitting somewhere in the repo.

### 5a. A tuner before a routine — offered, never a gate

The repo already found this from the other end: `docs/backlog.md` records the tuner being
*"buried behind a card that does not mention it"*, and the only fix so far was rewriting
the Toolkit card's copy. It is free forever (ADR 0144), needs no history to be useful, and
is the one thing a player does before every session.

- **Now:** a tuner affordance in `RoutinePlayerView`'s chrome and the practice screen's ⋯
  menu. `TunerView` exists — this is placement, not building.
- **Now, opt-in:** *"Offer the tuner when a routine starts"* — one skippable screen before
  block 1, never repeated within a session, default off. It offers; it never says you are
  out of tune.
- **Later, the ADR:** a **`Tune up` block type**, which is the honest answer because it
  makes tuning part of the *plan* and travels with a shared routine (ADR 0188). It is a new
  `RoutineItem` kind — ADR 0134 §11 switches on `RoutineStage.Payload`, ADR 0127's *no rest
  next to a rest* gains a sibling, and it is additive-only, so safe under ADR 0189's
  criteria.

⚠ **The gating unknown is the audio session, not the UI.** A tuner wants `.playAndRecord`
while the routine player holds `.playback`. ADR 0069 already had to keep those separate for
recording, so it is a solved problem — but it is the first thing to check, not the last.

### 5b. Scrubbing: one preference row, not a pile of toggles

It is not one behaviour today. **ADR 0080 already splits it** — a *tap* snaps to markers +
loop edges + beats (*"take me to that structure"*), a *scrub* drops the dense beat grid and
keeps only the sparse landmarks (*"put the playhead exactly here"*). `snapTolerance` scales
with the viewport, so the catch zone stays a constant size on screen at any zoom.

So a plain on/off toggle would flatten a considered distinction. The question that decides
the shape: do players want this because they **think in time rather than structure** (a
preference) or because they **cannot land it exactly** (a precision problem — which wants a
fine-adjust gesture, not a global switch)?

**Recommendation:** one three-value row in `SongPlayerSettingsView` — *Structure and beat*
(today) · *Structure only* · *Off* — defaulting to today. That screen already exists,
already has two doors (the hub, and a hold on **Loop controls**, ADR 0163), and carries
four rows; a fifth fits the medium detent. Default bound to one constant with a pure
`resolved…(storedValue:)`, in the shape of `TempoChangeWarning`.

⚠ **Scope it to seeking.** ADR 0099's neighbour-aware yielding on loop *edges* is what
stops a tight neighbour hijacking a handle. If *Off* disables that too, loops become hard
to place at all. Decide it explicitly rather than inheriting it.

### 5c. One transport grammar — clamp the skip to what is playing

Today the buttons mean two different things: with no loop armed they are **timed skips**
(ADR 0124); with a loop armed they are **restart / previous loop / next loop** (ADR 0030).
Unify on the timed skip. ADR 0124's own argument carries it — *"moving freely inside the
waveform beats a one-tap restart you can also get by tapping the start of the wave"* — and
that is **more** true inside a loop, where the move you want is to nudge back four seconds
and catch the entry.

⚠ **The constraint that forces the design:** an armed loop plays as a **pre-rendered,
crossfaded buffer** (`PracticeAudioEngine+LoopBuffer.swift`, ADR 0008), so *skip past the
loop end* is not a seek — it is a disarm.

- **Decided: clamp the skip to the loop region.** The buttons then carry exactly one
  meaning — *move ±N seconds through whatever is playing* — and the scope is whatever is
  armed. `TransportSkip.target(from:by:duration:)` takes a bounds range instead of a
  duration; it stays pure and the existing tests extend straight onto it.
- **Rejected: letting a skip past the edge disarm the loop.** Surprising, and it destroys
  the intent the player just expressed by arming it.

**What moves out:** `transportPrevious` / `transportNext` and the `hasPreviousTarget` /
`hasNextTarget` disabled states — **a net deletion**. Loop-to-loop navigation already lives
in the loops panel, where loops live: `WaveformPracticeModel+Actions.swift` `activate(_ loop:)`
is documented as *"Tap a loop row: make it the active looping region, seek to start + play"*,
so nothing has to move. `canRepeatSong` is unaffected.

**Would become:** its own ADR — it **reunifies ADR 0030 and ADR 0124**, and the transport is
documented in the manual.

> **Built** — `docs/decisions/0192-one-transport-grammar.md` (2026-09-06). It came out as forecast: a
> net deletion, `TransportNav` and its tests gone with the mapping they served, the pure tests
> extended onto `target(from:by:within:)`. One thing the sketch did not name — the bounds are read
> off the **engine's** armed region, not off `activeLoop`, so an unsaved A/B span scopes the buttons
> too.

### 5d. Six other things that would help players get the most out of it

Ranked. Every one is already recorded somewhere; none is new invention.

1. **Hear yourself then vs now** — two takes of the same loop, side by side. The only form
   of progress the app is *permitted* to show, and 0070-safe **by construction**: it plays
   two files and says nothing. ⚠ ADR 0151 (a take outlives its loop) makes the grouping key
   the first decision; ADR 0175 means a trimmed take and its older self are different spans.
2. **Hands-free control** — `NowPlayingController.swift:42-47` registers play/pause and
   *explicitly disables* seek/skip/next/previous. Enabling one as a hands-free **mark a
   moment** is the gesture most wanted mid-run and least reachable. ⚠ ADR 0175 forbids a
   live timecode on *Add note here*, so the interaction is the open question, not the
   plumbing.
3. **Onboarding's deferred fourth beat** (`docs/positioning.md` §7) — at the **second**
   session, the loop you saved becomes a block. The one moment that would teach the routine
   half of the position, which is currently learned by accident.
4. **The bar ruler** (§3 above) — markers, notes and moments start saying *bar 33* rather
   than *1:47*, which is how players talk to each other.
5. **First-song-to-first-loop.** ADR 0001 leaves the app nearly empty for a player with no
   material, and `docs/positioning.md` §8 names that as an excluded audience. Shortening
   that path compounds more than anything downstream of it.
6. ~~**The practice log is still two taps inside the Journal.**~~ **Closed by ADR 0208**
   (2026-09-09): Option A's stat strip is now the door, and the Journal's row is deleted.
   This was the last open item of §2.

---

## 6. Cheapest first: what to pick up

Ranked by cost, not by value, because everything here is argued for above.

**Tier 1 — small, pure, no schema change:**

1. ~~**The transport unification (5c) — and it is a net deletion.**~~ **Built — ADR 0192.** Give
   `TransportSkip.target` a bounds range instead of a duration, point the buttons at it in
   both states, then delete `transportPrevious`, `transportNext`, `hasPreviousTarget`,
   `hasNextTarget` and their wiring. More lines out than in; the pure tests extend onto the
   new signature. The only reason it is not trivial is that it needs an ADR (it reunifies
   0030 and 0124) and the transport is documented in the manual.
2. ~~**The Jump-back-in preference (§2).**~~ **Built — ADR 0193.** No model change — the data is
   already persisted and unread. One pure `HomeFeed.resumeKind`, one `PracticeSettingsView` row, one
   hold menu, three destinations. Landed **without a Home reshoot**: the default resolves the seeded
   figure to the same song it always showed, so it did not have to wait to be batched with the stat
   strip and the tile grid below.
3. ~~**The snapping preference (5b).**~~ **Built — ADR 0194.** One key, one row on an existing
   screen, one branch in `seekSnapping`. The design thinking was the expensive part and 5b did it;
   the open question it left — whether *Off* should reach ADR 0099's loop-edge yielding — is decided
   **no** in 0194 D3, and the minimap is brought in scope for the same reason.

**Tier 2 — small, but clear one unknown first:**

4. ~~**The tuner in the routine player (5a).**~~ **Built — ADR 0195.** The spike came back *not
   clean*, and that decided the design rather than the estimate. A block holds `.playback`, a tuner
   needs `.playAndRecord`, and the restore afterwards is the move that deletes an armed take
   (ADR 0179) — so the tuner is placed only on screens the player itself owns and the block has
   already left: before block 1, and an ungated button on the rest and Done screens. Mid-block is
   **declined**, and 5a's *later* `Tune up` block type is named as its real answer.
   ⚠ **A device pass reversed the shape of the first placement**, and the lesson generalises past
   this feature: 5a's *"one skippable screen before block 1, default off"* was built exactly as
   written and was wrong twice over — a full screen greets badly, and **a default-off setting is
   found by nobody**, so it would have left the tuner as buried as the backlog found it. It is now a
   three-button question asked **by default**, with the screen as what *yes* leads to. Anything else
   in this document specified as *opt-in, default off* deserves the same second look.
5. ~~**The Home stat strip alone, without the tile grid.**~~ **Built — ADR 0196.** One correction to
   the sketch above: the three tiles all read **one horizon**, because *minutes this week · days ·
   notes* paired two week figures with an all-time count and would have read as three facts about a
   week without being three. `PracticeStatsCard` was **deleted** rather than left beside it. The
   manual did not churn but the **figure did** — `launchForShoot()` seeds history, so `reference/home`
   is now stale, and is left so on purpose to be shot once with the tile grid (see Tier 3).

**Tier 3 — real work (and the whole of what is left of §2).**

⚠ ~~**It opens owing two figures.**~~ **Paid — 2026-09-07, with the tile grid (ADR 0197 D8).**
`reference/home` and `reference/settings-routines` were both reshot in one `base` pass, and the run
came back **27/27** with `shoot-progress.py --verify` clean at 91 of 93 (the two outstanding are the
subscription screens, which need a real phone and always have).

> It took **two** runs, and the reason is worth keeping: the first was driven while a device build
> and a verification build were running alongside it. Load average hit **184** with 5.3 GB of swap
> in use, and two unrelated tests failed — `testMetronome` ("the + stepper stopped responding at
> 90 BPM") and `testTakeTrim` (a `Trim…` button with an `{inf, inf}` frame). Both passed on an
> unloaded machine, and the pass ran in **714s** rather than 1100s. Neither failure was near the
> change. **Do not run a shoot next to anything else** — the harness's five recorded traps now have
> a sixth, and it is the cheapest of them to avoid.
>
> It also surfaced a harness bug, now fixed in `scripts/shoot-manual.sh`: the
> `STALE-DO-NOT-SHIP.txt` a failed pass writes says *"this file disappears when a run files a fresh
> set"*, which is true only of a **complete** shoot. A partial run files with `--keep` and clears
> nothing, so the marker survived the green re-run and sat on top of 56 fresh images calling them
> stale. It is now deleted explicitly after filing.

⚠ ~~**And `ManualRoutineShots.testPlayThrough` carries an unrun edit.**~~ **Run, and correct.** The
`routines` pass came back 3/3; the walk found `Not now` and tapped it. ADR 0195's selector was right
as written. Whether the prompt deserves a figure of its own on `routines.md` is **still open** — it
is described there in prose alone.

~~Then: option A's tile grid~~ **Built — ADR 0197.** Six call sites, the subtitles off the screen,
`check-manual.py` C9 naming the five manual backticks that broke, and the Home reshoot above. Two
things the ranking did not price:

- **A tile is a much smaller field of colour than a strip**, and the six washes were all chosen
  against a full-width card. The Journal's gold was at a **1.02** luminance ratio against the light
  background — last of six, next-weakest 1.14 — and at tile size it read as background. Found on
  device, not in a preview and not by any check. Darkened to 1.20 (0197 D9); crimson at 1.14 is the
  next candidate and was judged acceptable by eye.
- **"The whole app fits above the rail" is not what happened.** Learn and the rail are still below
  the fold; what now fits in front of them is the `This week` strip. The tile grid **paid for the
  stat strip** rather than making Home one screen (0197 D10). Anything planned on the assumption
  that Home now fits is still unbuilt work — which matters for the iPad sidebar in §2.

~~Then the bar ruler (§3 step 1, which must adopt ADR 0153's leaf-only playhead split) — the one
Tier 3 item still to start.~~ **Descoped and parked — 2026-09-07.** Three shapes were drawn against
the real cockpit and the **cheapest was chosen**: `TimeRuler` prints a bar number in each of its
existing six slots, behind a setting, rather than becoming a ruler you can seek from.

That is a **readout, not the control §3 asked for.** Six text labels are not a hit target, so the
tap-and-drag seek is not in it — and both shapes that would have delivered it are closed off (a
tick ruler in `TimeRuler`'s slot; a 44-pt strip above the waveform, which the cockpit cannot afford
in landscape). Do not record §3 step 1 as done when this ships. `docs/backlog.md` holds the
decision, the four things that will bite — chief among them that a song with no tempo or no placed
**1** has no bar to print, so the setting must degrade per song rather than swap a formatter — and
the drawings. No ADR yet, by this repo's own rule: the backlog promotes to one *when it is time to
act*.

**Tier 3 is therefore empty**, and nothing above Tier 4 is now waiting. The next thing picked up
comes either from Tier 4 or from the six-item list in §5 that this ranking was drawn against.

**Tier 4 — not now:** the tempo map (ADR 0168), notation, the iPad root, Android, the Oracle's
ADR 0187 S2–S5, and — as of 2026-09-07 — the bar-ruler **seek**, whatever is left of it once the
readout above ships.
