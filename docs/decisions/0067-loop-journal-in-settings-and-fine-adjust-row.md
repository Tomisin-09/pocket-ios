# 0067 — Loop journal moves into settings; the row becomes fine-adjust; loops re-arm without restarting

- **Status:** Accepted
- **Date:** 2026-07-05

## Context

Living with the waveform practice screen surfaced a placement problem and a
playback annoyance, both about the saved-loop row (ADR 0038 loop journal, ADR
0041 A/B span editing):

1. **The loop row carried a journal book button that no longer earned its
   place.** ADR 0058 moved journal *authoring* to the Practice run screen and
   left only a read-only "peek" behind — on the waveform that peek was the
   `book.closed` glyph on every loop row (left of the "A" automator control).
   Two problems: (a) a permanent, prominent control for a read-only history is a
   lot of row weight for something you rarely open mid-practice, and (b) it
   keeps the journal visually anchored to the waveform "workshop," blurring the
   split the run-screen move was meant to make. Meanwhile the fastest way to
   resize a saved loop — the edit sheet's **"Adjust range on waveform"** (ADR
   0041 / re-affirmed ADR 0063 as the *only* deliberate path) — was buried two
   taps deep behind hold-to-edit.

2. **Resizing a loop restarted it from the top.** Dragging an A/B edge and
   releasing calls `engine.setLoop`, which unconditionally rebuilds the
   crossfaded region buffer and reschedules at offset 0 — so every release
   snapped the playhead back to the loop start. Mid-audition that's jarring:
   you nudge the end out by a beat and the phrase you were listening to jumps
   back to the beginning.

## Decision

### Journal moves from the loop row into the loop's settings

The read-only journal peek is now a **"View entries"** row inside `LoopEditSheet`
(the loop's settings/info surface), showing the entry count as its trailing value
("None" until there's something to see, matching the ADR 0039 unrated-absence
convention). Tapping it presents the same read-only `JournalSheet(owner:
.loop(loop), readOnly: true)` that used to open from the row. Authoring stays on
the Practice run screen (ADR 0058, unchanged) — this only relocates the peek, one
layer deeper, where a rarely-needed history belongs. The waveform screen's
`journalingLoop` state and its read-only sheet are removed.

### The freed loop-row control becomes fine-adjust

The `book.closed` button is replaced by an `AdjustRangeButton`
(`slider.horizontal.below.rectangle`, matching the edit sheet's "Adjust range"
label icon). Tapping it calls the existing `WaveformPracticeModel.startRangeEdit`
— the same lift-into-A/B-span flow the edit-sheet button already triggers, no new
mechanism. This gives the deliberate range-edit a one-tap entry point from the
row while keeping the edit-sheet button as the discoverable path. It does **not**
reintroduce direct edge-grabbing on the waveform (ADR 0063 locked that off); fine
mode still runs through `startRangeEdit`.

### Loops re-arm without restarting when the playhead still fits

`endABHandle` (the A/B edge-release) now calls
`PracticeAudioEngine.setLoop(start:end:keepingPlayhead: true)` — a new opt-in flag
on the existing method (default `false`, so every other caller is unchanged). When
the flag is set and the live playhead still falls inside the resized region, it
re-arms by seeking to the current position within the new region (plays out to the
new end, then loops) rather than restarting from the start; only when the playhead
now sits outside the region does it restart from the region start. The
inside/outside test is a pure helper, `AudioMath.playheadInsideLoop(_:start:end:)`
(half-open `[start, end)`), unit-tested — the engine just branches on it. The
deliberate seek-to-start entries (`startRangeEdit`, `activate`,
tap-to-close-span) keep their existing behaviour.

**Scope:** the "keep playing" guarantee is deliberately limited to the
playhead-inside-the-new-region case. When you shrink a loop *under* a trailing
playhead it still restarts from the start (the outside branch) — a rarer case not
worth a "wait until the edit settles, then restart" state machine.

## Alternatives considered

- **Keep the journal button on the row, add fine-adjust elsewhere.** Rejected —
  the row only has space for one control next to the automator, and a read-only
  history is the weaker claim on it than the range-edit it now sits beside in the
  edit sheet anyway.
- **Full "let it play through, then restart when the edit settles" behaviour**
  for the shrink-under-playhead case. Out of scope (see Scope) — it needs
  debounce/settle tracking for a case you hit rarely; the within-bounds case is
  the one that actually annoyed in daily use.
- **Move bounds live, mid-drag, without rescheduling.** Not possible cheaply —
  the loop is a pre-rendered crossfaded PCM buffer of the region, so any bounds
  change rebuilds it. The win here is preserving the *offset* on the release
  reschedule, not avoiding the reschedule.

## Consequences

- The waveform screen no longer surfaces the journal at all; the only journal
  peek reachable from a song is now inside each loop's edit sheet. Anyone looking
  for "the loop's notes on the waveform" must open the loop's settings first.
- `setLoop`'s `keepingPlayhead` flag is the re-arm path for edge-drag releases
  only. If a future caller wants offset-preserving re-arm too, it's there; the
  flag defaults to `false`, so no existing caller changed behaviour.
