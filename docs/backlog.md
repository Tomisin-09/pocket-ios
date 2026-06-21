# Backlog

Deferred work that's intentionally parked — known, but not scheduled. Each item
notes enough context to pick it up cold. Promote to a branch (and an ADR if it
closes off an alternative) when it's time to act.

## UI / polish

- **Fine-tune the song details sheet.** `SongDetailsSheet` (opened by holding the
  song title on the practice screen) currently stands up the read-first overview on
  a plain SwiftUI `Form`. It works, but the presentation is a first pass. Candidate
  refinements:
  - Richer header treatment (artwork? larger title, tighter artist/album/year line).
  - A more bespoke descriptive layout than a stock grouped `Form` — spacing,
    grouping, and typography tuned to the app's design tokens (brief §3).
  - Decide the relationship with the scroll-area `SongInfoPanel`, which shows an
    overlapping subset (key · proficiency · progression · collections) — consolidate
    or differentiate so the two don't drift.
  - Consider inline editing vs. the current Edit → `SongEditSheet` hop.
  - Surface tempo precision / downbeat state if useful (currently shows rounded BPM).
