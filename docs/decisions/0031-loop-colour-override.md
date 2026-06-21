# 0031 — Loop colour override (manual identity colour)

**Status:** Accepted
**Date:** 2026-06-21
**Amends:** ADR 0023 (loop colour encodes identity, derived by start-order).

## Context

ADR 0023 made each loop's colour a **derived** identity hue: a deterministic
`PocketColor.loopPalette` slot by start-order (pure `LoopColors.slot`). Nothing
was stored on the loop. With the active-loop colour strip now in the transport bar
(ADR 0030), the colour is more prominent, and a user wanted to **choose** a loop's
colour rather than accept the auto assignment.

## Decision

Add an **opt-in manual override** while keeping derived colour the default.

- **Model** — `Loop.colorIndex: Int?` (a `PocketColor.loopPalette` index) and
  `Loop.customColorHex: String?` (a free `#RRGGBB` colour from the wheel). Both
  optional, so SwiftData lightweight migration leaves existing loops as `nil` (no
  migration code, no CoreData 134110 risk). Precedence: **custom → palette → derived**.
- **Resolver** — a pure `LoopColors.resolvedSlot(override:for:among:paletteCount:)`:
  a valid override wins, else the derived `slot`. An out-of-range or `nil` override
  falls back to derived, so a stale index (e.g. if the palette ever shrinks) can't
  crash or blank a loop. `LoopColor.color(for:among:)` routes through it, so the
  waveform, minimap, and transport strip all honour the override from one place.
  `LoopColor.derivedColor` exposes the auto hue (ignoring override) for the picker's
  "Auto" swatch.
- **UI** — a **Colour** section in the loop edit sheet (ADR 0028's hold-to-open
  settings): an "Auto" swatch (the derived hue, marked "A"), the six palette swatches,
  and a trailing **custom** gateway — a rainbow-ringed system `ColorPicker` (wheel) for
  any other colour. The selection (`LoopColorChoice`: auto / palette / custom) is
  written to `colorIndex` / `customColorHex` on Done.
- **Contrast** — the system wheel can't be restricted, so a free colour that's
  low-contrast on the near-black background shows an advisory **warning** (it's still
  allowed — user intent wins). Legibility is the pure, unit-tested
  `ColorContrast.isLegible` (WCAG, 3:1 for graphical elements); `HexColor` bridges
  `Color` ⇄ `#RRGGBB` and extracts components so the model and the contrast math stay
  colour-type-free.

## Consequences

- Loops keep auto, all-distinct colours until a user deliberately overrides one; an
  override also **pins** that loop's colour so it no longer shifts as loops are added
  or removed before it (a side benefit over pure start-order).
- **Collisions are allowed:** a manual choice can match another loop's auto (or manual)
  colour. Manual intent wins; we don't re-shuffle others to stay distinct. Overlap is
  still disambiguated by lane position on the waveform (ADR 0023), so same-colour loops
  remain readable.
- The pure resolver is unit-tested (`LoopColorsTests`) alongside the existing slot
  logic; the override path needs no model container to test.
