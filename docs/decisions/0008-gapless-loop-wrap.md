# 0008 — Seamless looping via a crossfaded `.loops` buffer

- **Status:** Accepted
- **Date:** 2026-06-16
- **Supersedes:** the "wrap is **not gapless**" consequence of ADR 0006 (the rest
  of 0006 — continuous looping, exit chip, `activeLoopID` as source of truth —
  stands).

## Context

ADR 0006 looped a region by **stop → seek → reschedule** in the segment-completion
handler, which left a few milliseconds of silence at the wrap. The first fix on
this branch made the wrap *gapless* by scheduling file segments back-to-back
(schedule-ahead). On-device that removed the silence but exposed two further
problems:

1. **A sharp click at every wrap.** Splicing two segments end-to-start is
   sample-*adjacent* but not sample-*continuous*: the value at the loop end rarely
   matches the value at the start, and that instantaneous step is an audible click
   (the "unplug the amp cable" pop). Scheduling can't fix it — consecutive segments
   are spliced, not blended.
2. **The old loop bleeding over a live edit.** Changing the loop region while two
   old-bounds segments were still queued (depth-2) meant you briefly heard both
   regions during a Fine range edit.

## Decision

Stop splicing file segments for loops. Instead **pre-render the loop region into a
PCM buffer, crossfade its seam, and play it with `AVAudioPlayerNode.scheduleBuffer(…,
options: [.loops, .interrupts])`.**

- **Crossfaded buffer (`makeLoopBuffer`).** Read the loop region (`R` frames, from
  `AudioMath.loopSegment`) into an `AVAudioPCMBuffer`. Fold the last `F` frames
  (`F` ≈ 15 ms, clamped to `R/2`) into the first `F` with **equal-power** gains
  (`AudioMath.crossfadeGains`, pure + unit-tested), and loop only `M = R − F` frames.
  The wrap (`buffer[M-1] → buffer[0]`) is then between two *originally adjacent*
  samples, and the head smoothly continues the tail over the fade — sample-continuous,
  no click.
- **`.loops` does the looping in the render thread** — inherently gapless, no
  completion/refill bookkeeping. The depth-2 segment-refill machinery is removed for
  the loop case.
- **`.interrupts` replaces cleanly.** Changing the loop (activate, edit, discard)
  rebuilds the buffer and swaps it in immediately, interrupting the old one — so only
  one loop is ever audible. This fixes the edit-time overlap.
- **Straight-through play is unchanged** — `scheduleSegment(seek → end)` with the
  `.dataPlayedBack` stop handler; `generation` still invalidates its completion across
  seek/stop/loop-change.
- **Playhead.** `AudioMath.loopedPlayhead` maps the continuously-growing player time
  back into the region, using the **looped length `M`** (region − crossfade) and a
  per-buffer `loopBaseSampleTime` anchor, so the visual playhead wraps in lockstep
  with the audio.

## Consequences

- The wrap is gapless **and** click-free; live loop edits audition the new region
  alone (the Fine preview commits on handle-release, rebuilding + interrupting).
- Verifying it is an **on-device listen** — both gaplessness and the absence of a
  click are audible, not visible; unit tests cover the gain/playhead math only.
- A loop change does a short file read + buffer build on the main actor. Fine for the
  dev source and typical loops; very long loops with real files may warrant a
  background read later.
- Seeking *into* an active loop restarts it from the loop start (the buffer begins at
  the loop start) — an acceptable simplification vs. mid-region resume.

## Alternatives considered

- **Schedule-ahead file segments (the first cut on this branch)** — gapless but
  can't crossfade (segments don't overlap), so the seam clicks. Replaced.
- **`scheduleBuffer(.loops)` without a crossfade** — gapless but still clicks at the
  seam. The crossfade is the point.
- **An OSS audio framework (e.g. AudioKit)** — would provide looping + fades but is a
  heavy dependency that partly duplicates this engine; a native equal-power crossfade
  is a few lines over AVFoundation. Rejected. (SoundTouch / Rubber Band are
  time-stretch, already covered by `AVAudioUnitTimePitch`.)
- **Zero-crossing snap of loop points** — cheaper but imperfect (zero crossings don't
  guarantee matching slope); a crossfade is robust for arbitrary material.
