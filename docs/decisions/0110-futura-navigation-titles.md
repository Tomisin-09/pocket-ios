# 0110 — Futura navigation-bar titles via a global appearance proxy

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-181-futura-nav-titles`)
- **Builds on:** ADR 0061 (Futura as the brand UI face; all text routes through `Font.futura`).

## Context

Pocket's type system is Futura everywhere (ADR 0061) — except SwiftUI's `.navigationTitle`, which
renders in **San Francisco**. SwiftUI exposes no native hook to swap the navigation-title font, so the
inline and large titles across ~45 screens have quietly stayed system-font, drifting from the brand.
Spotted on the exercise run screen ("A Minor Pentatonic") during the v1 screenshot shoot, but it is
systemic, not one screen.

Only two screens already dodge it by hand-rolling a `.principal` toolbar item in Futura: Home's wordmark
and `MetronomeView`'s header. Everything else shows an SF title.

## Decision

**One global `UINavigationBarAppearance`, installed once at launch** — a new
`Pocket/UI/NavigationBarStyle.swift` called from
`AppDelegate.application(_:didFinishLaunchingWithOptions:)`.

- Override **`titleTextAttributes`** *and* **`largeTitleTextAttributes`** to **Futura-Bold** at the
  `.headline` (17) / `.largeTitle` (34) anchor sizes, `UIFontMetrics`-scaled so Dynamic Type still
  grows them, in `UIColor(named: "Ink")` (= `PocketColor.textPrimary`). Fonts resolve as `"Futura-Bold"`,
  matching `Font.futura` / `DesignTokens`.
- **Preserve the current look otherwise.** Keep the system default material on
  `standardAppearance`/`compactAppearance` (the bar shown when content scrolls under it) and a
  **transparent** `scrollEdgeAppearance`/`compactScrollEdgeAppearance` (the flat bar at rest). Only the
  title *text font* changes.
- The two `.principal` screens set their own centre view, so they are untouched.

### Why global, not per-screen

The app sets **zero** per-screen toolbar-background customisation (no `.toolbarBackground` anywhere;
only `WaveformPracticeView` hides its bar), so there is nothing for the proxy to clash with. Editing
~45 call sites would churn and drift; the proxy also catches every *future* screen for free.

## Consequences

- Every navigation title — inline and large — renders in Futura-Bold, app-wide, with no per-screen
  edits. The change is pure appearance (font only); backgrounds, tint, and layout are unchanged.
- **Reversibility (a requirement of this decision):** the whole feature is one file plus one call site.
  Delete both to revert. Large titles are gated on a single line (`largeTitleTextAttributes`) so they can
  be dropped alone if they read wrong at 34pt.
- Not previewable in isolation — the proxy is installed by the app delegate, so it shows only in a real
  app run (device/simulator), not in a SwiftUI `#Preview`.

## Alternatives considered

- **Per-screen `.principal` Futura modifier** mirroring `MetronomeView` (a `.toolbar` item that centres a
  `Text(.font(.futura(...)))`). Safe and background-risk-free, but ~40 edit sites, misses future screens,
  and can't style large titles. Kept only as the fallback if the proxy ever misbehaves.
- **Leave titles in SF.** Rejected — it's the one visible hole in an otherwise all-Futura app and reads
  as an oversight next to the wordmark.
