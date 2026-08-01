# 0138 — Each mode gates on what it needs (ear training is not a trainer feature)

- **Status:** Proposed (2026-08-01)
- **Date:** 2026-08-01
- **Closes:** ADR 0135 §B9a, which recorded that ear-training blocks are gated behind a measurement
  ear training does not use, and left it unresolved.
- **Refines:** ADR 0135 §B9's single widened gate (`commandTempo != nil || isBackingTrack`) into a
  per-mode requirement. Same outcome for backing tracks, stated in terms that also answer ear.
- **Builds on:** ADR 0104 (ear training as a mode on a loop — *"an exercise they can do without an
  instrument in hand"*), ADR 0082 (setting a command tempo is what promotes a loop into Practice →
  Loops), ADR 0039 (`commandTempo` is optional on purpose — `nil` means never measured), ADR 0126
  (the loops-library toolbar grammar the filter has to fit).

## Context

Two surfaces decide which loops a player can reach: `LoopLibraryView.visibleLoops` and
`AddRoutineUnitSheet.trainableLoops`. Both apply the same test — `commandTempo != nil` — and the
add-sheet applies it to **two** buckets: Loops and Ear training. It is why both bucket rows show the
same count.

That test is a real rule, not an accident: setting a command tempo is what promotes a loop from a
region drawn on a waveform into a practice item, and without it the library would list every scratch
region a player ever dragged. The trainer genuinely needs it — the command tempo is the anchor its
ramp is built around.

Ear training needs none of it. It plays the loop's own audio and asks the player to hum it back.

And the gate is not merely irrelevant there — it is backwards. `commandTempo` is *"the fastest tempo
the player owns this loop at"*: a measurement you can only make **by playing the passage on your
instrument**. Ear training is the one mode in the app that works with no instrument in hand — on a
bus, in bed, away from the guitar entirely — and it is the mode gated behind having already played
the thing. The single practice a player can do when they can't practise is the one the app hides
until they've practised.

The sheet already knows how to do this correctly for a different unit: `playableSongs` filters on
`ref.source != .appleMusic`, gating the Songs bucket on *what a play-along actually requires* (ADR
0001 — catalog audio can't be run). Loops simply never got the same treatment; one gate, written for
the trainer, was inherited by every mode that came after it.

## Decision

- **G1 — "Measured" is a requirement of the *trainer*, not a property of a loop.** There is no such
  thing as a loop that is globally ready or not ready to practise; there are modes, and each has its
  own precondition. The gate moves from the loop to the mode.

- **G2 — The three preconditions, stated once:**
  - **Trainer** — `commandTempo != nil`. Unchanged. The ramp is anchored on the command tempo; without
    one there is nothing to build a staircase around.
  - **Ear** — the loop's audio resolves (its song is playable, the same condition `playableSongs`
    already expresses). **No tempo, no flag.** If it can be heard, it can be sung back.
  - **Improvise** — `isBackingTrack` (ADR 0135 B1). The flag *is* the precondition; a command tempo is
    as irrelevant here as it is for ear, which is what B9 was reaching for.

- **G3 — In `AddRoutineUnitSheet`, the Ear bucket drops the trainer gate.** Its count will exceed the
  Loops count, and that divergence is the point rather than a defect to hide: it says ear training
  works on anything you have captured, while the trainer works on what you have measured. Together
  with ADR 0135 §B8's Improvise bucket, the three counts on that screen become a plain statement of
  the three preconditions.

- **G4 — In `LoopLibraryView`, the default list stays as it is, and the modes appear per row.** The
  default listing keeps the trainer gate (plus backing loops, per B9) because that list *is* the
  practice library and admitting every scratch region would drown it. What changes:
  - a filter to show **all** loops, alongside the existing Favourites filter and inside ADR 0126's
    trailing menu — the deliberate way to reach an unmeasured loop rather than the default view;
  - **per-row affordances gated per mode** — Ear on any row whose audio resolves, the trainer entry
    only when measured, Improvise only when flagged (ADR 0135 §B8a). A row then offers exactly the
    modes that loop qualifies for.
  - the empty-state copy, which today instructs the player to set a command tempo as though that were
    the only way in, has to admit the other two routes.

- **G5 — This is a fix, not a feature, and the scope stops here.** No new destination, no Home card,
  no session type. ADR 0094 T1's dedicated theory/ear space stays deferred exactly as ADR 0104 E1
  left it.

- **G6 — Two related holes are named and deliberately not fixed here.** *(Both closed by ADR 0139,
  which makes audible loops serve the `ear.*` skills and gives `SkillMode.offGuitar` its first
  consumer as the "Away from your instrument" session.)* Both are real, both are
  planner-side, and neither is a gate:
  - `SkillFamilyMap` maps the three `ear.*` skills to `ExerciseTemplate.earTraining`, which is not in
    `creatable` — so no player can own a unit that serves them and they resolve to **zero candidates**,
    permanently. The mirror of ADR 0135's `improv.vocabulary` hole, and the fix is presumably the
    mirror too (let ear-capable loops serve those skills directly).
  - `SkillMode.offGuitar` exists on eight skills — all three `ear.*`, the three `know.*`, songwriting
    — and **nothing anywhere branches on it**. The vocabulary for "practice you can do without your
    instrument" is already in the taxonomy with no consumer.

  Recorded so the next person finds them attached to the right context; each is its own decision.

## Consequences

- **Ear training becomes reachable for the case it was designed for.** A player can build a routine of
  loops to internalise away from the guitar without first having played every one of them at a
  measured tempo.
- **The Ear bucket may list a lot.** Every region ever drawn has audio, so the count could be several
  times the trainer's. Grouped by song (ADR 0127) this is browsable, and it is the honest inventory —
  but it is the one place this change could feel noisy, and it is worth looking at on device before
  assuming otherwise.
- **`trainableLoops` stops being one concept.** The name and its single call become three
  mode-specific collections; anything later added to that sheet must pick which precondition it means
  rather than inheriting whichever was nearest.
- **ADR 0135 §B9 simplifies.** Backing tracks no longer need the gate widened *for them specifically*;
  they get a precondition of their own like every other mode. The B9 outcome is unchanged.
- **Nothing about the trainer changes.** Its gate, its library default, and its empty state are the
  same rule they have always been — this ADR only stops other modes inheriting it.

## Alternatives considered

- **Drop the gate globally.** Rejected — it does real work. Practice → Loops would list every scratch
  region, and the promotion step (set a command tempo, and it appears) is a deliberate piece of
  ADR 0082 that players already understand.
- **Keep ADR 0135 §B9's single widened gate (`commandTempo != nil || isBackingTrack`).** Rejected as
  insufficient rather than wrong: it fixes backing tracks and leaves ear training exactly where B9a
  found it, because ear has no flag to add to the disjunction and shouldn't need one.
- **Give ear training its own flag, mirroring `isBackingTrack`.** Rejected — a flag is a *curation*
  signal, justified for backing tracks because not every loop repeats musically. Any loop can be sung
  back, so an ear flag would be bookkeeping with no judgement behind it, and the player would have to
  tick it on everything.
- **Show unmeasured loops in the library by default rather than behind a filter.** Rejected (G4) —
  the noise lands on the surface the trainer depends on, to serve a path the add-sheet already covers
  properly.
- **Require a command tempo for ear training (today's behaviour).** Rejected — G5's inversion: it
  makes the away-from-the-instrument mode conditional on having played the passage.

## Slices

- **Slice 1 — the whole change.** Split `trainableLoops` into the three mode-specific collections,
  drop the gate on the Ear bucket, add the all-loops filter and the per-mode row affordances in
  `LoopLibraryView`, and rewrite the empty-state copy. Small, and the parts that can break silently
  (which loops each mode offers) are pure predicates worth unit-testing.
