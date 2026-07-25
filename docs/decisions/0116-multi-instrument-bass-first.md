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
3. Thread the exercise's tuning into the fretboard engine (the de-hardcode); bass scale/arpeggio presets; **and the create-step Guitar/Bass control** — the toggle lands together with the rendering so it never offers an instrument that would draw on the wrong neck. ✅
4. **Library instrument filter (progressive disclosure).** ✅ A pinned "All / Guitar / Bass" chip bar
   above the Exercises list, surfaced only once `PracticeLibrarySort.instrumentsPresent` finds more than
   one instrument's content — so the single-instrument player never sees it. The selection is a session
   filter (not persisted) that resets whenever the library drops back to one instrument, so a stale
   choice can never silently narrow the list after disclosure retracts. Filter matching and the
   disclosure threshold are pure in `PracticeLibrarySort` and unit-tested.
5. **Bass render fixes (device-test follow-up).** ✅ Four defects the first on-device pass surfaced — see
   the "Slice 4 device-test findings" section below. Landed via a transient `FretboardDrill.openMidi` (the
   single tuning source the renderer resolves labels/roots against), the warm-up preview passing
   `instrument`, nut-inclusive window framing for open-string boxes, and a grid-alignment fix. Guitar is
   byte-identical (unset `openMidi` ⇒ guitar); covered by `FretboardDrillTuningTests`.
6. **Instrument axis moves to the create sheet.** ⏳ Relocate the Guitar/Bass control from the top of
   `ConfigureExerciseForm` onto the `NewExerciseSheet` template picker — see the "Slice 6" section below.

## Slice 3 sub-decision — bass generation is a ladder-based placement rule, not a truncated CAGED box

Bass isn't CAGED: a bassist plays a scale as a single **2-octave positional shape** across all four
strings. Three routes were weighed — truncate a guitar CAGED box to the low four strings (cheap, but the
run comes out stunted, ~1.3 octaves), hand-author a parallel bass geometry table (highest fidelity, but a
lasting second system to maintain), or a **middle path**: a dedicated `BassNeckLayout` box built on the
*existing, already-property-tested* `ScaleNeckLayout.ascendingTones` tone ladder, laid across the strings
with a bass notes-per-string schedule. The middle path was chosen — it produces a real 2-octave shape with
no parallel CAGED table, inheriting the ascending/in-scale correctness from the shared ladder. Consequences:

- **The label layer forks** (bass string names E A D G, a single low-string-rooted flagship box, region
  labels instead of CAGED letters) — unavoidable for any option that truly generates bass, kept minimal.
- **Bass is box-only:** the diagonal extended-pentatonic and 3-notes-per-string layouts, and the
  blues/bebop passing-tone insertion, are declared **guitar-only** (they're guitar techniques). Bass ships
  **one** canonical box per key in v1 (`positionCount == 1`); octave-shifted positions wait for a follow-up.
- **Instrument is threaded, not persisted in the recipe.** `ScaleRun`/`ArpeggioRun`/`FretboardRun` gain no
  stored fields; `Exercise.instrument` (S2) is passed into `expanded(instrument:)` at render/edit time, so
  there is no payload migration and the guitar `expanded()` path is byte-identical (golden + regression
  tests). Generation uses the instrument's **standard** tuning; alternate/custom tunings stay deferred.

## Slice 4 device-test findings — bass render fixes (planned, 2026-07-24)

The first on-device pass (bass warm-up / scale / arpeggio creation) surfaced four defects. The bass
**geometry** is correct; the faults are in the *editor preview*, the *label layer*, and the *display
window* — none touch the generation invariants proven in Slice 3.

1. **Fretboard previews draw a 6-string neck for bass.** This is not warm-up-specific — it applies to
   **every fretboard-preview surface except Scales and Arpeggios in Generate mode** (which already pass
   `instrument`), and Chords is instrument-neutral so it doesn't apply. Two sub-surfaces:
   - **Generate mode** — `FretboardRunEditor` builds its preview from `run.expanded()` (guitar 6-string)
     instead of `run.expanded(instrument:)`. This one editor backs **Warm-up, Picking, and Legato**, so the
     single call fixes all three. The bass run's span is clamped to four strings, so the notes strand on the
     top four rows of a guitar neck.
   - **Draw-your-own + the plain Fretboard-drill template** — `FretboardDrillEditor` renders from
     `drill.stringCount` (so it's string-count-aware), but its bound `customDrill` is seeded as a 6-string
     drill and never reseeded for bass, so the canvas draws six strings. It's used by the draw mode of
     **all** fretboard families (run/scale/arpeggio) and the plain fretboard-drill template. **Fix:** seed /
     reseed `customDrill` at `instrument.stringCount`, and carry the instrument's `openMidi` on that drill so
     its labels (`FretboardDrillEditor` line ~248 also calls `GuitarScale.pitchClass(string:fret:)`) resolve
     in the right tuning — the same `openMidi`-on-`FretboardDrill` mechanism as finding 2. The guitar guide/
     reference overlay stays guitar-only for a bass draw (no bass CAGED guide — consistent with the ADR's
     box-only bass scope); revisit if a bass guide is wanted.
   - `ExerciseTemplatePreview` thumbnails on the picker remain guitar; once the instrument control moves
     onto the picker sheet (Slice 6) they *could* reflect the chosen neck, but that's optional and separate.
2. **Note names + root anchor are computed in guitar tuning.** `FretboardGrid.label(for:)` and `isRoot(_:)`
   derive pitch class from `GuitarScale.pitchClass(string:fret:)`, which hardcodes `e B G D A E`. On bass the
   geometry is right but every caption and the amber root ring are wrong — an open-E root reads as "D". This
   affects the **live run screen as well as the editor**. **Fix:** give `FretboardDrill` a *transient*
   `openMidi: [Int]?` (modelled exactly on the existing transient `noteGroups` — excluded from `CodingKeys`,
   `nil` ⇒ guitar, no migration), set it in the three bass `expanded(instrument:)` paths, and resolve
   pitch/root/labels through it in `FretboardGrid`. Guitar stays byte-identical; one change fixes both
   surfaces without threading `instrument` through every view.
3. **Open-string notes cram against the nut.** `FretboardDrill.displayLowestFret` excludes open notes, so a
   bass box rooted on an open string (E/A/D/G — the common case) frames from the lowest *fretted* note and
   the open root sits detached on the nut with a gap. **Fix:** nut-inclusive framing (start the window at
   fret 1) when the box contains open notes, so the open root reads contiguously with the low frets. Pure,
   unit-tested; a general improvement that also serves open-position guitar boxes.
4. **String labels misaligned.** The labels' `GeometryReader` fills the whole grid height (board + the
   fret-number row + spacing) while the string lines span only the board, so labels drift downward from
   their rows — worst at the bottom, more visible on four strings. **Fix:** restructure `FretboardGrid.body`
   so the label column and the board share one height, with the fret numbers below both.

Tests: bass label/root correctness through `openMidi`; `FretboardDrill` open-note window framing; existing
guitar golden/regression tests stay green (guitar default unchanged). Re-verify on device after.

## Slice 6 — instrument axis moves to the create sheet (planned)

The Guitar/Bass segmented control currently tops `ConfigureExerciseForm`, which the on-device pass found
crowds the form. Relocate it to the `NewExerciseSheet` **template picker**: a Guitar/Bass control at the top
of that sheet (defaulted from the profile's preferred instrument) seeds the instrument the configure form
opens on. The form then drops both its `instrumentSection` and its `onChange(of: instrument)` reseed logic —
instrument is fixed *before* the form, so it seeds its content once for the chosen instrument. Instrument-
neutral templates (Basic / Strumming / Chords / Chords & Strum) simply ignore the seed. This is a UI move
only — the per-exercise axis (S2) and its persistence are unchanged.
