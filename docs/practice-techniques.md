# Pocket technique taxonomy

The controlled vocabulary of **skills** the planner reasons about. It is the bridge
between a user's goals and the items a session schedules:

- **ADR 0015 (S2)** maps each goal to a set of skill IDs from this list.
- **ADR 0015 (S3)** resolves each skill to candidate *slots* (a loop, a speed-trainer
  ramp, a drill, a repertoire run) that the user fills with their own material.
- **ADR 0016** uses the per-skill `default mode` and `difficulty` to stage speed work
  behind the control/coordination work it depends on.

This is a **living reference**, not a decision record; it will grow. It is pure data —
no SwiftUI, no audio — and is intended to back a small enum/table in the Phase-3
planner.

## Clean-room / provenance note

Technique **names** here are generic guitar-pedagogy terms (alternate picking, hammer-ons,
pentatonic scale, …) and are not anyone's protected expression. The **structure, the IDs,
the mode/difficulty/prerequisite columns, and any drill descriptions are our own.** This
file deliberately contains **no third-party exercises, TAB, charts, or prose**. Where a
skill needs concrete practice material, the user attaches their own (ADR 0015 S3); a
first-party, in-house content set is a future option (see
`docs/research/guitargearfinder-catalog.md`). Do not paste source-article content into
this file.

## Columns

- **ID** — stable identifier the planner/`Goal` references (`SkillID`).
- **Difficulty** — `beg` / `int` / `adv`; used by ADR 0016 to order prerequisites.
- **Default mode** — how this skill is usually practised, which maps to a Pocket feature:
  - `loop-drill` → region looping on the user's audio
  - `speed-ramp` → the per-loop automator (ADR 0013/0016)
  - `metronome` → timing practice (future transport "Auto" slot)
  - `off-guitar` → ear/theory/listening (no instrument needed; cf. "practice without a guitar")
  - `repertoire` → playing a song from the library end-to-end
- **Prereqs** — skill IDs that should generally come first (feeds ADR 0016 S/A4 staging).

## Picking-hand technique

| ID | Name | Difficulty | Default mode | Prereqs |
|----|------|-----------|--------------|---------|
| `pick.alternate` | Alternate picking | beg | speed-ramp | — |
| `pick.string-skip` | String skipping | int | speed-ramp | `pick.alternate` |
| `pick.economy` | Economy picking | int | speed-ramp | `pick.alternate` |
| `pick.sweep` | Sweep picking | adv | speed-ramp | `pick.economy` |
| `pick.tremolo` | Tremolo picking | int | speed-ramp | `pick.alternate` |
| `pick.hybrid` | Hybrid picking | adv | loop-drill | `pick.alternate` |

## Fretting-hand / legato

| ID | Name | Difficulty | Default mode | Prereqs |
|----|------|-----------|--------------|---------|
| `fret.dexterity` | Finger dexterity & independence | beg | speed-ramp | — |
| `fret.stretch` | Finger stretching | int | loop-drill | `fret.dexterity` |
| `fret.hammer-on` | Hammer-ons | beg | speed-ramp | `fret.dexterity` |
| `fret.pull-off` | Pull-offs | beg | speed-ramp | `fret.dexterity` |
| `fret.legato` | Combined legato runs | int | speed-ramp | `fret.hammer-on`, `fret.pull-off` |
| `fret.slide` | Slides | beg | loop-drill | `fret.dexterity` |
| `fret.bend` | Bends (incl. pitch accuracy) | int | loop-drill | — |
| `fret.vibrato` | Vibrato | int | loop-drill | `fret.bend` |

## Fretboard knowledge

| ID | Name | Difficulty | Default mode | Prereqs |
|----|------|-----------|--------------|---------|
| `know.notes` | Note names across the fretboard | beg | off-guitar | — |
| `know.intervals` | Intervals | int | off-guitar | `know.notes` |
| `know.chord-construction` | Building chords from theory | int | off-guitar | `know.intervals` |

## Scales & improvisation

| ID | Name | Difficulty | Default mode | Prereqs |
|----|------|-----------|--------------|---------|
| `scale.major-minor` | Major / natural-minor scales | beg | loop-drill | `know.notes` |
| `scale.pentatonic` | Pentatonic scales | beg | loop-drill | `know.notes` |
| `scale.blues` | Blues scale | int | loop-drill | `scale.pentatonic` |
| `scale.modes` | Modes | adv | loop-drill | `scale.major-minor` |
| `improv.vocabulary` | Soloing / improv vocabulary | int | repertoire | `scale.pentatonic` |

## Rhythm & timing

| ID | Name | Difficulty | Default mode | Prereqs |
|----|------|-----------|--------------|---------|
| `rhythm.chord-changes` | Clean chord changes | beg | loop-drill | — |
| `rhythm.strumming` | Strumming patterns | beg | metronome | — |
| `rhythm.timing` | Metronome timing & subdivisions | beg | metronome | — |
| `rhythm.syncopation` | Syncopation | int | metronome | `rhythm.timing` |

## Ear & musicianship

| ID | Name | Difficulty | Default mode | Prereqs |
|----|------|-----------|--------------|---------|
| `ear.relative-pitch` | Relative pitch / interval recognition | beg | off-guitar | — |
| `ear.transcribe` | Transcribing by ear | int | off-guitar | `ear.relative-pitch` |
| `ear.active-listening` | Active listening | beg | off-guitar | — |

## Repertoire & creativity

| ID | Name | Difficulty | Default mode | Prereqs |
|----|------|-----------|--------------|---------|
| `rep.learn-song` | Learning a song | beg | repertoire | — |
| `rep.master-song` | Mastering one song deeply | int | repertoire | `rep.learn-song` |
| `create.songwriting` | Songwriting | int | off-guitar | `know.chord-construction` |
