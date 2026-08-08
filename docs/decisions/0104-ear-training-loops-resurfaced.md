# 0104 — Ear training as "loops, re-surfaced" (a mode on the loop, notes into the Journal)

- **Status:** Accepted (2026-07-22; shipped — see build note below)
- **Date:** 2026-07-22
- **Schedules the first build** of the ear-training direction — the Wave 2 "Note 7" item from the
  2026-07-20 user-testing plan of attack (`docs/backlog.md`).
- **Builds on:** ADR 0094 (theory/ear-training direction + the no-grading line), ADR 0070 (Pocket never
  grades the player), ADR 0100 (the Journal space) / ADR 0058 (the shared `JournalOwner`/`JournalWriter`
  write path) / ADR 0038 (typed `EntryKind`), and the existing local-file loop playback (ADR 0001).
- **Narrows:** ADR 0094's abstract "Theory / Ear space" sketch. That ADR imagined a generic destination
  (interval player, chord voicer, scale explorer). Note 7 (later, 2026-07-20) deliberately **rejects the
  generic-interval-trainer framing** in favour of *the player's own loops, re-surfaced*. This ADR follows
  Note 7 for the first slice; ADR 0094's boundaries (T2/T3) still govern.

## Context

Pocket has never had an ear-training surface, for the good reason set out in ADR 0094: conventional
ear-trainers **are** scored right/wrong quizzes, and a scored test of your ear slides straight back into
judging the player — the exact thing ADR 0070 forbids. ADR 0094 closed the "is theory even allowed?"
question (objective identity and *self-judged* practice, yes; app-scored right/wrong, no) but left the
*shape* of the first build open, sketching a generic theory destination.

Note 7 supplies the missing shape, and it's a better one than the generic sketch: **don't build an abstract
interval trainer — re-surface the loops the player already captured.** A loop is a real fragment of real
music the player is already working on. Presenting that loop **ears-only** — the audio without the
waveform crutch — and asking the player to internalise it (hum it, play it back, notice its shape) is ear
training grounded in the player's actual material, not decontextualised drills. It costs almost no new
surface: the loop, its audio, and the note-capture path all already exist.

The one open design question was *how the player captures what they hear*. A bespoke transcription/scratch
field was the obvious answer and the wrong one — it would be a second, disconnected note store sitting
beside the Journal (ADR 0100), which **already** captures free-text notes tied to a loop. Reusing the
Journal means ear-session observations land on the same day-grouped timeline as every other note, filterable
and searchable, with zero new persistence.

## Decision

- **E1 — Ear training is a *mode on an existing loop*, not a new destination and not a generic trainer.**
  It is launched from a loop the player already owns (a "Train your ear" affordance on the loop's
  surface), and stays within Practice. It does **not** add a Home card or a standalone theory space; ADR
  0094 T1's "dedicated space" is **deferred** — Note 7's loops-reframe supersedes it for this slice. New
  destinations, when they come, join a *section* (ADR 0102), but this slice needs none.

- **E2 — The mode is *hum/sing internalisation*, self-judged and away-from-the-guitar.** It plays the
  loop's own audio cycling continuously so the player can **hum or sing it back** — an exercise they can do
  *without* an instrument in hand — then listen again and compare. The loop's **identity is shown up top,
  always** (name + song prominent; type/command-tempo/range as a quiet caption): this is the player's own
  material, not a blind drill, so there is deliberately **no "reveal" and no hidden-details toggle** (an
  earlier draft had one — cut on device feedback). There is likewise **no stored "answer" and no app
  verdict**: a loop is an audio segment with no notation to grade against, and that's the point — this is
  ADR 0094 **T2b** (call-and-response, *self*-judged) applied to the loop: *the app plays; nothing listens;
  the player is the judge* (ADR 0070's exact posture). (A waveform picture is a possible later enrichment —
  it needs the loaded audio envelope, out of scope for slice 1.)

- **E2b — A tempo control is part of the first slice.** Ear internalisation lives or dies on being able to
  **slow the phrase down**, so the mode ships with a −/+ tempo adjuster (percent-of-original, the loop's
  own tempo vocabulary; 25–150% in 5% steps, seeded from the loop's command tempo) that takes effect
  **live** while the audio cycles. Implemented by extending `LoopRunModel` with a live
  `setAuditionPercent`; no ramp, no rep clock — a fixed, player-chosen rate.

- **E3 — Capture reuses the Journal; there is no new scratch field or transcription store.** Notes the
  player jots during (or after) an ear session write through the existing
  `JournalWriter.add(to: .loop(loop), …)` path (ADR 0058), snapshotting the loop's context exactly like any
  other loop note. They appear on the loop's journal and the cross-cutting Journal timeline (ADR 0100)
  unchanged — no bespoke storage, no second note surface. Making notes is **optional**: the mode is
  primarily *listen to internalise*; the Journal is there when the player wants to record what they heard.

- **E4 — A new `EntryKind.ear` (👂 "Ear") tags ear-session notes.** So these notes are typed and filterable
  like the completion-note kinds (ADR 0100 folded 🎯/⚡️/🧗/📝/🎬 tagging into the run screens). Added the
  established safe way: a new `case ear` on the `String`-raw `EntryKind` enum with a computed glyph/label —
  **never** a raw enum attribute on a `@Model` (the SwiftData enum-attribute migration rule; `kindRaw` is
  the backing store). Unknown/empty raws still fold to `.note`, so old rows are unaffected and the new case
  needs no migration. It slots into `pickerOrder` after `.session`.

- **E5 — Audio is the loop's existing local-file playback, not synthesised tone.** The mode replays the
  loop segment through the existing loop audio path (the same DRM-free local/iCloud file the practice
  engine uses, ADR 0001), **not** the Hear synth engine (ADR 0097) — the point is to hear the *real music*.
  No new audio pipeline. Consistent with ADR 0094 **T4/T2b** and the ADR 0001/0064/0070 walls: the mode
  plays *to* the player and **captures nothing** — no mic, no analysis, no transmission.

- **E6 — No score, streak, accuracy %, XP, or right/wrong verdict, anywhere (ADR 0094 T3).** The app never
  says "correct" — the player compares their own attempt to what they heard. Any progress shown is
  exposure-based and self-directed (e.g. "loops you've trained by ear"), never performance-based. A tally
  or verdict is out of bounds by ADR 0094 T2c/T3 and would need a new ADR to introduce.

## Consequences

- **The first ear-training slice is cheap and grounded.** Loop, loop audio, and the Journal write path all
  exist; the net-new surface is one mode view (identity header + continuous play + live tempo + note) plus
  one `EntryKind` case and a live-rate method on `LoopRunModel`.
- **Ear notes flow into the Journal for free.** A player's transcriptions/observations land on the same
  timeline as their practice notes and takes, searchable by song/loop/date — one history, not two.
- **The no-grading spine is reinforced, not bent** (as ADR 0094 intended): the mode is a live demonstration
  of "present, then get out of the way," using the player's real material.
- **ADR 0094's generic destination is parked, not cancelled.** If a broader Theory/Ear space is ever
  wanted, it can still be built (interval player, scale explorer) and would join a Home *section* (ADR
  0102); this slice simply doesn't need it, and shipping the loops-mode first tests the appetite cheaply.
- **Scope risk remains the quiz gravity well** (ADR 0094): the design pressure to score "did you get it
  right" will be constant. E2/E6 are the guardrails — the player self-checks, the app never verdicts.
- **Follow-ups parked** (not slice 1): a waveform picture behind the audio, and a dedicated Home Ear
  destination (ADR 0094 T1) if the loops-mode proves the appetite.

## Alternatives considered

- **A dedicated Theory/Ear destination first (ADR 0094 T1's sketch).** Deferred, not rejected — heavier,
  abstract, and not what Note 7 asked for. Re-surfacing real loops is a smaller, more grounded first cut;
  the generic space can follow if wanted.
- **A generic interval / "name that interval" trainer.** Rejected for slice 1 (Note 7). Decontextualised
  drills are the genre cliché and drift toward the scored-quiz well (ADR 0094 T2c); the loops-reframe keeps
  the player on their own material.
- **A bespoke transcription / scratch field for what you hear.** Rejected (E3) — it duplicates the Journal
  (ADR 0100) as a second, disconnected note store. Reusing `JournalWriter` gives one searchable history and
  no new persistence.
- **Synthesised tone playback (ADR 0097 Hear engine).** Rejected here (E5) — ear-training on a loop should
  play the *real* music, not a synth approximation. Hear stays the engine for chord/scale reference, where
  there's no recording to play.
- **Add a score / streak to motivate.** Rejected — ADR 0094 T3 and the no-grading spine (ADR 0070). The
  motivation is the music and the player's own judgement, not a tally.

## Slice 2 — ear training as a routine block (2026-07-22)

The loop-settings entry (Slice 1) makes ear training reachable but not *plannable*. Players build
routines; ear internalisation belongs in that flow. Slice 2 adds it **as a routine block**, staying
faithful to E1 ("a mode on a loop") — it is not a new unit type and not an exercise (an `Exercise`
carries no loop; ear training needs one — the reason it was never an `ExerciseTemplate`).

- **S2.1 — A loop routine block carries a *mode*.** A new `LoopRunMode` (`.trainer` / `.ear`), stored on
  `RoutineItem` as a `String`-backed `loopRunModeRaw` (declaration default `.trainer`, the CoreData
  134110-safe pattern; every pre-Slice-2 loop block reads as the trainer, no migration). The block still
  references the same `Loop` via the existing relationship — **no new unit type, no schema break**.
- **S2.2 — The player dispatches a new `RoutineStageKind.earLoop`.** A loop block whose mode is `.ear`
  resolves to a `.earLoop` payload and embeds `EarLoopRunView` (the shared `EarTrainingView` core +
  routine chrome), where a standard loop block embeds `LoopRunView`. The `loop` accessor covers both
  modes, so rest/skip/up-next logic treats an ear block as an ordinary unit.
- **S2.3 — Manual advance; no completion screen (E6 extended).** Ear internalisation has no ramp or
  natural end, so an ear block is **unbudgeted** (`warmup` kind) and never shows a `RoutineBlockDoneView`
  (no mastery/promote — there's nothing to grade). Its own **Done** button is the completion; the player
  advances straight on. This is the routine expression of E2's self-judged posture.
- **S2.4 — Authored via a peer "Ear training" bucket.** `AddRoutineUnitSheet` gains an **Ear training**
  bucket beside Exercises/Loops/Songs — the same loops-by-song picker, adding an ear-mode block. Kept a
  peer bucket (not a mode toggle buried under Loops) for discoverability. The **loop-settings entry
  (Slice 1) stays** — both access points are intentional.
- **S2.5 — Reusable core.** `EarTrainingSheet` (Slice 1) was split into a host + a reusable
  `EarTrainingView` so the standalone sheet and the routine block share one implementation.
- **S2.6 — Picker polish (device feedback).** The routine ear block's completion moved from an intrusive
  full-width bottom pill to a quiet nav-bar **Done**/**Finish** button (it read like an error on landing).
  And `AddRoutineUnitSheet` gained **per-row audio auditions** (reusable `AddRoutineUnitRow` +
  `LoopAudioPreviewPlayer`, one loop at a time) on loop/ear rows — indistinctly-named loops ("Loop 5/8")
  are told apart by ear — plus a **`.searchable`** field that flattens the buckets into typed result
  sections across every element (Exercises · Loops · Ear training · Songs).

**Folded in:** the **"Ear Training" and "Theory" "Coming Soon" rows were removed** from the New Exercise
picker. Ear training shipped as a loop mode, not an exercise template, so a placeholder promising a
generic interval trainer misdescribed the direction (the exact framing Note 7 rejected). The enum cases
live on for the planner's `SkillFamilyMap`; only the create-picker listing (`creatable`) and the now-dead
`isComingSoon` machinery were dropped.

## Amendment — takes on an ear block (2026-08-06)

**E5's "captures nothing" is narrowed, and E2/E6 are untouched.** Ear training now
offers the same practice take the rest of the app does: an arm ring beside the play
button, a take that begins when the loop does, and the take list one tap away under it.

E5's sentence conflated two different claims — *the app forms no opinion of your
playing* and *the microphone is never used here*. The first is load-bearing and stands
(ADR 0070 / ADR 0094 T2b/T3): nothing listens, nothing is analysed, no verdict is
produced, and no audio leaves the device (ADR 0001 / 0064). The second was a
consequence nobody had a reason for. It fails on its own terms as soon as you use the
mode: **humming a line back is precisely the thing you cannot judge while doing it.**
Singing occupies the ear that would otherwise be assessing, and the only way to hear
what actually came out is to record it and listen. Excluding takes from ear training
withheld the feature from the one mode whose self-judgement is hardest to perform live.

The original exclusion was recorded in code rather than here — `ContinuousLoopControls`
carried "improvise does, ear training doesn't (nothing is played over an ear block;
you're hearing, not performing)". That reasoning is true and beside the point: what is
captured differs, whether capture is *useful* does not.

**What this changes**

- All three ear hosts (`EarTrainingSheet`, `EarTrainingScreen`, `EarLoopRunView`) own a
  `RecordingController`, exactly as the improvise hosts do; `EarTrainingView` takes it
  as a parameter for the same reason it takes the player (ADR 0141).
- **Routine ear blocks record too**, matching improvise blocks. The ramped run screens
  keep their `routineContext == nil` gate, because a take there belongs to a ramp; a
  hummed line is worth hearing back wherever it was hummed.
- `EarLoopRunView.finish()` finalises an in-flight take **before** logging and
  advancing — advancing tears the screen down, and a take finalised on the far side of
  that reads zero seconds and is discarded (the Slice 6 follow-up bug).
- Copy is parameterised, not duplicated: `ContinuousLoopControls` takes a `bedNoun`
  ("backing track" on improvise, "loop" here), and every line naming the bed is built
  from it so they cannot drift apart.

**Not changing:** no analysis of the take, no pitch comparison against the loop, no
"how close were you". That would be the app judging, which E6 and ADR 0070 forbid, and
it is not what was asked for.

## Build

**Shipped (#161).** `EarLoopRunView` + `EarTrainingSheet` in `Pocket/Features/Practice/`; Slice 2
added the routine **Ear training** bucket in `AddRoutineUnitSheet` and the `.ear` `LoopRunMode`.
Extended 2026-08-06 (ADR 0069 amendment): all three ear hosts record takes. Which loops qualify is
`LoopModeAccess` (ADR 0138); the mode reaches the planner via ADR 0139 S1.
