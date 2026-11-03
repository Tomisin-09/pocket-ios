# ADR 0287 — The metronome records a take

- **Status:** Accepted. Planned with Tomisin on 2026-10-28 and logged on 2026-10-30. Built as item 14
  of the last feature push before 1.4.
- **Date:** 2026-11-03 (`pocket-408-metronome-takes`)
- **Amends:** ADR 0069, which lists the places a take is recorded against: a loop, an exercise or a
  song. The free-play metronome is now one more. Its §1 (the microphone only, never the app's own
  playback) and §2 (isolation by route) stand unchanged.
- **Relates to:** 0160 (the metronome note, whose snapshot columns and caption this copies), 0224 (the
  standalone take, whose flag this partitions with), 0132 (the withdrawal tier in force), 0112 and 0263
  (takes are free), 0286 (the Journal thread, which a metronome take never counts towards)
- **Schema:** six additive optional columns on `Recording`, with no declaration defaults:
  `isMetronome`, `metronomeBpmAtTake`, `metronomeBeatsAtTake`, `metronomeNoteValueAtTake`,
  `metronomeSubdivisionRaw` and `metronomeWithdrawalRaw`. Lightweight migration fills them with `nil`,
  which is right for every earlier take.

## Context

The metronome was the one practice screen with a click and no recorder, and recording yourself
playing to a click is the obvious thing to want there. Takes already ship, and exercise runs already
pair a `StandaloneMetronomeEngine` with a `RecordingController`, so most of this is reuse.

## Decisions

**D1. The microphone only.** ADR 0069 §1 stands. Through the speaker the mic hears the click, which
is the timing reference and is wanted here. With headphones the take is just the playing. Mixing the
click into the file was turned down for 1.4: it needs a new pipeline (an input tap plus latency
compensation) and would amend §1 itself.

**D2. Arm, then start.** The arm sits beside Start, as on an exercise run, and is offered **only while
the click is stopped**. The take begins with the click, from Start *or* the automator's **Start ramp**,
runs through Pause, and ends at Stop or on leaving the screen. Recording mid-click was turned down: the
session would have to sit in `.playAndRecord` whenever the metronome is open, for everyone, whether
they record or not.

Both starts go through one function, `startClick`, which calls `beginArmedTake()` **before** the
click starts. Once the click is sounding, the session's flip to record would happen under it, which is
the glitch ADR 0069's arm grammar exists to avoid. `.onChange(of: transport)` fires too late.

**D3. Leaving the app ends and saves the take; the click plays on.** On `.background` and on an
interruption beginning, through the same `endsTakeOnLeavingApp` every take screen uses. Not on
`.inactive` (Control Center, a banner).

**D4. A take knows it was recorded at the metronome, and what the click was.**
`RecordingOwner.metronome(MetronomeJournalContext)` sets `Recording.isMetronome` and snapshots tempo,
meter, subdivision and withdrawal into raw columns, as the metronome note does (0160 §2): never a
`TimeSignature` or an enum, which crash a migration on device only. `isMetronome` partitions with
`isStandalone` (never both true), and `ownerKind` reads it first, as `JournalEntry.ownerKind` does.

The snapshot is taken **when the take begins**, after the click has started, so the withdrawal is the
tier in force: a ramp plays a full click whatever is configured. A take recorded over a ramp is saved
with the ramp's floor, the tempo it began at, as the metronome note is pinned to the moment it was
opened (0160 §5).

**D5. The caption is "Metronome", written at capture.** It is written into `ownerLabelAtTake`, so the
take's own screen and the export file name read it through the fallback they already had. It is plain
text, never a link, for 0160 §6's reason: opening the metronome would restore whatever state it was
left in, not the click the take was played to. The Journal take row adds the snapshot's summary under
it (*96 BPM · 4/4*), and the Journal's **Metronome** filter now brings the takes with the notes. There
is no unit behind the click, so a metronome take never carries a thread count (0286).

**D6. The way back is a line under Start.** While stopped, *Take saved*, then *3 takes on the
metronome ›*, opens the Takes list for the metronome. No model owns these takes, so `TakesSheet` reads
them from a `@Query` filtered **in memory** (`Recording.metronomeTakes(in:)`), never a `#Predicate` on
the optional (`docs/swiftdata-gotchas.md`). Each row there shows the click it was played to.

**D7. The copy talks about the click.** The arm's hint and the setup line say *when the click starts*.
On a speaker route the line says *the click will be in the take* rather than nudging toward headphones
as if the sound in the room were a backing track, and the live status says the click is in the take
and that headphones record just the playing.

**D8. It travels in the archive.** `RecordingRecord` carries the six columns as optionals. An archive
written before this decodes them as `nil`. Without them, a restored metronome take would come back
reading as an orphan. No `schemaVersion` bump: an added optional is the shape old and new readers
already agree on.

**D9. Free**, like every take.

## Consequences

- `MetronomeView.swift` was at 395 of 400 lines. The transport moves to `MetronomeView+Transport.swift`
  and the take glue to `MetronomeView+Recording.swift`, as `ExerciseRunView` did.
- `MetronomeAutomatorPanel` takes the screen's Start ramp action rather than calling the engine itself.
- The shared record controls gain copy parameters (`armedHint`, `bleedNote`, `bleedNudge`), and
  `TakeSavedNote`'s `owner` becomes `place`, the whole phrase after the count.
- `MetronomeTakeTests` covers the round trip through raw columns, the partition, the caption, the
  filter bucket, the plain caption, the archive round trip, and the in-memory filter.
- A `@Model` change, so the store upgrade is checked over an existing store on the simulator and on the
  device, proved by timestamps rather than counts.
- Owed on the device: a take through the speaker and through headphones, a take started by Start ramp,
  and one ended by leaving the app.
