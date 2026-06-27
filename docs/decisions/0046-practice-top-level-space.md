# 0046 — Practice as a top-level space; exercises decoupled from the metronome (revises 0043 + 0045)

- **Status:** Accepted (architecture); built in phases (none built yet — this records the decision before code)
- **Date:** 2026-06-27

## Context

ADR 0043 framed a metronome **exercise** as *"a saved metronome setup"* — a preset
captured from the standalone metronome and stored as `MetronomeExercise`. ADR 0045
then added command-anchored progression (working → command → reach, with a warm-up
→ dwell → summit → backoff routine) and surfaced it as **Training Mode**, but built
that mode *on top of the automator's machinery*: the training routine reuses the
exercise's automator fields for storage (`automatorStepBPM`, `automatorCeiling`,
`automatorEnabled`…) and the engine arms training by going *through* the automator
setters (`startTraining` → `setAutomatorMode(.bars)` → `setAutomatorCommand`). That
reuse was a deliberate shortcut to avoid a migration; 0045 even notes that arming
the free-play automator and starting training are "mutually exclusive at runtime"
because they share one slot.

Two problems follow from that framing:

1. **The information architecture is backwards.** Exercises are *content* — the
   things a musician actually trains — but they live *inside* a tool: Home →
   Metronome card → standalone metronome → library sheet. The metronome is a tool;
   the exercises are buried beneath it. Musicians think *"I practise spider
   picking,"* not *"I have a metronome preset."*
2. **The automator has no clear purpose.** It is a generic tempo ramp with no
   stated job. But its job is exactly **command-tempo discovery** — ramp the tempo
   until your hands break down, and that ceiling *is* your command tempo.

Designing the decoupling surfaced a larger structure. There are **two different
things** both called "practice":

- **The trainable unit** — a single command-anchored drill (a metronome exercise)
  or a song loop with a command-derived target (the progression that was scoped to
  this ADR number for loops). One thing you push faster over time.
- **The orchestration** — the practice-routine planner (ADRs 0014 / 0015 / 0016,
  V2): the layer that *assembles a session* from your units and songs, weights what
  needs work, and journals it (building on the loop journal, 0038).

These are not competitors; the orchestration sits **on top of** the unit. Training
Mode is the unit layer; the planner is the orchestration layer. Conflating them
produces the fear of two overlapping destinations ("Training" vs. "Routines"). The
resolution is that they are **one space at two altitudes.**

Finally, the user has confirmed that the **existing saved exercises are disposable**
— they were built from early experimentation and carry no value worth migrating.
That removes the additive-only constraint that forced 0045's automator-field reuse,
and frees a clean model rewrite.

## Decision

Establish **Practice** as a top-level destination (alongside the song library and
the metronome), make it the home for all trainable units, and nest the future
planner *inside* it as the orchestration layer. Decouple exercises from the
metronome/automator at the product level, keeping a single deliberate seam.

### 1. Practice is a top-level destination, named "Practice"

A first-class space reached from Home, peer to the song library and the metronome —
not a sheet beneath the metronome. The destination is a **place** (a noun,
"Practice"), and "start training" is the **verb** you perform on a unit inside it.
"Training Mode" as a top-level *mode* is retired; the command-anchored routine it
named lives on as the action you take on a unit.

The hub offers two ways in:

- **Build today's session** — the guided path (the planner, V2).
- **Your units** — the focused path: the list of everything you can train, openable
  one at a time.

### 2. A "unit" is an aggregation over two separately-stored models

Practice presents two kinds of trainable unit side by side:

- **Exercises** — click-only, command-anchored drills (your own + shipped presets).
- **Song loops** — a loop from a song, with a command-derived target tempo.

These stay **separate models** because their audio sources differ
(`MetronomeExercise` is audio-free; `Loop` is bound to a DRM-free local/iCloud file
— the local-first boundary of ADR 0001, which must not be eroded). Practice is an
**aggregation/presentation surface** over both, not a single model. This is
deliberate forward-compatibility: the planner (0014–0016) needs exactly this
multi-source "things you train" surface to compose a session, so building the
aggregation now lays the planner's foundation rather than throwaway scaffolding.

### 3. The planner nests inside Practice (V2), it is not a sibling

ADRs 0014 / 0015 / 0016 (practice-routine generation, goal-driven candidate
selection, speed-trainer staging) describe the **orchestration** layer. They are
re-homed here: the planner becomes a feature *within* Practice — the "Build today's
session" path — that draws from the unit aggregation, weights by what needs work
(stale / low-mastery / recently-failed / stuck-below-reach), time-boxes to the
session length, and runs the units back-to-back. The post-session **journal**
(extending 0038) logs what was trained and *feeds the weighting* so the next built
session reflects how the last one went. This ADR fixes the planner's **home and
inputs**; the detailed mechanics remain governed by 0014–0016 and are built in
Phase C.

### 4. Decouple from the automator; keep one one-way seam

- **The automator becomes a named discovery tool** inside the metronome: play,
  experiment, ramp until your hands break down. It is transient and exploratory and
  **no longer persists per exercise** (at most a single global "last used" config).
- **The seam is one-directional and light:** when the automator surfaces a ceiling,
  a **"Save as exercise"** action hands that tempo into Practice's create flow,
  prefilled. The automator *feeds* Practice; it never *owns* an exercise. No Chinese
  wall, but a clear edge.
- **The engine stops routing training through automator config.** `CommandRamp` and
  `MetronomeAutomator` already both conform to `TempoRamp`; training will hand the
  engine a `CommandRamp` directly (e.g. `engine.run(ramp:)`) rather than piggy-back
  on `setAutomatorMode`/`setAutomatorCeiling`/`setAutomatorCommand`. This removes the
  0045 "arming and training are mutually exclusive at runtime" constraint.

### 5. Clean model rewrite (enabled by orphaning existing exercises)

Because existing exercises are disposable, the additive-only constraint is **relaxed
for this one entity** (and only this one — `Loop`/`Song` keep full ADR 0011/0012
migration discipline). A one-time store reset for the exercise entity is accepted.
That buys a clean model:

- **Rename `MetronomeExercise` → `Exercise`** (drop "metronome" from its identity —
  it is a Practice unit, not a metronome preset).
- **Store the `CommandRamp` recipe natively** (warm-up step count / `stepBPM`, dwell
  intervals, `includeBackoff`, interval unit/count) instead of borrowing the
  automator fields 0045 reused.
- **Drop the free-play automator fields** from the exercise entirely.
- Keep working / command / reach (0045's three tempos) and the pure `TempoStretch` /
  `CommandRamp` logic unchanged — those are sound and already unit-tested.

### 6. Presets are in-house authored content

"Ones we put in" means a small set of curated exercises seeded on first launch.
These are **our** content, authored in-house (consistent with the content strategy —
encode method, don't ship others' material), not lifted from any third party.

### Phasing (protects V1 scope)

- **Phase A (V1) — the decoupling.** Promote Practice to a top-level destination;
  lift exercises out of the metronome; clean-rewrite the model (`Exercise` + native
  `CommandRamp` recipe); add the automator → "Save as exercise" seam;
  `engine.run(ramp:)`. Seed a first batch of presets (or shell-first; see Open
  question).
- **Phase B — command-derived loops in Practice.** Extend working/command/target to
  `Loop` (reusing the unit-generic `TempoStretch` with `×`-unit clamps, as 0045
  anticipated) and surface trainable loops in the same Practice aggregation.
- **Phase C (V2) — orchestration.** The planner (0014–0016) + journal, *inside*
  Practice: built sessions, weighting, reflection feeding back into weighting.

## Consequences

**Positive**

- Each surface gets one job: the metronome/automator *discovers*, Practice *trains*
  and (later) *orchestrates*. The "three unrelated tempo regimes on one screen"
  problem 0045 began addressing fully dissolves.
- The exercise model stops being a union of two recipes; the engine sheds the
  shared-slot constraint.
- The aggregation surface and the unit/orchestration split are exactly what the V2
  planner needs — this is foundation, not detour.
- Exercises become discoverable first-class content instead of a buried sub-feature.

**Costs / new work**

- A new top-level destination + exercise list + create flow (IA work, the bulk of
  Phase A).
- A model rewrite and a one-time exercise store reset (data loss, accepted).
- A preset-authoring workstream.
- The discovery → create seam in the metronome.

**Risks**

- *Scope creep.* The full vision spans V1 (Phases A–B) and V2 (Phase C); the phasing
  exists to keep V1 from ballooning into the planner.
- *The automator must actually aid discovery* — e.g. a "mark this as my command" tap
  at the point of breakdown — or it is just the old ramp with a new story.
- *Single creation path.* Creation should funnel through Practice (fed by the
  automator seam), not exist in two places, to avoid double-entry confusion.

**Revises**

- ADR 0043's "an exercise is a saved metronome setup" framing.
- ADR 0045's "Training Mode rides the automator" implementation (shared fields,
  routing through automator setters, runtime mutual-exclusion) and "Training Mode"
  as a top-level mode. 0045's tempo model and pure logic (`TempoStretch`,
  `CommandRamp`, working/command/reach, promotion) are **retained**.
- Re-homes ADRs 0014 / 0015 / 0016 as the orchestration layer *inside* Practice.

## Open question

**Presets in V1, or shell-first and seed later?** Phase A can ship the Practice
shell with only user-created exercises and add curated presets in a follow-up, or
seed presets from day one. Deferred to the Phase A build decision.
