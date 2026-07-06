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

- **T10 — Renderers draw from semantic `PocketColor` tokens only; never literal
  hex.** Every colour in a template view resolves through a semantic role
  (`practice` = content, `metronome` = clock, the loop/accent tokens = note
  state, the surface/ink tokens for chrome) — the same discipline
  `DesignTokens.swift` already enforces app-wide ("do not hard-code hex values").
  This is what makes a template **theme-agnostic**: it inherits light/dark (ADR
  0062/0063) and any future **swappable `Theme`** (the seam `DesignTokens.swift`
  anticipates — "each role becomes a `Theme` property; the current values become
  the 'teal' theme") for free. A renderer that bakes in a literal colour silently
  opts out of theming and is a review-blocker. Two down-to-earth rules that follow:
  a strum down/up-stroke, a lit fret, a current-chord highlight all read via
  *roles* that already differ per appearance; and a template must clear contrast
  on **every** theme's ground, not just near-black (the ADR 0063 wash-token lesson
  — a low-opacity accent that reads on dark can vanish on cream).

## Build order

1. **`strumming`** — self-contained, the visual is already designed (the
   down/up arrow lane), and it validates the whole template mechanism (kind +
   payload + renderer switch + pure slot-timing) on the simplest case.
2. **`fretboard`** *(implemented 2026-07-05)* — the largest family, and the **same
   renderer** as the tab→fretboard feature
   (`docs/research/feasibility-tab-to-fretboard.md`, Phase R) and the future preset
   guides. Build the animated fretboard once, reuse it three ways. Landed as
   `FretboardDrill` (pure timing math) + `FretboardGrid`/`FretboardView` (the skin),
   with `.scales`/`.picking`/`.legato`/`.fingerstyle`/`.warmup` templates all pointing
   `renderer` at `.fretboard`, and a seeded "Chromatic Warm-up" preset (v3 batch). The **authoring editor** followed in the same body of work
   (`FretboardDrillEditor`): the "steps lane + tap-to-place" model — a subdivision
   segmented control (¼/⅛/triplet/1⁄16, re-gridding via `resized`), a slot strip, an
   interactive board that writes the selected slot via `replacingNote`, and a
   fret-position window so drills can sit anywhere on the neck. With an editor in hand,
   a fretboard-family template now seeds a `defaultFretboardDrill` (spider-walk canvas)
   at creation — the inverse of the renderer-only slice, where a payload-free family
   template deliberately fell back to the metronome. The host sheets pick the editor via
   `ExerciseTemplate.bespokeEditor`.

   - **Authoring by generation, not placement.** The tap-to-place grid above makes the
     player do the teacher's job — hand-place every note — and device testing found it
     fiddly with a confusing up-front subdivision control. The pivot: **you declare the
     *shape* and the app generates the notes.** A `FretboardRun` recipe is a *movable*
     finger pattern — finger numbers (`1-3-2-4`) anchored to a **base fret**, travelling a
     **string span**, optionally **up and back** — expanded (pure) into the same
     `FretboardDrill` the renderer plays; change the span and the whole run re-generates,
     nothing is dragged. `FretboardRunEditor` skins it, with a **live `FretboardDrillPreview`**
     (self-driving clock, no engine) so the run is visible before it's saved, and the
     subdivision demoted to an "Advanced" disclosure (default eighths). The payload is a
     discriminated `FretboardContent` (`.run` | `.custom`) so the generative editor and the
     grid coexist on one blob; `Exercise.fretboardContent` best-effort decodes a legacy
     bare-`FretboardDrill` blob into `.custom` for back-compat. **Editors are now
     template-specific, not merely renderer-derived** (`bespokeEditor`: `.strumming` /
     `.run` / `.scale` / `.fretboardGrid` / nil): Warm-up/Picking/Legato/Fingerstyle declare
     a run and seed a real chromatic warm-up at creation (`defaultFretboardContent`).

   - **Scale library (Slice 2, landed) — generated, not hand-drawn.** Scales are *picked*, not
     placed: a `GuitarScale` is just an **interval formula** (e.g. major `0 2 4 5 7 9 11`), and a
     `ScaleRun` recipe (scale + root + **position** + **octaves** + up-and-back + subdivision,
     `FretboardContent.scale`) **generates** the notes onto the neck — so every scale is correct
     by construction and a new scale costs one line. The generator is a **four-fret hand box**: it
     starts on the position's tonic and climbs scale tones, moving to the next string whenever the
     next tone would leave the box the current string opened on. Notes-per-string therefore *vary*
     the way a real CAGED shape does (the A-major E-shape is 2·3·3·3·2·2, not a flat count) — the fix
     for boxes with a fixed per-string count "falling apart" past the first octave (the blues, which
     is a pentatonic-plus-tritone, and the diatonic scales). **Positions** (1…`positionCount`, one per
     scale tone — 5 for a pentatonic, 7 diatonic) climb the neck by anchoring on successive scale
     tones; **octaves** (capped at 2) trim the run root-to-root. `ScaleRunEditor` is menus + a
     position stepper + an octave toggle over a live preview. Correctness is guaranteed by a test
     asserting every generated run (all scales × positions × octaves) is in-scale, strictly
     ascending, and spans exactly the requested octaves (count `= octaves × scaleSize + 1`) — the
     net that makes generation safe (T8: common-practice vocabulary, in-house). First set:
     minor/major pentatonic, major, natural minor, blues; a seeded "A Minor Pentatonic" ships (v4).
     The tap-to-place grid (`.fretboardGrid`) is **retained as the general custom escape hatch**,
     though no template selects it by default now.

   - **Arpeggio library (Slice 3, landed) — its own category, same boxes.** Arpeggios are a *separate*
     template (`.arpeggios`) so the option lists stay short, but they generate from the identical five
     `CAGEDShape` boxes: `ArpeggioQuality` (major, minor, maj7, min7, dominant 7) is an interval
     formula plus the *relative major* whose box it borrows, chosen so every chord tone is diatonic to
     that major (major/maj7 → 0; minor/min7 → +3; dominant 7 → +5, its V7 parent), and `ArpeggioRun`
     places the box and filters it to the chord tones — the box+filter generator (`CAGEDShape`) is now
     shared by scales and arpeggios. `FretboardContent.arpeggio`, an `ArpeggioRunEditor`, and a seeded
     "A Minor 7 Arpeggio" (v5). A **CAGED + triads** category remains a noted future.

   - **Exercise-audio seam (scaffold).** `ExerciseAudioEngine` (a `Sendable` protocol), an
     `AccompanimentSettings`/`AccompanimentStyle` shape, and a SwiftUI `\.exerciseAudio` environment
     value default to a `SilentExerciseAudio` no-op; a `SoundPreviewButton` reads `isAvailable` and
     reads "Sound soon" until a real backend is injected at the app root. The audio itself is deferred;
     only the boundary, settings shape and injection point are factored in now, so it slots in with no
     call-site churn.

   - **Grid narrowing.** The fretboard drills this serves are *even runs* (one note
     per subdivision), so `FretboardDrill` narrows T4's `{string, fret, beat}` event
     list to an evenly-gridded `[FretNote?]` with `notesPerBeat` (`beat = index /
     notesPerBeat`), `nil` = rest — reusing the exact wrap/active-index math proven for
     `StrumPattern` rather than a second timing model. Arbitrary-beat events are
     deferred until a drill needs an uneven rhythm; the in-band `version` lets that
     arrive as a decode-time upgrade with no store migration (T4). The display fret
     window is *derived* from the notes (min fretted → span, min width 4), so the
     payload stays lean.
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
- Because every template obeys T10, **swappable themes and templates are the same
  bet** — each new template reskins under any theme automatically, and shipping
  themes never has to revisit the templates (see the backlog "swappable themes"
  note and the template-gallery preview, which reskins all five from one control).
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
