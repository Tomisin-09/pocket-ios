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
    setting via `@AppStorage` (live) and releasing on disappear so it never leaks past
    those screens. Default on because you play along hands-free.
    **Amended 2026-08-06 — the modifier releases a *claim*, it does not clear the
    flag; see the amendment at the end of this ADR.**
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

## Amendment — keep-awake is a lease, not a flag (2026-08-06)

**The screen slept during a routine with the setting on.** Found on the device pass
that closed the Slice 6 follow-up.

`UIApplication.isIdleTimerDisabled` is a single process-wide slot with no notion of who
asked for it, and the original modifier wrote it directly from `onAppear`/`onDisappear`.
That works for exactly one practice surface at a time. A routine is never that: the
player swaps a fresh run screen in per block, so at every block change two practice
surfaces exist at once, and the outgoing screen's `onDisappear` re-enabled the idle
timer the incoming screen's `onAppear` had just disabled. SwiftUI does not promise which
of the two runs first, which is the difference between "usually fine" and "correct".

Two defects, and the second is the one that made it reproducible rather than flaky:

1. **Last writer wins on a global flag.** Any overlap between two practice surfaces
   could clear the hold, with nothing to show for it — the Settings toggle still read
   "on", so the symptom looked like the setting being ignored.
2. **Five practice surfaces never asked at all.** `FreeformRunView`, `EarLoopRunView`,
   `ImproviseLoopRunView` and the standalone ear/improvise hosts had no modifier, and
   neither did `RoutineBlockDoneView`. So a routine advancing from an exercise block to
   an ear, improvise or freeform block *deterministically* went to sleep: the outgoing
   screen cleared the flag and nothing set it back. `restView` carried a comment
   asserting "the block run screens have it", which was true when only exercise and loop
   blocks existed and quietly stopped being true as ramp-less block kinds were added.

**The fix is the lease this codebase already uses for the audio session.**
`KeepAwakeLease` reference-counts holders and derives the flag from
`shouldDisableIdleTimer(holders:settingOn:)` — two independent conditions, since a
surface must not override the player's setting and the setting alone must not keep a
phone awake on the Home screen. `KeepAwakeClaim` is idempotent in both directions
(SwiftUI re-fires `onAppear`), and `release()` is floored at zero so an unbalanced
release can't drive the count negative and defeat every later claim.

**`RoutinePlayerView` now claims for the whole session**, not only through whichever
block is on screen. The host outlives every block, so the claim spans the gap a block
change opens — and with a count, a block claiming as well is free. That makes the
routine case correct *structurally*, rather than by every block kind remembering to opt
in, which is the thing that already failed once.

**The general rule this is an instance of:** global device state must not be driven from
a per-screen `onDisappear`. The same shape lives in `OrientationGate` (ADR 0042), which
is safe today only because exactly one screen opts into landscape — it would break the
same way the moment a second one did.
