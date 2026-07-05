# 0065 — Exercise content templates ("what to play" over the tempo engine)

- **Status:** Accepted (2026-07-05)
- **Date:** 2026-07-05

## Context

Today an `Exercise` run (ADR 0046, `ExerciseRunView`) answers exactly one
question: **how fast.** It plays a metronome, counts in, and climbs the
working → command → back-off `CommandRamp` staircase (`RoutineStairs`). It
knows tempo, meter, subdivision, and accents — and **nothing about the notes,
fingers, or strums the player is actually meant to execute.** Every exercise,
from "Spider Walk" to "Chord Changes" to a strumming drill, renders identically:
beat dots over a tempo climb.

For many drills that is enough — a timing exercise wants a click and nothing
else. But the exercise inventory (`Exercise inventory` sheet, 2026-07-05) is
dominated by drills whose *content* is the point: strumming patterns (down/up
arrows on a beat grid), spider/warm-up finger sequences, scale and arpeggio
runs, chord progressions. For these, a bare metronome makes the app a
stopwatch; the practice value is in *seeing the pattern* in time.

The project's technique taxonomy (`docs/practice-techniques.md`) already carries
a **`Default mode`** column (`speed-ramp`, `loop-drill`, `metronome`,
`off-guitar`, `repertoire`) — a pedagogically-grounded map of *how each skill is
practised*. That column is, in effect, an unbuilt template map: it says which
drills want a richer surface than the click.

This ADR decides how a richer per-exercise surface is modelled and rendered,
**without** disturbing the existing tempo engine or any existing exercise.

## Decision

A **content template** is the "what to play" layer, rendered over — never
instead of — the existing metronome/ramp engine. Nine rules govern it.

- **T1 — A template is orthogonal to the tempo ramp; both ride one clock.**
  The metronome is the single time source. A template is a *visual/interactive
  layer* driven by the current beat; the `CommandRamp` speed climb is
  independent. A strumming drill can run at a fixed tempo *or* climb a ramp —
  the two compose, they don't replace each other. The metronome-only view stays
  the universal underlay and the fallback.

- **T2 — The template is selected by a new `Exercise.kind`.** A String-backed
  enum (the ADR 0036 enum-attribute rule — never a raw enum attribute), with a
  **declaration default of `.metronome`** so every existing exercise is
  untouched and the migration is additive (the CoreData 134110 rule). `kind`
  chooses the renderer; it does not change the tempo model.

- **T3 — The template families are a small, closed set**, each mapped to
  taxonomy modes:

  | `kind` | Renders | Serves (taxonomy) |
  |---|---|---|
  | `metronome` (default) | today's beat dots + ramp staircase | `rhythm.timing`; fallback for all |
  | `strumming` | animated down/up/rest arrow lane, current slot lit | `rhythm.strumming`, `rhythm.syncopation` |
  | `fretboard` | notes animating on a fretboard in time | `fret.*`, `pick.*`, `scale.*`, `know.notes/intervals`, chromatic |
  | `chords` | chord diagrams + a per-bar progression stepper | `rhythm.chord-changes`, `know.chord-construction` |
  | `flashcard` (reserved) | quiz surface, no metronome | `off-guitar`, `ear.*` |

  New kinds are a deliberate, ADR-worthy addition — not an open extension point
  filled ad hoc.

- **T4 — The payload is a versioned `Codable` value blob, not a child model.**
  A template's content (a strum pattern ≈ 8 slots of down/up/rest; a fretboard
  drill = a list of `{string, fret, beat, technique?}`; a progression = an
  ordered list of chord shapes) is a small, self-contained **recipe**. Store it
  as `Exercise.templatePayload: Data?` — a `Codable` struct per kind, carrying
  its own `version: Int`, encoded to `Data`.
  - **Why not a child `@Model` per kind:** it multiplies schema + CloudKit
    surface and buys nothing — the payload is *never relationally queried* (we
    never ask "all exercises whose third strum slot is an upstroke"). ADR 0058
    chose typed relationships for the journal precisely because entries *are*
    queried and need cascade/inverse; a template payload is the opposite case.
  - **Why versioned in-band:** a `version` field inside the Codable struct lets
    the pattern schema evolve with a decode-time upgrade, **no store migration**
    — the blob is opaque to SwiftData, which is acceptable *because* it is never
    queried. Optional field ⇒ additive migration.

- **T5 — The renderer switches in `ExerciseRunView`; unknown/absent ⇒
  metronome.** The run screen picks a template view by `kind`; a missing payload
  or an unrecognised kind falls back to the metronome view (forward-compatible:
  an older build opening a newer exercise still runs it as a click drill). Each
  template view is a **thin skin over pure timing math** — "which slot/beat/chord
  is active at time *t*" is pure, SwiftUI-free, and unit-tested (AGENTS.md); the
  view only draws it.

- **T6 — Templates are optional and independent of the ramp.** An exercise may
  have a template and no ramp (fixed-tempo pattern practice), a ramp and no
  template (today), both, or neither. Nothing about adding a template forces a
  speed climb, and nothing about a ramp requires a template.

- **T7 — Some techniques deliberately get *no* interactive template.** Vibrato,
  bends, and palm muting are expressive/feel techniques where a positional
  animation **misleads** (a bend is a pitch you hear, not a fret you land). These
  stay `metronome`-kind (or, better, are practised as `loop-drill` on the user's
  own audio) with a written description and an optional reference. Recorded so a
  misleading "bend animation" is never built.

- **T8 — Pattern content is generic pedagogy, authored in-house.** A D-DU-UDU
  strum, a 1-3-4-2 spider, a I–IV–V progression are common-practice vocabulary,
  not anyone's protected expression — safe to encode. But all copy, diagrams,
  and the specific curated set stay ours (the content strategy,
  `docs/research/guitargearfinder-catalog.md`). No third-party exercises, TAB, or
  prose enter the payloads.

- **T9 — The seeded presets adopt kinds over time.** `PracticePresets` (ADR
  0046) currently seeds six `metronome` drills. Once a template exists, the
  matching preset gains a `kind` + payload (e.g. "Chord Changes" ships a real
  G–C–D progression, the strumming preset ships the sheet's pattern), under a new
  `practicePresetsSeeded.v2` key so the upgrade seeds cleanly without disturbing
  existing users' edited/deleted v1 presets.

## Build order

1. **`strumming`** — self-contained, the visual is already designed (the
   down/up arrow lane), and it validates the whole template mechanism (kind +
   payload + renderer switch + pure slot-timing) on the simplest case.
2. **`fretboard`** — the largest family, and the **same renderer** as the
   tab→fretboard feature (`docs/research/feasibility-tab-to-fretboard.md`, Phase
   R) and the future preset guides. Build the animated fretboard once, reuse it
   three ways.
3. **`chords`** — a chord diagram is a fretboard subset, so it rides on (2).
4. **`flashcard`** — a different interaction (no metronome); deferred until an
   off-guitar practice surface is wanted.

## Consequences

- Additive schema only (`kind` with a `.metronome` default + optional
  `templatePayload`); every existing exercise runs exactly as today. Device-verify
  the migration before merge (the SwiftData migration rule).
- The `fretboard` renderer becomes a shared asset across three features
  (exercise templates, tab→fretboard, first-party preset guides) — build it as a
  reusable, pure-model-driven view, not an exercise-only one.
- Exercise **creation** grows a per-kind payload editor (a strum-pattern editor,
  a fretboard-sequence editor). Deferred and sliced per template; the run-side
  renderer can land and be exercised by seeded presets before an authoring UI
  exists.
- Composes with routines (ADR 0066): a routine is a sequence of *typed*
  exercises, so each richer template makes routines richer for free.

## Alternatives considered

- **A `kind` enum with associated-value payloads in Swift, persisted by
  flattening each case's fields onto `Exercise`.** Rejected — every new template
  adds columns to the shared `Exercise` table, most null for most rows; the blob
  keeps template data self-contained and the core model lean.
- **A child `@Model` per template kind (relationship from `Exercise`).**
  Rejected per T4 — relational machinery for data that is never queried
  relationally.
- **A single generic key-value payload the renderers interpret.** Rejected —
  loses compile-time typing of each pattern; a typed `Codable` struct per kind
  keeps the pure timing math checkable.
- **Rendering templates on the waveform/loop screen instead of the exercise run
  screen.** Rejected — exercises are audio-free click drills (ADR 0043/0046); a
  template is their content surface, and the run screen is where they're played.
