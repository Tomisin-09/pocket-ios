# Routines — cold-start build plan (ADR 0066)

**Purpose.** A pick-up-cold execution plan for the practice-routine feature, written
while context was rich so a later session can build without re-deriving anything.
Pairs with **ADR 0066** (the decision record) and the backlog note under "Practice
routine model". Branch: **`pocket-107-routine-model`** (already created off `main`).

**Status when written (2026-07-07):** branch created, nothing implemented yet.
Slice 1 is next.

---

## 1. The concept in one paragraph

A **routine** is an ordered list of typed blocks (`focused` / `warmup` / `play` /
`rest`); a non-rest block points at exactly one **unit** you already own —
`Exercise`, `Loop`, or `Song`. A **player** runs the list end-to-end, handing each
block to the per-unit engine that already exists (exercise run screen, loop run
screen, waveform screen for a song) and advancing between them. It's a
*session-level conductor* over existing engines — not new playback. The **planner**
(ADRs 0014/0015/0016, deferred) is simply an automatic *producer* of the same
`Routine` object you can also build by hand — so manual and generated routines share
one model and one player. Build the container first, the intelligence later
(substrate before intelligence).

Naming trap: "routine" also names the **intra-exercise tempo ramp** (`RoutineStairs`
/ `CommandRamp`, already built). That is NOT this. This is the multi-unit *session*.

---

## 2. Decisions locked this session (2026-07-07)

1. **Home = the Practice space.** Routines are listed and authored inside the
   Practice space, next to Exercises (where the run engines and the exercises-first
   direction already live). Home-screen routine *cards* (ADR 0014 / design brief §4
   P3) come later; don't touch `HomeView` now.

2. **Player auto-advances — and the aim is controlled discomfort, not clean reps.**
   The session player advances between blocks automatically on the material's own
   pacing (see §5 for the completion trigger). **Philosophy:** command tempo is a
   *reference marker* for "just outside your comfort zone"; the routine pushes you
   at/past it, where playing likely won't be clean, and that is the intended
   stimulus. This deliberately diverges from ADR 0016's clean-before-fast **at the
   session level** — 0016's `.onConfirm` gate governs an *individual* drill's tempo
   plateaus and stays available standalone, but a routine does not wait for
   confirmation. **Capture this as its own short ADR when slice 3 is built** (it
   closes off the wait-for-clean-gate alternative for the session player).

3. **Exercises-first.** Exercises are first-class routine units, incl.
   **exercise-only routines** (the model already allows it — R4). Exercises =
   technique mode (audio-free, portable, the planner's skill axis); loops =
   repertoire mode. Ship **exercise + loop** routines first; **defer Song items**
   (they need the hard waveform-screen handoff — see §5/§8). Keep the model
   **freeform** (any mix) — NO rigid routine-type enum; curate exercise-heavy
   routines via presets, not schema.

---

## 3. Conventions to follow (verified in-repo)

- **Model discipline (ADR 0011/0036):** business `uid: UUID`; **declaration
  defaults** on every non-optional attribute (CoreData 134110 rule — `init`-only
  defaults wipe the store); enums stored via a `String` backing field + computed
  accessor, never a raw enum attribute. Reference: `Pocket/Core/Models/Exercise.swift`.
- **Typed-optional polymorphic relationships (R4):** copy the `JournalEntry` pattern
  (`var loop: Loop?`, `var exercise: Exercise?` already coexist there) — NOT a
  generic `ownerKind + ownerID` (loses SwiftData inverse/nullify integrity; rejected
  in ADR 0058 and ADR 0066 R4).
- **Schema registration:** add new `@Model`s to the `modelContainer(for:)` array in
  `Pocket/App/PocketApp.swift:17`.
- **Pure logic stays pure (AGENTS.md):** budget/ordering/pacing math in a
  SwiftData-/SwiftUI-/AVFoundation-free module, unit-tested. Tests live one-per-module
  in `PocketTests/` (e.g. `CommandRampTests`, `ExerciseTests`).
- **SwiftData test-host trap:** in unit tests use uninserted `@Model` objects for
  property/logic checks; do NOT `context.insert` a full object graph (SIGTRAPs in the
  XCTest host). See memory `swiftdata-insert-test-host-trap`.
- **File length ≤400 lines** (CI `--strict`); split proactively.

---

## 4. Slice 1 — model + pure helpers + tests  ← START HERE

Pure substrate. No UI, no player. Ends with a compiling, additively-migrating schema
and a fully unit-tested pure layer.

**4a. `Pocket/Core/Models/Routine.swift`** — two `@Model`s (one file; tightly coupled,
stays well under 400 lines):

- `Routine`: `uid: UUID`; `name: String = ""`; `dateAdded: Date = .now`;
  `@Relationship(deleteRule: .cascade) items: [RoutineItem] = []` (R1).
- `RoutineItem` (R2–R5):
  - `uid: UUID`; `order: Int = 0` (explicit ordering — R2; player sorts by it, never
    trusts array order).
  - `kindRaw: String = RoutineItemKind.rest.rawValue` + computed `kind:
    RoutineItemKind` accessor (String-backed enum — R3).
  - Three typed-optional relationships, each `.nullify` (R4/R5): `exercise:
    Exercise?`, `loop: Loop?`, `song: Song?`. Exactly one set on a unit block; none on
    a `rest`.
- `RoutineItemKind: String, Codable, CaseIterable { case focused, warmup, play, rest }`.
- **Inverse relationships** on `Exercise` / `Loop` / `Song` (additive — they already
  carry journal inverses, same shape). Deleting a unit **nullifies** the item (never
  orphan-cascades the routine); deleting a `Routine` cascade-deletes its items only.

**4b. `Pocket/Core/Models/RoutineBudget.swift`** — pure layer (R7). SwiftData-free.
Operates on a projected value type (e.g. `struct RoutinePlanItem { kind; unitLabel;
estimatedMinutes }`) so it's trivially testable:
  - ordered traversal (sort by `order`);
  - focused-only budget accounting (only `.focused` counts toward a time budget;
    warm-up/play unbudgeted — ADR 0014 R1; 10–20 min block caps — R2);
  - default rest-insertion *proposal* between focused blocks (R3) — proposes, does
    not mutate the store.

**4c. Schema registration** — add `Routine.self, RoutineItem.self` to
`PocketApp.swift:17`.

**4d. Tests — `PocketTests/RoutineBudgetTests.swift`:**
  - ordering returns items sorted by `order`, not insertion;
  - budget: only `.focused` accrues; warm-up/play/rest don't; cap behavior;
  - rest proposal inserts between focused blocks per the rule;
  - a model-level round-trip using **uninserted** `@Model` objects (property logic
    only — respect the test-host trap).

**Slice-1 gate:** `swiftlint --strict` clean; `xcodebuild build` 0 warnings; tests
green. **Migration is additive but MUST be device-verified** against a store that
predates these models before merge (SwiftData migration-crash lesson — in-memory
tests miss it). Docs: `CHANGELOG.md` (Added), `PROJECT.md` (new model),
`docs/architecture.md` (new module).

---

## 5. Slice 2 — manual authoring (Practice space)

The user is the planner: build a routine by hand.

- **Entry point in the Practice space**, next to the exercise list (decision §2.1).
  A routines list + a "New routine" affordance.
- **Add-unit picker** — a sheet, **sectioned Exercises / Loops / Songs**, with
  **Exercises as the primary/default source** (exercises-first, §2.3). Songs may be
  present but their *player* support lands in slice 3 — either hide Song here until
  then or add-but-mark-unsupported (decide at build).
- **Reorder** (drag; writes `order`), **insert rest blocks**, **name the routine**
  (empty name allowed, like `Exercise`; auto-title suggestion optional).
- Deleting a unit elsewhere must leave the routine intact (R5 nullify already
  guarantees it; verify the list renders a nullified item gracefully — "unit removed"
  / skip).

**Open Qs for slice 2 (decide at build):** auto-name vs required name; whether a
focused block stores an explicit duration or derives it (see §5-completion below);
Song visibility in the picker before slice 3.

---

## 6. Slice 3 — the player (auto-advance)

Session-level transport over the existing per-unit engines (R6). The new thing is the
**transition**, not playback.

- Runs the current block on its own engine; on completion **auto-advances** to the
  next (decision §2.2), inserting `rest` blocks and showing session progress ("2 of
  5").
- **Block-completion trigger (recommended, confirm at build):** advance on the
  **unit's own natural completion** rather than an arbitrary wall-clock —
  - exercise/loop block → **one full ramp pass** (warm-up → reach/past-command →
    back-off; both now carry ramp-shape fields — exercise natively, loop via
    `rampWarmupSteps…` from pocket-083). This is on-philosophy: the ramp already
    encodes the climb to/past command tempo (the "just outside comfort" reference).
  - `rest` block → a **fixed countdown**, then auto-advance.
  - (`song` block → one play-through — deferred with Song items.)
  This means **manual routines need no per-block minutes** — each block runs its
  natural length; the time-budget (ADR 0014) becomes a *planning-time* concern for the
  future planner, not a runtime clock. (Alternative: explicit per-block time-box.
  Prefer natural completion; note the fork.)
- **Song block player — audio-only, no waveform (decided 2026-07-07).** Earlier this was
  flagged as "the hard part" because a Song block was assumed to reuse the full
  `WaveformPracticeView`. **We are not reproducing the waveform.** A Song block instead
  gets a **minimal, branded audio play-along**: pick tempo, play/pause, **−10 s / +10 s**,
  and nothing else — "just play along." It still runs on the existing local-file audio
  engine (`PracticeAudioEngine`), so tempo change = time-stretch and therefore **works
  only on DRM-free local/iCloud files** (ADR 0001) — Apple-Music-sourced songs can't be
  time-stretched, the same wall as everywhere else. This removes the full-screen handoff
  problem: every block (exercise, loop, song) now runs in a compact screen, so Song items
  no longer have to be deferred *for handoff reasons* — they're gated only on building this
  small player. Capture it in the slice-3 player ADR alongside the auto-advance decision.
- **No performance feedback (ADR 0070, Accepted).** The player never grades the take —
  no scoring, no pitch/timing detection, no pass/fail. Block completion is the material's
  natural length, never "play it right to advance." The player is the judge; the app just
  reflects the session back. Build the player with **zero** evaluation surface.

---

## 7. Slice 4 — `RoutinePresets` (content) — its own slice, after the player works

Curated in-house routines, seeded like exercises.

- Mirror `PracticePresets` exactly: a one-time `UserDefaults` seed flag (NOT an
  "is the store empty?" check) so **deletion sticks**; each preset a spec of ordered
  unit references; **encode the method, author ALL copy in-house** (content-strategy /
  guitargearfinder guardrail).
- Candidates: "10-Minute Warm-Up", "Alternate-Picking Builder", "Chord-Change
  Bootcamp" — ordered **exercise** sequences with ramps, showcasing the complete
  ADR 0065 template axis.
- **Why this matters:** (a) **cold-start unlock** — exercise routines work day one
  with an empty library (no imported song/loops needed), the onboarding wedge loops
  can't provide; (b) exercise routines are the **shareable** ones (ADR 0064 §2 —
  exercise is the shareable unit, loop never), the teacher-persona win.

---

## 8. Deferred / explicitly out of scope

- **Song repertoire items** — defer until exercise+loop player is proven (waveform
  handoff, §6).
- **Planner generation** (ADRs 0014/0015/0016) — becomes another producer of a
  `Routine`; its own future ADR (ADR 0066 R8 / slice 4-planner). Front-half:
  goals → skills → candidates (0015); back-half: `buildSession` ordering/time-box
  (0014); speed staging (0016).
- **Home routine cards** (ADR 0014 / design brief §4 P3) — surface after authoring
  exists in Practice.
- **Per-item overrides** (e.g. "run this loop at 80% *here*") — possible additive
  field later (ADR 0066 alternatives), not core.
- **AI suggester** (ADR 0002) — later producer over the same pure layer.

---

## 9. Gotchas checklist (don't get bitten)

- [ ] Declaration defaults on every non-optional attr (store-wipe risk otherwise).
- [ ] Enums via `String` backing + accessor, never raw enum attributes.
- [ ] Typed-optional relationships, not generic `ownerKind+ownerID`.
- [ ] **Device-verify the migration** before merge (not just in-memory tests).
- [ ] Tests use uninserted `@Model` objects (test-host insert trap).
- [ ] `xcodegen generate` after adding files/targets; run before building.
- [ ] `swiftlint --strict` locally (CI promotes warnings→errors); files ≤400 lines.
- [ ] UI tests (slices 2/3) need `-testPlan PocketAll` or CI catches what local skips.
- [ ] Pre-push: lint → build (0 warnings) → tests → docs table (AGENTS.md).
