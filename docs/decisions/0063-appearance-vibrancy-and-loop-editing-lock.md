# 0063 — Appearance override, vibrancy retunes, and locking loop-range editing

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

ADR 0062 shipped paired light/dark tokens and a brand-consistent Metronome/Practice
retune, verified by WCAG contrast math. Living with it on-device across both
appearances surfaced four more problems the math didn't catch, plus one deferred
item ADR 0062 explicitly left open:

1. **The wash/CTA/gridline tokens were still too dark in Dark Mode.** The
   Metronome/Practice card + circle washes on Home, and the "Add a song" green
   wash, were baked (ADR 0062 follow-up, undocumented at the time) as
   `metronome`/`practice`/`active` at 10–15% opacity. That recipe fixed Light
   Mode but never actually fixed Dark Mode — blending a colour at low opacity
   toward `#040404` multiplies it *down* almost to black, so the "same" fix that
   reads as a soft pastel on cream reads as near-invisible on near-black. The
   same asymmetry hit the loop-identity lane lines on the waveform/minimap
   (opacity 0.55 for inactive loops) and the beat-grid downbeat lines. On
   device, in Dark Mode, all of these read as "the app looks muted" — not a
   Light Mode regression, a Dark Mode one that the original contrast pass
   didn't measure because Dark "already worked" before ADR 0062 (see
   Consequences).
2. **The Metronome/Practice identity hues themselves were too dusty**, on
   *both* appearances, once actually lived with day to day — `#799BA9`/
   `#486B79` and `#8D7EA6`/`#705D8F` sit at only ~20–25% saturation. This is
   independent of (1): it's not a blending bug, the source colour is just
   under-saturated for how much visual weight these tokens carry (feature-card
   icons, the tempo slider, every waveform bar).
3. **The loop-identity palette (ADR 0023, light twins added in ADR 0062) was
   brand-muted when it should be maximally distinguishable.** A loop's colour
   exists purely so you can tell loops apart at a glance — it has no reason to
   sit in the brand's register, and doing so produced two light-mode swatches
   (`LoopAmber`, `LoopGold`) that read as an indistinguishable muddy
   brown/olive once deepened for on-cream contrast.
4. **A saved loop's edge was directly draggable on the waveform** (ADR 0041):
   touching within its grab tolerance would lift it into an A/B span and let
   you resize it, with no confirmation step. This is too easy to trigger by
   accident, and it duplicates the edit sheet's explicit **"Adjust range on
   waveform"** action, which exists precisely to make range-editing a
   deliberate step.
5. ADR 0062 deferred an in-app Appearance override ("can be added to Settings
   later if wanted"). Living with system-only switching made it clear it's
   also a testing tool, not just a preference — worth pulling forward.

## Decision

### Appearance override (closes ADR 0062's deferred item)

Added `AppearancePreference` (`.system` / `.light` / `.dark`, `RawRepresentable`
so it works directly with `@AppStorage`) and a segmented control at the top of
Settings. Applied once, at the `PocketApp` root, via
`.preferredColorScheme(appearance.colorScheme)` (`nil` for `.system`) — no other
view touches `colorScheme` directly. Default `.system`, so nothing changes for
anyone who doesn't open the control.

### Wash/CTA/gridline/lane-line tokens: baked flat per appearance, not shared opacity

`MetronomeCardWash`, `MetronomeCircleWash`, `PracticeCardWash`,
`PracticeCircleWash`, and `ConfirmWash` all got new, independently-chosen dark
values with real luminance separation from `#040404` (e.g.
`MetronomeCardWash` dark: `#101315` → `#153A44`), while keeping the icon glyph
drawn on top at ≥3:1 contrast. The Canvas-drawn loop lane lines (waveform +
minimap) moved their "inactive loop" opacity from 0.55 → 0.8 for the same
reason — a `Canvas` opacity blend has the identical asymmetry as an
Asset-Catalog-color-at-opacity, it just isn't a named token. This is the same
root cause as ADR 0062's original Light Mode bug, just discovered in the
opposite direction: **a shared-opacity recipe only transfers symmetrically at
very low opacities; anything designed to visibly tint one appearance needs an
independently baked value for the other, not a shared multiplier.**

### Metronome/Practice/waveform-bar saturation boost

`Metronome`, `Practice`, and `WaveformBarBase` (which mirrors `Metronome`) were
re-picked at ~50% saturation instead of ~20–25%, same hue, adjusted lightness
per appearance so contrast against `background` stays ≥4.5:1:

| Token | Old dark | New dark | Old light | New light |
|---|---|---|---|---|
| `metronome` / `waveformBar` | `#799BA9` (S 22%) | `#60A8C7` (S 48%) | `#486B79` (S 25%) | `#2B6982` (S 50%) |
| `practice` | `#8D7EA6` (S 18%) | `#9272CA` (S 45%) | `#705D8F` (S 21%) | `#603B9B` (S 45%) |

`MetronomeCTA`/`PracticeCTA` (already boosted in the undocumented wash
follow-up, S 50–71%) were left as-is — they were already at the target
vibrancy level, just not shared with the base identity tokens.

**Consequence worth naming:** the Metronome accent no longer matches the
brand-mark artwork's literal hex (`#799BA9`/`#486B79`, still baked into the app
icon and the About-screen logo PNGs) — ADR 0062 called that match "a
deliberate, singular exception." It's now a looser family match (same hue, more
saturated) rather than a pixel match. Accepted: the static brand mark is meant
to be a quieter, more dignified mark; the *interactive* accent needs to carry
its own visual weight across a whole tappable card, slider, and every waveform
bar, which the brand-mark's dustier value couldn't do.

### Loop-identity palette: vivid, non-brand hues

Replaced `LoopAmber`/`LoopGold`/`LoopCoral`/`LoopMagenta`/`LoopViolet`/`LoopTeal`
with `LoopRed`/`LoopOrange`/`LoopGold`/`LoopMagenta`/`LoopViolet`/`LoopBlue` —
plain, maximally-distinguishable, saturated hues (loosely a Tailwind-scale
picks), each independently tuned per appearance so none collapse to a muddy
mid-tone when deepened for light-mode contrast:

| Token | Dark | Light |
|---|---|---|
| `LoopRed` | `#F87171` | `#DC2626` |
| `LoopOrange` | `#FB923C` | `#C2410C` |
| `LoopGold` | `#FBBF24` | `#B45309` |
| `LoopMagenta` | `#F472B6` | `#BE185D` |
| `LoopViolet` | `#A78BFA` | `#6D28D9` |
| `LoopBlue` | `#60A5FA` | `#1D4ED8` |

`LoopTeal` was retired (not just retuned) because the waveform-bar/metronome
recolour above now occupies that exact hue family — a teal loop would read as
chrome, not identity. Replaced with `LoopBlue`, which was safe to introduce
because the waveform bars moved off true blue to teal back in the ADR 0062
follow-up.

### Loop-range editing: locked to the edit sheet's explicit action

Removed `WaveformCanvasGestures`' `pickLoopEdge` and the `onLiftLoopEdge`
plumbing — touching near a **saved** loop's edge on the waveform no longer
grabs it (an **A/B span's own** edges, once one is live, are still directly
draggable — that's a different, already-deliberate action, ADR 0041). The only
way to resize a saved loop is still the edit sheet's **"Adjust range on
waveform"** button (`WaveformPracticeModel.startRangeEdit`, unchanged) — this
removes an accidental *second* path to the same effect, it doesn't remove the
capability.

The grabbable-knob visual on the active loop's edges (which implied the
now-removed interaction) was replaced with a bold static vertical line at the
active loop's start/end, drawn across the bar region — a boundary marker, not a
grab target (no knob shape, no drag affordance). A first attempt drew bracket
ticks on the *lane line* underneath the waveform instead; on review that read
as visual noise on an indicator that already worked, so it was reverted — the
boundary line lives only in the bar region where the old knobs used to be.

### Brand-mark transparency

`RedMoonLogo`'s light/dark PNGs (Settings → About) were flat compositions on a
solid card-coloured rectangle, close to but not exactly `PocketColor.background`
(`#0F0F0F` vs `#040404`; `#EDE0D8` vs `#F0E3D8`) — close enough to look
intentional at a glance but producing a faint rectangular seam. Both PNGs were
re-processed (colour-distance keying, protecting pixels near the artwork's own
light-blue/cream fill from an over-eager flood-fill so the moon's fine
crater/vein linework survived) to a transparent background, so the artwork now
sits directly on the live `PocketColor.background` with no seam in either
appearance, and stays correct even if the two colours ever drift further apart.

## Alternatives considered

- **Derive washes/CTAs/loop-palette programmatically from a base hue** (e.g. a
  `Theme.wash(from:appearance:)` function) instead of hand-baking each value.
  Not done here — every token in this ADR was still hand-tuned via one-off
  contrast checks, same as ADR 0062. Flagged as the real prerequisite before
  "swap the whole palette for a special edition" becomes cheap; out of scope
  for this pass, which was about fixing what shipped, not building a theme
  engine.
- **Keep the loop palette in the brand's muted register, just fix the
  contrast.** Rejected — the brand register is inherently low-saturation,
  which is exactly wrong for a role whose only job is "look different from
  its neighbours."
- **Dilate-then-flood-fill the logo's whole background uniformly.** Tried
  first; failed — the moon's decorative linework is topologically connected to
  the outer background at the crescent's silhouette by design (thin dark
  strokes crossing the edge), so a pure connectivity-based key erased chunks of
  the artwork itself. Fixed by protecting any pixel near a clearly-foreground
  (non-background-coloured) pixel, dilated by a margin, regardless of its own
  colour.

## Consequences

- Dark Mode was implicitly treated as "the one that already works" throughout
  ADR 0062 (it was the only shipped appearance before that ADR). This pass is
  the reminder that a blending-based fix must be re-verified in *both*
  directions, not assumed correct in the direction that was previously
  default.
- The Metronome/Practice/waveform-bar tokens and the brand-mark artwork have
  now diverged in exact hex (same hue family, different saturation) — future
  brand-mark refreshes should decide deliberately whether to chase the UI
  accent's new saturation or keep the mark quieter; don't assume they're still
  meant to match pixel-for-pixel.
- `PocketColor.loopPalette`'s asset names changed (`LoopAmber`→`LoopOrange`,
  `LoopCoral`→`LoopRed`, `LoopTeal`→`LoopBlue`); no migration needed since
  loops store a palette *index*, not a colour name.
