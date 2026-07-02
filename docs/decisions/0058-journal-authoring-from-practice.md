# 0058 — Journal authoring moves to Practice; journal extends to exercises

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

The journal (ADR 0038) captures a short, timestamped note against a **loop**, snapshotting the
loop's `mastery` and `commandTempo` at write time so the entry never drifts as the loop improves.
Today it is **authored from the waveform screen** (`LoopJournalSheet`, reached from
`WaveformPracticeView`) and relates only to `Loop` — exercises have no journal at all.

Two things changed the right home for authoring:

- **ADR 0046 makes Practice *the* run surface.** The truthful moment to write a note is right after
  a run, when you just felt the difficulty — that happens on the Practice run screens
  (`LoopRunView` / `ExerciseRunView`), not the waveform edit/create screen.
- **Exercises deserve a journal too.** They're first-class practice units now (ADR 0045/0046) but
  can't record how a session felt.

Before building we had to settle **one open question**: when the journal spans both loops and
exercises, is that **one entry type with a polymorphic owner**, or **two separate entry types**?
The two owners do *not* share snapshot semantics — a loop snapshots `mastery` (dots) and
`commandTempo` as a **song fraction** (`Double`); an `Exercise` has **no mastery** and its command
is an **absolute BPM** (`Int`). Overloading the existing `Double` to hold a BPM would be exactly the
kind of semantic lie ADR 0039 fought.

## Decision

### 1. Authoring relocates to the Practice run screens; the waveform journal is read-only

- The waveform screen keeps a **read-only history view** of a loop's entries — you can read past
  notes there, but the add/edit affordance is gone.
- A **"+" / add-note affordance** lives in the run screen's top-right (the empty nav slot today),
  on both `LoopRunView` and `ExerciseRunView`.
- **No data migration, no erasing entries.** This is a UI relocation over the same rows. (Corrects
  the 2026-07-01 sense-check premise: the journal never captured automator settings — only the
  mastery + command-tempo snapshot, which is unchanged.)
- The snapshot is now read off the **model from the run screen** (loop/exercise) instead of the
  waveform practice model.

### 2. One polymorphic `JournalEntry`, owner = loop **XOR** exercise, with honest per-owner snapshots

Keep the single `JournalEntry` class and add a second optional relationship. An entry belongs to
**exactly one** owner.

- `var loop: Loop?` (existing) and a new `var exercise: Exercise?`. Exactly one is non-nil;
  `Exercise` gains a cascade-owning `journal` relationship mirroring `Loop.journal`.
- **Snapshot stays honest, not overloaded.** Loop entries keep `masteryAtEntry: Int?` and
  `commandTempoAtEntry: Double?` (song fraction). Exercise entries leave both `nil` and use a **new**
  `commandBpmAtEntry: Int?` (absolute BPM; exercises have no mastery, so nothing maps to it). Each
  field means one thing for one owner; the unused ones read `nil`, not a defaulted lie (ADR 0039).
- Shared, owner-agnostic fields — `uid`, `createdAt`, `text`, `kind`/`kindRaw` — are reused as-is,
  so the list diffing, undo, and `EntryKind` machinery and the entry-row UI carry over unchanged.

Migration is **additive**: a new optional `exercise` relationship and a new optional
`commandBpmAtEntry` column, both defaulting to absent. Existing loop entries keep `loop` set,
`exercise`/`commandBpmAtEntry` `nil` — no store wipe (CoreData 134110 rule / ADR 0012). Additive
SwiftData relationships still get **device-verified** before merge (in-memory tests miss migration
crashes).

## Implementation (2026-07-02)

Built as one slice on top of the model layer. A `JournalOwner` enum (`.loop` / `.exercise`) adapts
the two owners, and a shared `JournalWriter` is the single owner-aware write path — it snapshots a
loop's mastery + song-fraction command tempo, or an exercise's absolute command BPM, through the
matching factory. `LoopJournalSheet` was generalised into `JournalSheet(owner:readOnly:)`: rows are
**self-describing** (keyed off `entry.exercise`) so each renders in the right units, and a
`readOnly` flag drops the composer/edit/delete for the waveform screen. Both `LoopRunView` and
`ExerciseRunView` gained a nav-bar **book** button opening the sheet in authoring mode; the waveform
screen opens it read-only. The old `WaveformPracticeModel+Journal` write helpers were retired.
`JournalWriter` is unit-tested (snapshot honesty per owner, trimming, update/delete). The additive
migration still needs on-device verification before merge.

## Alternatives considered

- **Two entry types (`JournalEntry` + `ExerciseJournalEntry`).** Rejected. Each stays trivially
  honest, but it duplicates the whole `uid`/`createdAt`/`text`/`kind` shape, the list/undo diffing,
  and the entry-row/sheet UI — two of everything for a note that's 90% identical. The snapshot
  divergence is small enough (three nullable fields) to carry on one type.
- **One entry, overload `commandTempoAtEntry` to hold BPM for exercises.** Rejected — a `Double`
  documented as "song fraction" silently holding `120.0` BPM is the defaulted-semantics lie ADR 0039
  removed. A distinct `commandBpmAtEntry: Int?` keeps the meaning legible.
- **A single generic `ownerKind` + `ownerID` instead of two typed relationships.** Rejected —
  loses SwiftData's cascade/inverse and referential integrity; two typed optional relationships are
  the idiomatic SwiftData shape and cost nothing extra.
- **Keep authoring on the waveform screen.** Rejected — contradicts ADR 0046 (Practice is the run
  surface) and separates note-writing from the moment the difficulty was felt.

## Consequences

- Notes are written where difficulty is felt (post-run), and the waveform screen becomes a
  read-only journal history — one authoring path, not two.
- Exercises gain a journal with a snapshot honest to their absolute-BPM, no-mastery model.
- `JournalEntry` becomes polymorphic over its owner; anything iterating entries must tolerate either
  `loop` or `exercise` being the owner (exactly one set).
- Additive schema only; existing loop entries are untouched. Migration is device-verified before
  merge per the SwiftData migration rule.
- **Loops-first is an acceptable partial ship** if the exercise side slips — the relocation for
  loops stands on its own; the exercise relationship + `commandBpmAtEntry` can land in a follow-up.
