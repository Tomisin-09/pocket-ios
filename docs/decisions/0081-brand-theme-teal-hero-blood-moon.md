# 0081 — Brand-led home theme (teal hero · plum · terracotta) + Blood Moon theme

- **Status:** Accepted (Slice 1 built); Blood Moon theme (Slice 2) planned
- **Date:** 2026-07-11
- **Amends:** [ADR 0023](0023-blue-theme-bordered-loop-identity.md) (retires the
  song-surface **blue**), [ADR 0062](0062-light-dark-appearance.md) /
  [ADR 0063](0063-brand-hue-saturation.md) (the teal was the *metronome* hue; it
  now leads via Practice)

## Context

Design review of the home screen (2026-07-11): the app is practice-focused, so
the **plum** Practice accent "took over" — it wore the one filled CTA
("Start today's session") *and* the Practice strip, making purple the dominant
colour even though it was never the brand hue. The brand hue is the **teal** that
the wordmark was retuned to in ADR 0062/0063; it was sitting on the *metronome*,
a secondary tool.

The fix the user landed on: lead with the brand. Put teal on the most-used
surface (Practice), give the other two home features complementary hues that stay
distinct, and let the brand shine through. Separately, the app is called **Red
Moon** — a warm terracotta (`#C24A2C`) is teal's complement *and* on the "moon"
narrative, so it becomes the second selectable theme's hero.

## Decision

### The home triad is re-hued (default theme)

Colour is still keyed to feature identity; only the hue assignments change:

| Feature | Was | **Now** |
|---|---|---|
| **Practice** (brand hero, + "Start today's session" CTA) | plum | **teal** |
| **Metronome** (theme-invariant tool) | teal | **plum** |
| **Song Library** (songs) | blue | **terracotta `#C24A2C`** |

- **`mastery` tracks the brand hero** (`= practice`), so it is teal by default and
  never the metronome plum — "mastered" reads as an on-brand positive state.
- The ADR 0023 song **blue** is retired from the home triad (its colour sets are
  removed). The `loopPalette` blue is unaffected.
- Asset colour sets are renamed from feature names to **hue names** (`Teal*`,
  `Plum*`, `Terracotta*`), each a full set (base + `CardWash` + `CircleWash` +
  `CTA`) with independently baked light+dark values (the ADR 0062 lesson: a
  low-opacity blend reads washed-grey on cream and near-invisible on near-black).
  `PocketColor`'s feature tokens now map role → hue, which is the seam the theme
  switch (below) plugs into.

### Two selectable themes (Slice 2, planned)

A theme is a **feature → hue mapping in code, not a second set of baked
palettes**, so it does not multiply asset-catalog work — the three hues keep their
single light+dark pairs.

| Role | **Default** | **Blood Moon** |
|---|---|---|
| Practice (hero + CTA) | teal | **terracotta** |
| Song Library | terracotta | teal |
| Metronome | plum | plum |
| Mastery (tracks hero) | teal | terracotta |

Because Practice owns the dominant filled CTA, Blood Moon makes **terracotta the
main colour of the home screen**. Blood Moon also re-tints the **wordmark** and
**Settings logo** terracotta (the wordmark tints cleanly as a template; the
textured moon logo needs a terracotta art variant — open). The theme picker lives
in Settings beside Appearance, orthogonal to light/dark.

### Also in Slice 1

- The Home **add-song** button lost its pale edge: on iOS 26 the nav bar wraps bar
  items in a shared glass background. `.sharedBackgroundVisibility(.hidden)` on the
  `ToolbarItem` (gated `#available(iOS 26.0, *)`; pre-26 has no such glass) drops
  it, so the solid green disc reads flush.
- The practice screen's whole speed-bar cockpit stays **teal** via a new
  `waveformAccent` token (tied to the theme-invariant waveform bars), so the song's
  tempo reads as the song, not the metronome: the **speed slider**, **"Set BPM"**, and
  the **in-song metronome-click toggle** all draw it. Only the home Metronome card and
  the standalone metronome screen keep the plum `metronome`. Without this they'd all
  have followed the metronome hue to plum.

## Consequences

- Every Practice call site (~120) reskins from the single `practice` token, so the
  Blood Moon swap in Slice 2 is a one-token change per role — no per-site edits.
- `#C24A2C` sits near `danger` (red) and the reserved `marker` (orange) on the
  wheel. It is only ever a passive **identity wash / accent**, never an action
  colour (delete-red appears solely as a glyph in the loop toolbar), so the
  proximity is acceptable. Revisit if terracotta ever gains an action role.
- Slice 2 introduces the theme abstraction, the Settings picker, and the terracotta
  wordmark/logo. Until then the default (teal-led) theme is the only one shipped.
