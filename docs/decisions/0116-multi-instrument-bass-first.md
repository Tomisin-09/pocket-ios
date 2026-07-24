# 0116 — Multi-instrument: bass first, instrument as a per-exercise axis

- **Status:** Accepted
- **Date:** 2026-07-24 (`pocket-194-multi-instrument`)
- **Builds on:** ADR 0115 (guitar tuner — shipped the `Instrument` enum + lowest-first `Tuning` value in `Core/Theory/InstrumentTuning.swift`, the data foundation this reuses). ADR 0065 (fretboard engine — the highest-first canonical convention). ADR 0068 (`ExerciseTemplate` as the immutable per-exercise axis this sits beside). ADR 0113 (local artist profile — the source of the instrument default). ADR 0036 (SwiftData: never store a raw enum attribute; back it with a `String`).

## Context

The fretboard-family features (scales, chords, arpeggios, custom drills) are guitar-only, but the interval math and rendering are instrument-agnostic — a bass is a 4-string guitar an octave down, and `FretboardGrid` already draws N strings. Extending to **bass** is nearly free; **ukulele** is not (its reentrant gCEA tuning is non-monotonic). The tuner (ADR 0115) already ships the model foundation: an `Instrument` enum and a `Tuning` value type whose string count is just its array length.

Two design forks decide the shape of this work.

### Fork 1 — How does instrument attach to content?

- **Per-exercise axis, defaulted from the profile (chosen).** Instrument is a property fixed at creation, a sibling to the immutable `ExerciseTemplate` axis, defaulted from the ADR 0113 profile ("what do you play") and overridable per exercise.
- **Global "mode" (rejected).** A single app-wide instrument switch fights the Library — a bass exercise would render on a guitar neck the moment the mode is on guitar — and fails the multi-instrumentalist who practices both in one session.
- **Launch-time path pick (rejected).** Same failure, plus it forces a choice before the app knows what the player wants to do.

### Fork 2 — Guitar engine is highest-first; the tuner's `Tuning` is lowest-first. Reconcile how?

The fretboard engine is canonically **highest-first**: `FretNote` documents "0 = high e … 5 = low E", `CAGEDShape.openMidi = [64,59,55,50,45,40]`, `ScaleLayout`, `ChordGrip.RootString`, and the renderer's row-stacking all index that way — **and it is persisted** in every stored drill's `FretNote.string`. The tuner's `Tuning.midiNotes` is **lowest-first** (ADR 0115).

- **Adapt at the boundary (chosen).** Keep both conventions; cross them in exactly one pure place.
- **Unify the conventions (rejected).** Flipping either side either rewrites every persisted drill's string indices (data migration on canonical geometry — high blast radius, no user benefit) or rewrites the tuner. The two subsystems are already correct internally; only the crossing needs defining.

## Decision

**Extend the fretboard family to bass by making `Instrument` a per-exercise axis defaulted from the profile, and cross the tuner's lowest-first tuning into the highest-first engine through one pure reversal adapter.** Ukulele is explicitly out of scope.

1. **One boundary adapter — `Tuning.engineOpenMidi`.** A pure computed reversal of `midiNotes` (index 0 = highest string), the *single* crossing point between the lowest-first tuner model and the highest-first engine. Rules:
   - Raw `tuning.midiNotes` never reaches engine code — only `engineOpenMidi`.
   - A **golden test** asserts `Instrument.guitar.standardTuning.engineOpenMidi == [64,59,55,50,45,40]` and equals the engine's existing `CAGEDShape.openMidi` / `ChordVoicing.openMidi` constants byte-for-byte — proof the refactor changes nothing for guitar.
   - Valid only for **monotonic** tunings. A reentrant tuning (ukulele gCEA) is not a simple reversal — the same non-monotonicity that breaks CAGED box generation — so it is deferred, and when it lands it is chords + custom drills only, no generated scale boxes.

2. **`Instrument` as a per-exercise axis.** `Exercise` grows an `instrumentRaw: String` (declaration default `guitar`, additive migration per ADR 0036 / CoreData 134110), read through a typed `instrument` accessor with an unknown-value fallback to `.guitar`. Fixed at creation like `template`. The create/configure step shows a segmented **Guitar / Bass** control, defaulted from the profile's preferred instrument; guitar-only templates (CAGED-labelled scale boxes) hide or disable off-guitar.

3. **Profile default.** The ADR 0113 `Profile` grows a preferred-instrument field (default guitar) set at intake, feeding the create step's default so the common single-instrument player never sees the choice.

4. **De-hardcode string count at the boundary.** The engine's `stringCount = 6` / `openMidi.count == 6` assumptions are replaced with the exercise tuning's length where bass content flows through, so 4-string content renders and validates correctly. Guitar content, still resolving to the guitar tuning, is unchanged.

5. **Library instrument filter — progressive disclosure.** A filter chip appears only once more than one instrument's content exists; the single-instrument player never sees it.

## Scope ladder

Guitar (shipped) → **bass** (this ADR: tuning-as-value + string-count de-hardcode + the axis) → ukulele (chords + custom drills only, own follow-up ADR — reentrant tuning breaks the reversal and box generation). Existing presets are tagged guitar; bass presets grow a small curated set over time.

## Consequences

- **Guitar is provably untouched** — the golden test pins `engineOpenMidi` to the old constant, and existing exercises migrate to `instrument = .guitar` additively.
- The canonical highest-first convention and its persisted data are preserved; there is one, findable, unit-tested place where orders cross.
- Ukulele and custom/user tunings remain closed off until their own ADR — consistent with the tuner's deferral of the same (ADR 0115).

## Slices

1. **Boundary adapter + golden tests + this ADR** (pure, guitar byte-identical). ✅
2. **`Instrument` per-exercise axis** — `instrumentRaw` on `Exercise` + `preferredInstrument` on `Profile`, plumbed through creation and defaulting to guitar. No visible UI yet (every exercise stays guitar), so this commit is guitar-identical too. ✅
3. Thread the exercise's tuning into the fretboard engine (the de-hardcode); bass scale/arpeggio presets; **and the create-step Guitar/Bass control** — the toggle lands together with the rendering so it never offers an instrument that would draw on the wrong neck.
4. Library instrument filter (progressive disclosure).
