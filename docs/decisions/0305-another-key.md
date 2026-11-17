# ADR 0305 — Another key: a lick moved to practise it, a song moved to meet your tuning

- **Status:** Proposed. Raised by Tomisin on 2026-11-17 and written up the same day. Nothing is built.
  It's not for 1.4.1, and not before the November marketing month ends; the backlog carries it under
  *After the freeze*. The open questions at the end are Tomisin's to decide.
- **Date:** 2026-11-17 (`pocket-438-another-key`)
- **Would amend:** ADR 0140, *What this closes off*: *"No pitch shifting. `pitch` stays 0"* is lifted
  for the two shifts below and nothing else. Speed stays pitch-preserving, and there is still no
  varispeed. ADR 0227 **D9**: a piece named while its song is raised or lowered records the open
  strings that match the recording, not the strings the player tuned to (D5). On acceptance these
  become `Amends` fields, and the notes this left in 0140 and 0227 become `Amended by`.
- **Relates to:** 0302 (Active listening, where the first shift lives) · 0225 (the piece, one per loop)
  · 0301 (higher, same or lower, which is the same in any key) · 0097 (Hear, which plays named notes) ·
  0123 (key-first spelling) · 0115/0116 (the curated tunings) · 0188 (the archive, which would carry the
  song's shift) · 0195 (a tune-up before a routine) · 0070 (never grades).
- **Schema:** slice 1 has none. The Active listening shift is never saved (D3). Slice 2 adds one
  attribute to `Song`: an `Int` of semitones, defaulting to 0 (D4). It is additive.

## Context

Tomisin, 2026-11-17: the usual advice for "stealing" a lick is to play it in other keys, because that
is how it becomes your own. The proposal is a pitch control in Active listening.

The reason it works: at its own pitch, a lick can be copied by fingering, by where the hand goes. In
another key that shape stops matching the sound, so the player has to rebuild the lick from its
intervals. What they own afterwards is the intervals, which go to any key, rather than one fingering.

Active listening already splits along that line. *Count the notes*, *Higher, same or lower* (0301)
and hum-it-back give the same answer in every key. *Name the notes* is the one step whose answer
changes, so a shifted loop makes it a new exercise on a lick the player already knows.

A second use came up in the same conversation. A lot of recorded guitar is tuned a half step down
(Hendrix and Stevie Ray Vaughan, for two). To play along in standard tuning today, the player retunes,
and the song's notes field already prompts *"Tuning, capo, anything worth remembering…"*
(`SongDetailsSheet`). In a routine
that moves between songs, a retune between blocks stops the session. Raising the song a half step
fixes that without touching the guitar. This isn't an exercise. It's a fact about the recording, set
once.

**The engine already has a pitch control.** Every song's audio goes through `PracticeAudioEngine`:
the song player, loop runs, play-along, Active listening, improvising and the routine preview.
`PracticeAudioEngine` holds one `TimeStretcher`. Apple's high-quality stretcher (`'tmpt'`, 0140 §4)
takes a pitch parameter alongside rate, and so does the `'nutp'` fallback.
`TimeStretcher.writePitchZero()` sets it to 0 at init and nothing writes it again, because 0140 said
so. The stems feasibility note (`docs/research/feasibility-song-splitting-and-stems.md`) already
called this *"a small UI slice … Parked until asked for."* The click bypasses the stretcher (0140), so
it isn't affected.

**Sound quality comes first** (Tomisin, 2026-11-17). That is why the range is six semitones (D2) and
why a listening check is a gate (D7).

## Decision

### D1 — Two shifts, because they mean two things

- **In Active listening, a key to practise the lick in.** It's an exercise setting, like speed, and
  it lasts for the session.
- **On a song, the recording against your tuning.** It's a fact about the recording: set once, kept
  with the song, and heard everywhere the song plays.

They add up: the Active listening shift sits on top of the song's. Pitch is never tied to speed.
Changing one never changes the other. Every shift is in whole semitones.

### D2 — Six semitones either way, in whole steps

- **±6 reaches all twelve keys.** Past six, the same keys come back an octave away. Sound quality
  comes first, and a phase-vocoder stretcher colours the sound more the further it shifts.
- **The engine never goes more than 6 from the recording, whatever asks.** `TimeStretcher` clamps the
  total. With a song raised by 1, the Active listening stepper runs from −7 to +5, which is still all
  twelve keys.
- **No cents.** Fine-tuning a recording that drifted off A440 is a separate question (Deferred).

### D3 — Active listening: the shift starts at 0, every time

- A stepper on the Active listening screen: down and up by a semitone, and a way back to the
  original.
- **Not saved.** It's 0 each time the screen opens, and a routine block doesn't store one.
- The shift sounds in every step: hum-it-back, *Count the notes*, *Higher, same or lower* and *Name the
  notes*.
- **It says what you are hearing.** If the song has a key, it reads *+3 · G → B♭*, spelled key-first
  (0123). If not, it reads *+3 semitones*. Note names on the sheet are spelled for the key you're
  hearing. The neck's faint names still don't move (0227: *a faint name is a map, not a hint*).
- It lives in Active listening, which is Pro, so it is Pro too.

### D4 — On a song: raised or lowered, and saved with it

- The song gains one saved shift, in semitones, default 0. It is set in **Edit song**, beside the key
  picker, because like the key it describes the recording. It doesn't go on the speed bar, which holds
  what you change while you practise.
- **It sounds wherever the song's audio plays:** the song player, loop runs, play-along, Active
  listening, improvising, routine blocks and the routine preview. All of them share the one engine.
- **Never hidden.** When it isn't 0, the song player shows it beside the speed (*+1 semitone*). A song
  that sounds a half step off with nothing on screen to explain it would look like a bug.
- **The song's key stays the recording's key**, and the shift is shown against it: *E♭ → E*.
- **The archive carries it** (0188). An archive or a build without it reads 0, so decode it with
  `decodeIfPresent` and apply the default after.

### D5 — A piece always describes the recording

A loop has one piece (0225). Saving again replaces it, and the song map lays every loop's piece on
one board. So every piece has to be in the same frame, and that frame is the recording.

**Named at a song's shift: saved, translated to the recording.** For the frets, raising a song by *n*
is the same as tuning the guitar down by *n*. 0227 already says *a new tuning keeps the frets*. So the
piece keeps the frets the player placed, and records its open strings as the player's tuning lowered
by *n*: *Standard* at +1 saves as *Half step down*, which is already in the tuning list. A by-ear name
or a chord root is saved *n* below what was heard. This is the job `openMidi` already does (*"so
changing the tuner's tuning later can't silently re-pitch a saved tab"*, `PieceTranscription`).
Removing the song's shift later leaves the piece right. And two players save the same piece: one who
retuned to *Half step down*, and one who raised the song instead.

A tuning with no name in the list (*Drop D* lowered by 1) is described as the player's tuning plus the
shift.

**Shown as you hear it.** Names, and *Hear* (0097), use the song's shift, so a named note sounds like
the loop. The frets are shown as saved, against the strings they were saved with, because that is the
recording's tab. For a piece named at the song's shift, those are exactly the frets the player
played. When the shift isn't 0, the tuning line says so. The wording is the build's to settle.

**Named at an Active listening shift: not saved.**
- What you name at +3 is the lick in another key. It's your version, not the recording.
- Saving it as the piece would replace the names made at the lick's own pitch. Translated back, it
  would also read as a tab for an odd tuning: *Standard* at +3 becomes three semitones down.
- **The taps carry over.** Pitch doesn't move time, so the count stays where it was. *Count the
  notes* saves at a shift exactly as it does at 0.
- **The saved names are hidden while you're shifted**, because they're the answer.
- *Name the notes* at a shift opens a fresh pass over the same taps, and says plainly that the names
  aren't kept. For example: *Naming in B♭ · your names in G stay as they are*.
- *Hear* plays the new names as you named them, which is the key you're hearing.

### D6 — What doesn't move

- Speed stays pitch-preserving, and there is still no varispeed (0140).
- The click, the tuner, the tone engine's own sounds, takes and the metronome in a take (0287) don't
  change.
- Nothing listens for the key or the pitch. Nothing compares what the player names with what they
  named before (0070, and 0227's *never detected, never suggested*).

### D7 — The gate: a listening check before slice 1 merges

This is set before the build, as 0140 §4 was, so it isn't re-argued when it's inconvenient. On a
phone, play a guitar loop at 0, −6 and +6, each at 100% and at the slowest speed (25%). It passes if
Tomisin would practise to it.

If one end fails, there is a fallback that keeps every key. −6 and +6 are the same key, so the range
can stop one short (at 5) on the weaker side. If more than that fails, either the range narrows and
the screen says it reaches fewer keys, or the third-party stretcher 0140 deferred comes back.

## Alternatives not taken

- **±12, the first idea.** Practising in other keys doesn't need the octave. On guitar, a lick an
  octave up is the same shape 12 frets higher. An octave up does help you hear a low line, but that is
  the far end of the range, where the sound is worst. It can come back if D7 shows it holds up.
- **One shift, saved per loop.** It mixes the two meanings, and a lick left at +3 would open in the
  wrong key next week.
- **Saving names made at an Active listening shift as the piece, translated back.** The frets aren't
  ambiguous: the open strings move, as D5 does for a song's shift. The problem is the meaning. The
  piece would stop describing the recording, and its tuning line would read *three semitones down*.
- **Storing the shift beside the names instead of translating** (a piece with a `namedAt` field). It
  adds a field, the song map would have to apply it, and the piece's meaning would split. `openMidi`
  already carries what it would carry.
- **A session shift on the song player too.** Practising the whole song in another key is a real use,
  but it's an exercise, so it belongs with the other one. Two pitch controls on one screen would be
  confusing. Not decided here; it can come back.
- **Expressing the song's shift as the recording's tuning** (*the record is in Half step down*). That
  is closer to how players talk. But a recording can be off for other reasons, like a sped-up master or
  a capo, so semitones are the general case. The control can still *show* the tuning list's name when
  one matches, if the build finds that clearer.
- **Turning *Name the notes* off while shifted.** Simpler, but it drops the step the whole idea is for.

## Open questions

1. **Is the song's shift free?** Speed on the song player is free, and a tuning fix reads like a basic
   need. Lean: free. Either way, `docs/manual/` says what is free and what is Pro.
2. **Is a pass named at a shift kept anywhere,** such as a Journal line, *Named in B♭ (+3)*? Lean: not
   in slice 1. The value is in doing it, and D5's copy says plainly that it isn't kept.
3. **After naming at a shift, can the player reveal their saved names moved to that key?** It would
   show their own earlier answer, with nothing marked right or wrong. Lean: later, and only if 0070's
   line still holds once someone has used it.
4. **Can a routine block hold a shift,** such as *Slow Bend riff in B♭*? Lean: not now. It would be the
   first thing to make D3's shift a saved setting.
5. **What happens to a piece saved before the song's shift changed?** Its frets are right for the
   strings it was saved with, but those no longer match what you hear. Lean: when it's opened to edit,
   the sheet says so and offers to move every fret by the shift on the same string. Where a fret would
   fall off the neck (an open string lowered), it asks rather than guessing a string.

## Deferred

- Cents, for recordings that aren't at A440.
- The octave, unless D7 says it sounds good.
- A third-party stretcher (0140's Deferred list), if D7 fails.

## Slices

1. **Engine and Active listening (no schema).** Add `TimeStretcher.setPitch(semitones:)`, clamped to ±6
   in total. It writes on both backends and is written again after `engine.start()`, as rate is
   (`reassertRate`). Then the stepper, D3's copy, D5's rule for an Active listening shift, and D7's
   gate. Pure unit tests: the clamp and the sum, and the key label for a shift (beside `NoteSpelling`).
2. **The song's shift (schema).** The `Song` attribute, the control in Edit song, the mark on the song
   player, the archive key, and D5's translation on save and its display. Unit tests: *Standard* at
   +1 saves as *Half step down* with the frets kept; by-ear names and chord roots move down by the
   shift; a player who retuned and one who raised the song save equal pieces; the archive decodes a
   missing key as 0. Then the store upgrade check on the simulator.

## Consequences

- 0140's *No pitch shifting* line and 0227's D9 each carry a note pointing here. They become
  `Amended by` when this is accepted.
- Slice 1 changes `TimeStretcher.writePitchZero()` and its comment ("Pitch is never touched again").
- `PieceTranscription.openMidi`'s comment gains *against the recording*. The version stays 1: every
  piece saved so far was named at a shift of 0, where both readings agree.
- `docs/manual/` gains the stepper and the song's shift, and the figures that show either need a
  reshoot.
