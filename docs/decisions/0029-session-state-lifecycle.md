# 0029 — Practice session state: clean on entry, wipe on exit

- **Status:** Accepted
- **Date:** 2026-06-21

## Context

The practice screen mixes two kinds of state on `WaveformPracticeModel`:

- **Persisted song data** — BPM, downbeat anchor, saved loops and markers. These
  belong to the `Song` and must survive across sessions untouched.
- **Transient session knobs** — the playback **speed** multiplier, the **active loop**,
  the **metronome** toggle, the interaction **mode**, the playhead. These are about
  *this* practice sitting, not the song.

Most transient knobs already started clean: `speed` is `1.0`, the playhead is `0`,
`mode` is `.navigate`, `metronomeOn` is `false`. But `activeLoopID` was seeded in
`init` to `song.loopsByStart.first?.uid` — so opening a song with saved loops armed
the first one silently. The first ▶ then looped a region the user never chose,
instead of playing the song through. The intent for this screen is the opposite:
practice opens on the **whole song**, and you arm a loop deliberately.

The model is recreated on each screen entry (it's `@State` built in the view's
`init`) and torn down on exit, so "wipe on exit" is mostly handled by deallocation
today. But the lifecycle contract wasn't expressed anywhere, leaving it fragile to
any future change that caches or reuses the model.

Note: "tempo" in this context means the transient **speed multiplier**, not the
song's stored **BPM**. BPM is persisted song data and is never wiped.

## Decision

- **Clean on entry.** `activeLoopID` starts `nil`. Practice opens on the full song;
  a loop arms only when you tap its row, punch a new one, or start an automator.
- **Wipe on exit.** `endPlaybackSession()` (called from `onDisappear`, alongside the
  existing engine stop + Now Playing teardown) explicitly resets the transient knobs
  — `activeLoopID`, `speed`, `metronomeOn`, `mode`. Persisted song data is never
  touched. This is belt-and-suspenders given per-entry recreation, but it makes the
  contract explicit and survives future model reuse.
- **Deleting the active loop clears to `nil`** rather than auto-jumping to the first
  remaining loop. Same principle: don't silently arm a region the user didn't pick —
  playback continues through the song. Undo still restores the deleted loop *and* its
  active state if it was active.

## Alternatives considered

- **Keep auto-arming the first loop on entry.** Rejected — it surprises: the first
  play loops instead of playing through, and "the first loop" is an arbitrary pick.
- **Rely solely on model deallocation for wipe-on-exit.** Rejected as the *only*
  mechanism — it works today but encodes nothing; an explicit reset documents intent
  and is robust to caching the model later. Kept deallocation as the backstop.
- **Persist the last active loop / speed per song.** Rejected — a practice sitting is
  meant to start fresh; resuming a stale loop/speed is more confusing than helpful.

## Consequences

- Opening any song lands on full-song playback at 1.0×, no loop highlighted, no loop
  chip in the transport. Loops are armed by intent.
- `wipeTransientState()` centralises the exit reset; the per-entry `init` no longer
  seeds `activeLoopID`.
- Deleting the loop you're hearing plays through instead of hopping to another region.
