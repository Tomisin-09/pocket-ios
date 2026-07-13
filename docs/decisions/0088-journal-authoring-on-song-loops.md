# 0088 — Journal authoring returns to the loop edit sheet

- **Status:** Accepted (2026-07-13)
- **Date:** 2026-07-13
- **Reverses (in part):** ADR 0058 — which moved journal *writing* off the waveform screen so the loop
  edit sheet was history-only (`readOnly`).
- **Builds on:** ADR 0038 (the journal + immutable per-entry snapshot), ADR 0067 (the journal row moved
  into the loop edit sheet's settings).

## Context

ADR 0058 made the journal authorable **only** from the Practice run screens; the waveform loop edit
sheet showed a read-only "View entries" row. In practice that means a song loop can't be journalled
without launching a full run — but the loop edit sheet is exactly where a player sits reviewing a loop,
and journaling a song loop there is the natural moment. The 2026-07-13 review asked to bring journaling
back to song loops via the loop edit sheet.

The write path already exists and is owner-generic: `JournalWriter.add/update/delete` (ADR 0058) and the
`JournalSheet` composer, which the run screens use. `JournalSheet` even still carried a `readOnly` flag
whose *only* caller was the waveform screen.

## Decision

- **J1 — The loop edit sheet's journal is authorable.** It now presents `JournalSheet` in its normal
  authoring mode, wiring `onAdd` / `onUpdate` / `onDelete` to the shared `JournalWriter` (same path as
  `LoopRunView`), each entry snapshotting the loop's mastery + command tempo at write time and saved
  immediately (independent of the sheet's Cancel/Done, which govern the loop's *fields*).
- **J2 — The row reads "Journal", keeping the tally.** "View entries" becomes **Journal**; the trailing
  value keeps the ADR-0039 absence signal — **None** until there are entries, then the count.
- **J3 — Retire the `readOnly` mode.** With no remaining read-only caller, `JournalSheet.readOnly` and its
  branches (the hidden composer, plain non-pushable rows, the "write from the run screen" empty message)
  are removed. `JournalSheet` is authoring-only again.

## Consequences

- A loop's journal is now writable from **two** surfaces (the run screen and the loop edit sheet), both
  through the one `JournalWriter`, so snapshots stay consistent. The exercise journal is unchanged
  (still run-screen-authored; `ExerciseDetailSheet` never showed a journal row).
- The immutable-snapshot rule (ADR 0038) is untouched — entries added here snapshot exactly as the run
  screen's do.
