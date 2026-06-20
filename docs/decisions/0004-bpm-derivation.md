# 0004 — BPM is best-effort and user-correctable; speed never depends on it

- **Status:** Accepted
- **Date:** 2026-06-15

## Context

The speed bar shows a BPM readout (`round(songBPM × speed)`) and the future
metronome and tempo automator need a tempo. The original plan was to derive BPM
from the song. But Pocket's audio is DRM-free local/iCloud files (ADR 0001), and
tempo is not reliably available:

- **Metadata** — some files carry a BPM tag; many personal/ripped files don't.
- **On-device analysis** — beat/tempo detection is possible but an *estimate*:
  it struggles with rubato/ambient material and frequently lands on half- or
  double-tempo. It cannot be treated as ground truth.

So "no known BPM" is a normal state, not an error — and the original "derive it"
plan needs an explicit fallback.

## Decision

- **Speed is decoupled from BPM.** The `×` multiplier is a playback-rate change
  and never requires a tempo. BPM is a display convenience (and a feeder for the
  metronome/automator). A song with no BPM is fully usable for looping and speed
  practice.
- **Tempo is populated by a fallback chain, with provenance:**
  1. read from file **metadata** if present;
  2. else optionally **estimate** on-device, flagged as estimated;
  3. always allow the user to **set or correct** it (tap-tempo or manual entry).
- **"Unknown" is a first-class UI state.** When there is no BPM, the speed bar
  shows a tappable **"Set BPM"** affordance instead of a number; the `×` keeps
  working.
- BPM is stored as a **user-correctable** value attached to the song's practice
  data, so an estimate can be confirmed or overridden and persisted.

## Consequences

- `Song.bpm` is **optional**; the derived display is `Int?` (nil → "Set BPM").
- The tap-tempo / manual-entry flow behind "Set BPM" is a follow-up; this change
  ships the affordance only. (Rung 3 shipped in **ADR 0024** — tap-tempo, manual
  entry, and a peak-snapped downbeat, with tempo stored at full precision.)
- Any estimated BPM must be presented as estimated and be easy to correct
  (estimates are often half/double off).
- The metronome and tempo automator must handle a nil/uncertain BPM gracefully.

## Alternatives considered

- **Require a BPM per song** — rejected: blocks every file without tempo
  metadata and breaks the local-first model.
- **Trust on-device analysis as truth** — rejected: half/double-tempo and
  rubato errors would mislabel songs; estimates must be user-confirmable.
