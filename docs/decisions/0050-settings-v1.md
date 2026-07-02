# 0050 — Settings V1 (a thin preferences shell)

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

User testing asked for "a settings toggle — a V1." Several other notes are
toggle-shaped (haptics, count-in, later a gridlines control), but there was no
home for a preference: the app had no settings surface at all. Building one small,
honest shell now unblocks the toggle-shaped work without over-committing to a
sprawling settings screen before we know what belongs in it.

Two constraints shaped it:

- **No new infrastructure.** Preferences already persist via `@AppStorage`
  (`LibraryView`'s grouping/sort), and the privacy manifest already declares
  UserDefaults (CA92.1). A settings screen needs no new model, migration, or
  required-reason API.
- **Some settings are read outside SwiftUI.** The count-in fires in the audio
  engine and haptics in a free function — neither can lean on `@AppStorage`
  (a view property wrapper). They need to read the same value from plain code.

## Decision

A minimal, pushed settings screen backed by a shared thin wrapper.

- **`AppSettings`** — a `UserDefaults` wrapper exposing each preference by a stable
  key. SwiftUI binds with `@AppStorage(AppSettings.Key.…)`; engine/helper code reads
  `AppSettings.hapticsEnabled` / `.countInEnabled`. Both hit the same key, no shared
  object. Reads route through a pure `resolvedBool(storedValue:default:)` so a
  never-set key takes its **default (on)**, not `UserDefaults.bool`'s `false`. That
  rule is unit-tested (`AppSettingsTests`) — a regression there would silently switch
  an opt-out feature off.
- **`SettingsView`** — a `Form` pushed from a `gearshape` in the Home toolbar (a
  push, not a sheet, so it can grow sub-screens), grouped into **Feel / Practice /
  About** so the skeleton reads as deliberate structure even while small. V1 carries:
  - **Haptics** (default on) — gates the `haptic(_:)` helper.
  - **Count-in** (default on) — `startAutomatorRun` counts in only when set; off
    engages the climb immediately — with a configurable **length** (`countInBars`,
    1–2 bars, clamped) shown only while count-in is on.
  - **Keep screen awake** (default on) — a `keepAwakeDuringPractice()` view modifier
    on the practice/metronome/run surfaces drives `isIdleTimerDisabled`, reading the
    setting via `@AppStorage` (live) and always restoring the idle timer on disappear
    so it never leaks past those screens. Default on because you play along hands-free.
  - **About** — the app version.
- **Scope discipline.** Feature-specific controls do **not** live here. The
  **gridlines** toggle in particular is a *contextual* control on the practice
  screen, shown only once the grid is drawable (tempo + downbeat set, i.e. the beat
  grid is non-empty) — a global toggle would be dead on a song with no tempo. It
  rides the later bar-lines/song-time-signature slice, not this shell.

## Consequences

- A real settings home exists with two settings that take effect immediately, at
  zero persistence/migration/manifest cost.
- New preferences are cheap: add a key + a `Form` row, and read it from anywhere via
  `AppSettings`. The default-resolution rule keeps opt-out settings honest.
- Because settings read from `UserDefaults` at call time (not injected), they're not
  reactive in non-SwiftUI readers — fine here (count-in is read at run start, haptics
  per fire), but a future setting that must update live mid-use would need observation.
- Keeping feature controls off this screen holds the line against a settings screen
  that accretes every toggle; contextual controls stay next to what they affect.
