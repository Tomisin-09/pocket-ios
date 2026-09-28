# ADR 0225 — count the notes: tap along, then name what you heard

- **Status:** Accepted. Built on `pocket-337-count-the-notes`.
- **Date:** 2026-09-27 (planned 2026-09-26, refined 2026-09-27)
- **Amended by:** ADR 0227 (Name the notes on the neck, 2026-09-28). **D5**: the three sheets become two,
  *Fret & string* (a neck you tap) and *By ear* (Chord and Note name merged); the chip grid becomes a
  strip; picking no longer sounds, and *Hear it, then mine* is withdrawn until the tone engine sounds
  like a guitar. **D6**: a fretted label gains optional marks (bend, vibrato, a join) and a multi-note
  *shape* kind; the tuning is chosen per piece but still recorded as before. **D10**: "one note per
  tap", "no technique marks" and "tuning comes from the tuner's settings" are lifted. D5's reason, a
  heard chord named by root and quality rather than a grip, stands, as does the rest of D10. **D7**
  (after 0227's device check): four or more unnamed notes in a row are said as a count, *(60 unnamed)*,
  rather than a `?` each.
- **Amended by:** ADR 0231 (Correct the count while naming, 2026-09-28) — **D5**: Name the notes can
  also take a tap out, or add a note the player missed by tapping it in while the stretch around it
  plays, each with Undo. D3 stands: a tap is only ever one the player made, in song seconds.
- **Amended by:** ADR 0229 (Pieces in the Journal, 2026-09-28) — **D7**: *Save* no longer writes a 🧩
  line. The Journal lists the loop's piece itself, one row per loop, under a new *Pieces* scope, dated
  by when the piece last changed. The `.transcribed` kind stays for marking a lick by hand; D8 stands.
- **Amends:** ADR 0104 — **E3** and **E6**. E3's "no transcription store" is reversed for one case on
  purpose: a loop now carries its **piece**, structured and read by a named future reader (D8). The
  Journal stays the dated history, and free-text notes still go nowhere else. E6's "a tally … is out of
  bounds" is narrowed: a count of what the player heard, entered by the player, is not the tally E6
  meant (D9). No score, streak, accuracy or verdict appears anywhere, so E6's actual guard stands.
- **Amends:** ADR 0094 — the Consequences' line that "any slice proposing a tally or a correct/wrong
  verdict is out of bounds" is narrowed in the same way (D9). T2c and T3 stand unchanged. Name the notes
  is T2b call-and-response applied to the player's own recording.
- **Relates to:** ADR 0070 (never grades) · ADR 0139 (`ear.transcribe`, which nothing served until now)
  · ADR 0140 §3 (the stretcher's latency, already compensated) · ADR 0153 (who may read the playhead)
  · ADR 0154 (grid anchors, why taps are seconds) · ADR 0123 (key-first spelling) · ADR 0115/0116 (the
  tuner's instrument and tuning; highest-first strings) · ADR 0093 (the chord-quality vocabulary)
  · ADR 0097 (Hear, the synth that sounds "mine") · ADR 0188/0189 (the archive and the schema criteria)
  · ADR 0150 (export vs hosting, the hinge the song map will meet).
- **Schema:** one additive attribute, `Loop.transcriptionData: Data?`. It is Optional and stores no
  custom enum (the ADR 0036 crash), so older rows read as no piece and nothing is destructive: ADR 0189's
  burden for a destructive change doesn't arise. One new `EntryKind` raw value, `transcribed`, which
  older builds fold to `.note` (the 0104 E4 pattern).

## Context

The app had no transcription side. Tomisin wanted one, but suspected that tab or notation would drift
from what the app is for. Their own method for learning a lick is to **count the notes in it**, then
work out what they are.

The tools that exist split in two:
- **Manual tap-along tools** work while the loop plays slowly. Transcribe! taps beat, bar and section
  markers live. Soundslice syncpoints are taps at barlines, but need your audio on their server.
  Anytune's transcribe mode works note by note and produces no notation.
- **Automatic tools** are a feature race this app chose not to run (`docs/positioning.md`): Moises (AI
  stems, synced chords and tabs) and Klangio and similar AI audio-to-tab (roughly 70–90% of notes right
  on clean audio, worse on a full mix, and all cloud-based). They also conflict with ADR 0001/0092 (the
  audio stays on the device) and 0094 T2c (no answer to check the player against).

So the lever is the manual tap-along, applied to one lick, as ear training. A playable mockup settled
the shape with the user (https://claude.ai/artifact/VavP3nnhhCkv8D2r5u85BK). A second discussion, the
**jigsaw**, set where it leads: each transcribed loop is a solved piece, and the player's own chart of the
whole song is the finished picture (D8).

## Decision

### D1 — It lives inside Train your ear

**Count the notes** is a section of `EarTrainingView`, so all three hosts get it: the loop-settings sheet,
the Loops library screen and a routine's ear block. It sits under the play and tempo controls. **There's
no waveform in it, on purpose** (0104 E2): you count what you hear, not the peaks you can see.

### D2 — A pad that fires on touch-down, one row per pass

- The pad is a plain shape with a zero-distance drag latch (the `StepperButton` pattern). It is not a
  `Button`, which fires on lift and adds a lag that varies with how long each tap is held, and not
  `onTapGesture` for the same reason. A light haptic confirms each tap.
- Taps count **only while the loop plays**. A tap while stopped says "Press play first".
- **One row of dots per pass**: the pass playing now on top ("Now", with a playhead), then the last four
  finished passes, newest first, each with its count. Tap a row to pick it. When passes agree, you have
  the count. Nothing compares them for you.
- The readout shows the live pass's count while playing, or the picked pass's when stopped.
- **Clear** empties the rows. **Undo clear** stands in its place until the next tap. Pass numbers never
  go back down, so an Undo can't collide with passes tapped since.
- The taps of a visit are scratch paper. Nothing is stored until **Save** (D6).

### D3 — A tap is a place in the song, in seconds

- `PracticeAudioEngine.loopClock()` reads the player's render position on demand, not the once-a-frame
  `currentTime`, so a tap between two frames isn't a frame late.
- The position is **unwrapped** across passes, and the pass is worked out from it. `loopIteration` is
  not used: it counts *rendered* wraps (0140 §3), and the render position runs a full output latency
  ahead of the ear, so near a wrap it has already moved to a pass the player hasn't heard.
- **Output latency is taken off**: `(outputLatency + ioBufferDuration) × rate`, scaled by the rate
  because it is wall time and the loop runs in song time. `currentTime` already corrects the stretcher's
  latency (0140 §3) but not the route's, and Bluetooth adds 150–250 ms. `StandaloneMetronomeEngine` is
  the precedent.
- A tap **within 60 ms (wall time) before the wrap** belongs to the next pass, at its first note: that
  is the player catching the top of the loop early.
- Stored as **song seconds, never beats** (D4, D6).

### D4 — Show beats is a switch, off by default, and honest about the grid

- **Off by default and remembered** (`AppSettings.countShowsBeats`, one default constant). It toggles
  freely, mid-loop included, and nothing about the count depends on it.
- When on, it draws faint beat lines on the rows and a per-beat split under them ("Pass 3 by beat:
  2 · 3 · 3 · 3"). A beat's slot opens 12% of a beat early, so a note tapped a hair early counts where
  it was meant. A sliver of a slot at either edge of the region folds into its neighbour.
- It carries a caption: *"Beats come from the song's tempo and its 1. If the lines don't sit on the beat,
  the grid needs correcting."* The grid is one tempo per song (0154), so it can be wrong.
- It is **hidden when the song has no grid**, meaning no tempo or no 1 placed. ADR 0022 doesn't guess
  the phase, and neither does this.
- **Why an unreliable grid costs nothing:** taps are seconds. Beats are worked out only for display, so
  correcting the grid with a 0154 anchor re-divides the same taps with nothing rewritten. Turning the
  switch off hides a guess and loses no data. (`TapTallyTests` pins this with a drifted song and a
  correcting anchor.)
- The Journal line includes the split **only if beats are on as you save**.

### D5 — Name the notes: hear the real moment, then say what it was

- **Name the notes** opens a sheet for the picked pass. **It stops the loop first**, the way the takes
  sheet does, so nothing plays over a slice.
- The pass's taps are numbered chips. **Tapping a chip plays a slice**: 0.35 s of the real recording,
  starting 80 ms before the tap, at the current tempo. If the tap was off, the slice says so. The slice
  is a PCM buffer with its own envelope (5 ms in, 60 ms out) played through the loop's stretcher, so it
  starts and ends at silence sample by sample, rather than relying on a volume ramp that only moves once
  per render cycle.
- **Three ways to name**, one label type underneath:
  - **Note name**: a 12-name grid, spelled for the song's key where it has one and by the player's
    preference where it doesn't (0123). No octave.
  - **Fret & string**: strings from the tuner's instrument and tuning (0115), thinnest first like the
    tab, so bass gets four; a fret from 0 to 22. The sheet says which, e.g. "Guitar · Standard".
  - **Chord**: a root and a quality, from `ChordQuality.catalog` (0093), each suffix once. **Not a
    grip.** The plan said to reuse `ChordPickerSheet`, but that is a browser of *voicings*, which answers
    "how do I play it", not "what was it". A heard chord is named by root and quality, the way a note is
    named by pitch class. Chord loops open in this mode.
- Picking a label sounds it and moves to the next chip. **Hear it again** replays the slice. **Hear it,
  then mine** plays the slice and then the chosen label through Hear (0097). **The player judges whether
  they match**; the app has no opinion (0094 T2b).
- **Done** keeps the names on that pass for the visit. **Cancel** drops them. Swipe-to-dismiss is off
  once anything has changed.

### D6 — Storage: the loop's piece, replaced on save

- `Loop.transcriptionData: Data?` holds an encoded `PieceTranscription`:
  `version`, `taps: [Tap { seconds, label? }]`, and, when any label is a fret, `openMidi` (the strings,
  highest-first) and `tuningLabel`. **The tuning is recorded with the frets**, so changing the tuner
  later can't silently re-pitch a saved tab. That is data integrity, not a per-loop tuning setting.
- `PieceLabel` is `.pitchClass(Int)`, `.fretted(string:fret:)` or `.chord(root:suffix:)`, coded as a
  tagged object (`{"kind": "note", "pitchClass": 3}`). A kind a build doesn't know decodes as an
  **unnamed tap**, not a failed piece. Every field past `taps` is Optional, so an older build reads a
  newer piece and ignores what it doesn't know.
- **Save** puts the picked pass on the loop and **replaces** any piece already there, after a prompt.
  The dated history lives in the Journal lines (D7).
- **Saved on this loop**, a section under the count, shows the piece: its line of names, and the tab
  when any note has a fret. **Edit names** reopens Name the notes on the saved piece, and Done writes the
  edit back. **Edit pieces, never the picture.**
- The export archive carries it as `LoopRecord.transcription`, as structure rather than a blob, so the
  file reads (0188). It is Optional, so a pre-0225 file decodes. Restore lands it. The share file
  doesn't carry loops, so it doesn't carry pieces.

### D7 — A Journal line of its own kind

*Amended by 0229: Save writes no line now. The Journal shows the piece itself under Pieces, so the lines
described here are the ones written before that change.*

- Save writes, through `JournalWriter.add(to: .loop(loop), …)`, a line like *"11 notes. A C D D♯ E G A G
  E D C"*, plus *"By beat: 2 · 3 · 3 · 3."* when beats are on. Each fact is said once: names only if one
  is named (`?` holds an unnamed note's place; since ADR 0227, four or more in a row are said as a count,
  *"C♯ D♯ A♯ (60 unnamed)"*, because a long pass named only at the start read as a wall of `?`), and no
  split of a single beat. A piece of chords counts "chords".
- It is tagged with a new **`EntryKind.transcribed`** (🧩 "Transcribed", the study hue), not `.ear`.
  Ear notes are also what hum-along writes, and a reader that wants the solved loops (D8) can't tell
  the two apart without parsing prose.
- `.transcribed` is **in `pickerOrder`**, so a lick worked out on paper can be marked by hand. **"Solved"
  is always the player's declaration**, never something the app infers.

### D8 — Why structured: the song map is the reader

0104 E3 refused a second note store because it would duplicate the Journal with nothing to read it.
This is structured data **with a named reader**: the song map (`docs/plans/song-map.md`, parked
2026-09-27). The map lays a song's loops out as pieces on a chords lane and a notes lane, and draws the
player's own chart from them. It needs to know **where** each note sits in the song (seconds, which is
why melodies can sit over their chords) and **what** it is (the label). So every piece saved from 0225
on is on the map the day the map ships, with no migration. That's the retroactive payoff for existing
players, and the reason these storage decisions stand while the map is parked.

A `.txt` tab attachment was in the first plan and is **dropped**: a text copy is a picture that can be
edited apart from its piece, which is the drift "edit pieces, never the picture" exists to prevent.

### D9 — Why a count is not the tally 0094 and 0104 forbid

0094 T2c forbids the app asking, the player answering, and the app scoring. Here the player asks and
the player answers. The app records where they tapped and plays back what is really at that spot. There
is no detected count to compare against, no suggested name, no "match", no score, and nothing charted
over days (0094 T3, 0104 E6). ADR 0200 drew the same line for snags: *where the marks are, never how
many*, and a count charted over time "is a score in everything but name". The number on screen is the player's own count of what they
heard, the way a note in the Journal is their own sentence.

### D10 — Where the tab stops

Anything past this needs a new ADR:
- **One note per tap**: no chords or double-stops in fret mode. A chord is named as a chord (D5).
- **Order only, no durations.** The dots carry the timing.
- **No technique marks** (bends, slides, hammer-ons). Those go in the Journal text.
- **No free-text tab document anywhere.** The finished chart is a derived view (the song map), and
  changing a bar means re-solving its piece.
- **No playing the tab back as a sequence**, only per-note "then mine".
- **Tuning comes from the tuner's settings.** No per-loop tuning control (the tuning is *recorded*, D6).
- **Never detected, never suggested.** Every name and fret is the player's.

## Not planned

- **An onset-detected auto-count.** The drums dominate a full mix, an estimate isn't the truth (ADR
  0004), and next to the player's count it becomes a quiz.
- **Snapping taps to transients.** It moves the player's answer toward the machine's.
- **AI audio-to-tab.** ADR 0092 §A4.
- **A count on the practice (waveform) screen.** You'd count peaks, and the Snag already owns one-tap
  marks there.
- **Hear my taps** (a click at each tap over the loop). A later slice; it would reuse `MetronomeSchedule`.

## Consequences

- The planner's `ear.transcribe` (0139) finally has a surface that serves it.
- `PracticeAudioEngine` loses `private` on `player`, `loopBaseSampleTime` (now `private(set)`),
  `currentSampleTime()`, `heard(_:)` and `startEngineIfNeeded()`, for its `+CountTheNotes` split. The
  main file sits on the 400-line cap. It's the same tax `+LoopBuffer` and `+Metronome` pay.
- `LoopRunModel` and `ContinuousLoopPlayer` each gain a clock read and a slice call, and a slice is
  refused while the loop plays, so neither can land on a live run.
- Only the live pass row reads the clock every frame (0153). It tells the model when the pass changes,
  and nothing else reads the playhead.
- **Owed on a device** (the user's check, not reproducible on a simulator):
  - On the demo song, count a lick at 50% on the speaker, then on AirPods. The dots should land in the
    same places.
  - Tap a chip: the slice should start just before the note, with no click at either end, and a chip
    tapped mid-slice should cut cleanly.
  - Check the pad has no touch delay inside the Form's scroll view. A systematic delay would show up as
    slices that start after their note.

## As built

- Pure, unit-tested: `TapTally` (clock → pass and seconds, the per-beat split, the Journal line),
  `TapPasses` (numbering across runs, Clear and Undo), `CountGrid`, `AudioSlice` (window and envelope),
  `PieceLabel`, `PieceTranscription`, `TabLine`.
- Views: `CountTheNotesSection` (pad, readout, switch, actions), `PassRowsView` (the rows; the live row
  is its own leaf), `NameTheNotesSheet` (+ `+Pickers`), `SavedPieceSection`. State:
  `CountTheNotesModel`, owned by `EarTrainingView` so the sheet and the replace prompt sit at its body
  root (memory: a `.sheet` on a List row loses its write).
- Differences from the plan, all recorded above: the chord picker is root + quality, not
  `ChordPickerSheet` (D5); the plan's separate `NoteLabel` is folded into the one `PieceLabel`; the
  engine read is an unwrapped clock rather than `(heard, iteration, rate)` (D3); and the tuning is
  recorded with the frets (D6).
