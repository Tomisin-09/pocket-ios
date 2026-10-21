# ADR 0265 — A take opens the mode it was recorded in

- **Status:** Accepted. Built on `pocket-382-take-opens-its-mode`.
- **Date:** 2026-10-21
- **Amends:** ADR 0228 — **D3**: takes leave the list of things that keep J5a's precedence. A loop
  take now stores the mode it was recorded in, and its caption opens that mode on D2's terms (only
  while the loop still qualifies). 0228 rejected storing the mode on takes as "a schema change for a
  small gain; if takes need it later, that is its own decision". This is that decision. D1, D2 and the
  rest of D3 stand: notes still route by their kind, and session pills keep the precedence.
- **Relates to:** 0142 (J5a, the precedence a take with no mode still falls back to) · 0069 (takes) ·
  0189 (an additive optional column, and D4: a raw string, never an enum attribute) · 0117 (the
  practice log the backfill reads) · 0151 (a take outlives its owner).
- **Schema:** `Recording.loopRunModeRaw: String?`, additive, optional, no declaration default. The
  archive's `RecordingRecord` gains `loopRunMode: String?`. No `schemaVersion` bump, as with
  `isPinned` and `isStandalone`.

## Context

Found on the device: a take recorded in **Train your ear** on a loop shows the right caption in the
Journal (*Self Control daichi Cover · Chords ›*), and tapping it opens the **practice ramp**.

`JournalOwnerRoute.route(for: .take)` passed no mode, so it fell back to J5a: trainer, then ear, then
improvise. Any loop with a tempo qualifies for the trainer, so the trainer opened. Notes don't have the
problem because their kind names the mode (0228). A `Recording` stored nothing that could. Improvise
had the same bug: an improvise take on a loop with a tempo opened the ramp too.

## Decision

### D1 — The take records its mode at capture

`Recording.loopRunModeRaw` holds `LoopRunMode.rawValue`. It is written once, by
`RecordingOwner.attach(to:)`, and never changed afterwards. An exercise, song or standalone take
leaves it `nil`, and so does every loop take recorded before this.

The decoded `loopRunMode` reads an unknown raw value as `nil`, **not** as `.trainer` the way
`LoopRunMode(raw:)` folds it. An unknown mode has to fall back to the precedence. Reading it as the
trainer would be this bug again.

### D2 — The mode is part of the owner, so it can't be forgotten

`RecordingOwner.loop(Loop)` becomes `.loop(Loop, LoopRunMode)`. The mode lives in the case rather than
in a defaulted parameter, so the compiler makes every loop take site say which mode it records in. A
missing mode is exactly the bug, so it should not compile.

The sites are the trainer (`LoopRunView`), ear training (`EarTrainingView`, `EarLoopRunView`) and
improvise (`ImproviseView`, `ImproviseLoopRunView`). In the routine player, `takeOwner(for:)` switches
on the stage's **payload**. `stage.loop` answers the same for all three modes.

A loop's Takes list ignores the mode and still shows every take on the loop. The mode decides where a
caption leads, not which screen may list a take.

### D3 — The route uses 0228's rule unchanged

`route(for: .take)` passes `take.loopRunMode` as `writtenIn`. Everything else is 0228 D2: the
recorded mode wins only while `LoopModeAccess.modes(for:)` still allows it, so an improvise take on a
loop whose backing-track flag came off opens the precedence's first mode, not a screen the loop can't
run.

### D4 — Existing takes get a one-time backfill from the practice log

`TakeModeBackfill` runs once at launch (`takeModeBackfill.v1`), beside the other backfills. For each
loop take with no mode, it looks for a `PracticeRun` on the same loop (`unitUID`) whose kind is a loop
mode (`.loop` → trainer, `.earLoop` → ear, `.improvise` → improvise) and whose span
`[startedAt − 5 s, startedAt + duration + 5 s]` contains the take's `createdAt`.

- A take's `createdAt` is its **stop** time: `RecordingController.stopRecording` builds the row. So it
  falls inside the run it was recorded in.
- The 5 s covers the two `.onDisappear`s that finalise the take and write the log. They fire in
  either order.
- **Exactly one mode** among the matching runs is the answer. None, or two different modes (a trainer
  block ending as an ear block on the same loop begins), leaves the take `nil`. A guess that opens the
  wrong screen is worse than the precedence.

**Why once and not every launch.** A take with no matching run stays `nil` for good. Re-checking it on
every launch would fetch the whole practice log each time and find nothing new. Takes recorded from
now on carry their mode from capture, so the backfill has nothing new to do.

**What it can't recover.** A routine block that was skipped or exited (nothing was logged), a run
shorter than `PracticeLogWriter.minimumSeconds`, and a take restored later from an archive written
before this ADR. Each keeps the precedence, which is how it behaved before. None of them gets worse.

A failed fetch or save leaves the key unset, so the next launch tries again.

### D5 — The archive carries the mode

`RecordingRecord.loopRunMode` is the raw string, **optional**. An archive written before this decodes
it as `nil` (a Codable default would not survive a missing key), and its takes restore with no mode,
as they were written.

## Alternatives rejected

- **Inferring the mode on every read from the practice log.** That is a fetch per caption, and it can't
  work for takes whose run was never logged. Storing the mode at capture is the reliable record. The
  backfill uses inference once, only for takes recorded before the column existed.
- **A defaulted mode parameter (`.loop(loop, mode: .trainer)`).** Any site that forgot it would compile
  and write the trainer, which is this bug.
- **Storing the enum as the attribute.** A custom enum on a `@Model` is the migration crash in
  `docs/swiftdata-gotchas.md`. 0189 D4 rules it out.

## Consequences

- An ear or improvise take on a loop with a tempo opens its own mode from the Journal. A trainer take
  still opens the ramp.
- Pure and unit-tested: `JournalOwnerRouteTests` (the measured-loop ear take, the fallback when the
  flag comes off, a legacy take, an unknown raw value), `RecordingTests` (the owner writes the mode,
  only a loop take has one), `TakeModeBackfillTests` (the rule, plus one in-memory store run), and the
  archive round trip, restore, and the decode of an archive without the key.
- A store upgrade is additive. A store written by the previous build opens unchanged, and its takes
  route as before until the backfill runs.
