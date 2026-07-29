# ADR 0121 — A command tempo is bound to the rhythm it was measured in

- **Status:** Accepted
- **Date:** 2026-07-29
- **Supersedes / amends:** amends ADR 0045 (adds a second dimension to the term *command tempo*);
  retires the `Exercise.subdivision` half of ADR 0043's feel model. Builds on the display-only pass
  shipped the same day (Slice 3a, no ADR).
- **Number note:** 0120 is reserved for the analytics/privacy ADR sketched in `docs/backlog.md`
  Slice 8; this took the next free number rather than that reservation.

## Context

ADR 0045 defines the **command tempo** as a *measured achievement* — the fastest you can play a
drill clean and repeatable — not an aspiration. It is stored as a single absolute BPM.

A BPM on its own is half a fact. 80 BPM means four different things at quarters, eighths, triplets
or sixteenths, and the drill's rhythm is **editable after the command is measured** (the Advanced →
Rhythm dropdown, renamed from "Subdivision" in the 2026-07-28 authoring pass, which made it the most
reachable control on the sheet). Moving eighths → sixteenths quadruples what a beat demands while
the stored 80 sits unchanged: a measured achievement silently revalued, with no event marking it.

Two things were found while building this, both of which changed the shape of the fix:

1. **There were nominally two note-rate axes, but only one was ever real.** `Exercise.subdivision`
   was documented as the metronome's click density — yet `StandaloneMetronomeEngine.setSubdivision`
   is only ever called from the standalone metronome screen. An exercise's subdivision never reached
   the click. It was written by the preset seeder, copied by duplication, and read by exactly one
   label. It stated a rhythm the drill did not play. (Strumming drills are the exception and are
   genuinely wired — the run arms `engine.setStrumPattern`, so their slots do sound.)
2. **The other half of the "what breaks" list was wrong.** Planner emphasis ranks on mastery and
   `lastPracticed`, never a tempo; the `RoutineStairs` signpost describes one exercise at one rhythm.
   Neither compares across rhythms, so neither needed changing. The real exposure was the library's
   command sort (fixed in Slice 3a) and the journal's `commandBpmAtEntry` snapshots.

This lands inside the **no-users window**: v1.0 is approved but distribution is deliberately held, so
a model change owes no migration and can be backfilled outright.

## Decision

**One rhythm concept, and a command tempo that carries its own.**

1. **Retire `subdivision`.** The stored attribute survives un-removed (dropping a SwiftData
   attribute is not a lightweight migration — same treatment as the vestigial `targetTempo`), but
   nothing writes it and only the one-time backfill reads it. The user-facing word is **Rhythm**,
   everywhere, and the detail sheet's Feel section shows one row instead of two.
2. **`Exercise.notesPerBeat: Int?`** states the rhythm for a template whose content declares none.
   Content that carries its own `notesPerBeat` — every fretboard run, every strum pattern — remains
   authoritative, because that is what the Rhythm dropdown edits and what the drill plays.
   `Exercise.noteRate` resolves the two: content → own → `nil`.
3. **`nil` means "not stated", never "quarters".** A chord-changing drill states no note density, and
   no surface invents one for it. This is what keeps a label honest: a rhythm shown is a rhythm
   claimed.
4. **`Exercise.commandNotesPerBeat: Int?`** binds the measured command to the rhythm it was earned
   at. Every promote runs through `promoteCommand`, so the binding cannot be forgotten at a call
   site. `nil` means nothing is bound — no measured command, or a command measured on a drill that
   states no rhythm — and never "legacy, unknown, be careful".
5. **A rhythm change becomes an event with two honest answers**, presented before anything is
   written (`RhythmChangePrompt`, shown from `ExerciseShapeSheet`):
   - **Keep the same note speed** — every tempo rescales so notes-per-minute is unchanged (80 @
     eighths → 40 @ sixteenths) and the command re-binds. The achievement survives, restated.
   - **Re-measure** — the command and its binding clear, and the drill reads "not yet measured"
     until one is earned at the new rhythm.
   Both rescale the **working floor**: a warm-up floor left at the old rhythm is the wrong speed to
   warm up at, whichever answer was given. The pins (reach, backoff) are restated, not discarded.
6. **The journal snapshots the rhythm too** (`JournalEntry.commandNotesPerBeatAtEntry`), so an old
   entry's "80 BPM" stays readable after the drill moves on. Entries written before this show a bare
   BPM: the snapshot is immutable (ADR 0038), so an unrecorded rhythm is left unstated rather than
   back-filled from today's drill.
7. **A one-time backfill** (`ExerciseNoteRateBackfill`) moves the retired subdivision into
   `notesPerBeat` and binds every existing measured command. It is idempotent, and it deliberately
   leaves a stated-nothing unstated.

**The prompt has two answers and no cancel.** The player has already made the change; both options
resolve it, and dismissing without answering is the one outcome that leaves an achievement silently
revalued — the exact failure this ADR exists to prevent.

**Notes-per-minute stays a comparison aid, never a difficulty score** (carried forward from Slice
3a). Triplets at 80 and sixteenths at 60 are both 240 npm and are not equally demanding. It
describes, sorts and labels; it never judges. Growing it into a derived "level" or an ability ranking
would be grading the player, which **ADR 0070** rules out.

## Consequences

- The term *command tempo* now has two dimensions. Any surface that renders it should render its
  rhythm; `Exercise.commandProgressLabel` does this once for all four row implementations, and reads
  the **bound** rhythm rather than today's, since the label describes the measurement.
- `Exercise.swift` crossed the 400-line ceiling, so the tempo model moved to `Exercise+Tempo.swift`.
- The ramp math is untouched. Working, reach and back-off all derive from command proportionally
  (`TempoStretch`), so they were always note-rate-invariant; only comparison and edit safety were
  broken.
- **No new authoring control**, deliberately. Rhythm stays editable exactly where it already was —
  the content editors' dropdown. Giving content-less templates (Basic, Chords) their own Rhythm
  control would let a drill state a rhythm it renders nothing for; if that's wanted later it is a
  small follow-up, not part of this.
- The backfill's binding is an **assumption** — that a command was measured at the drill's current
  rhythm. That is right for every seeded preset and affordable only because there are no users. If a
  build ever ships before it runs, this owes a real unknown-provenance state instead.

## Alternatives rejected

- **Wire the subdivision up so the click actually subdivides.** Honest in one sense, but a behaviour
  change: sixteenths at a command of 120 is 480 clicks a minute, and the ramp climbs from there. It
  would need its own volume/on-off control to be usable, which is a metronome feature, not this one.
- **Leave both fields and add only the binding.** Smallest change, but it leaves "Rhythm: Eighths /
  Subdivision: None" on screen indefinitely — a contradiction the device pass had already flagged.
- **Silently rescale the command on a rhythm change.** An unannounced rewrite of a measured
  achievement. Rejected on the same grounds as ADR 0070's no-grading wall: the app does not quietly
  decide what your playing was worth.
- **A stored `notesPerMinute` field.** Derivable from BPM × rate; storing it is a denormalisation
  that goes stale the moment either input moves.
- **A global difficulty ordering built on npm.** See the scope decision above.
