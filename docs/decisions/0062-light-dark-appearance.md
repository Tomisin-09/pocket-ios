# 0062 — Light + dark appearance, and a brand-consistent accent retune

- **Status:** Accepted
- **Date:** 2026-07-03

## Context

ADR 0023 made Pocket dark-first and hardcoded every surface to a near-black
(`#0F0F0F`). With the "Red Moon" brand mark now shipping **two** logo backgrounds
— cream (`#F0E3D8`) and near-black (`#040404`), ADR 0061 — a light appearance
became plausible for the first time, and the brand review surfaced two more
problems worth fixing at the same time:

1. Two of the app's functional accents — the Metronome's cyan (`#35C8C8`) and
   Practice's indigo (`#8B7CF6`) — are generic, saturated hues that clash tonally
   with the brand's muted, desaturated teal (`#799BA9`). Sitting a vivid indigo
   card next to a muted-teal one reads as two different apps.
2. Nothing in the codebase actually responded to the system Light/Dark setting:
   `PocketColor` was all hardcoded hex/opacity literals, and five **production**
   views (`HomeView`, `NewExerciseSheet`, `WaveformPracticeView`, a
   `WaveformSections` popover, `MetronomeView`) additionally forced
   `.preferredColorScheme(.dark)`, so the app stayed dark even with the phone set
   to Light Mode.

Naively reusing the same hex values on a light background doesn't work: measured
against real WCAG contrast, colours tuned to glow on near-black collapse to
2–3:1 against cream (`#799BA9` alone drops from 6.46:1 on black to 2.36:1 on
cream) — well under even the 3:1 UI-component threshold. The same is true of
plain white text (1.26:1 on cream) and every opacity-based neutral fill, since
`white.opacity(x)` inverts direction on a light surface instead of just working.

## Decision

Ship a **paired light/dark token table** — every semantic role gets two values,
not one reused — plus two accent retunes, chosen deliberately to sit in the
brand's muted register rather than as generic UI-kit colours:

- **Metronome retires `#35C8C8`, adopts the brand teal `#799BA9`** (dark) /
  `#486B79` (light, deepened for 4.57:1 contrast on cream). Thematically apt —
  the metronome *is* the pulse the brand mark evokes — and it's a card + icon on
  Home and the practice screen, so the brand colour gets real visual weight.
- **Practice moves from generic indigo to a dusty plum** — `#8D7EA6` (dark) /
  `#705D8F` (light, 4.57:1) — analogous to the brand teal and in the same
  desaturation register, so the two feature cards read as one family instead of
  two unrelated UI-kit hues.

### Mechanism

- **Asset Catalog colour sets**, one per token, under
  `Assets.xcassets/Colors/*.colorset`, each with an "Any Appearance" (light) and
  a `luminosity: dark` override. `PocketColor` now returns `Color("Name")`
  instead of hex literals; SwiftUI/UIKit resolve the right value from the
  environment automatically — no manual `colorScheme` branching in views.
- **The app follows the system Light/Dark setting.** The five production
  `.preferredColorScheme(.dark)` call sites are removed; `#Preview` blocks keep
  theirs (canvas consistency, not shipped behaviour). No in-app appearance
  override for this slice — can be added to Settings later if wanted.
- **A new adaptive `ink` token** (near-black on light / white on dark) replaces
  bare `Color.white`/`Color.black` as the base for anything that used to be
  "white at N% opacity." `textPrimary`, and four new surface tokens —
  `surfaceSubtle` (hairlines, 5%), `surfaceStandard` (cards/pills/toggle-off
  states, 9%), `surfaceEmphasis` (selected chips, 18%), `surfaceBorder` (capsule
  stroke outlines, 15%) — are all `ink.opacity(_)`. Composing opacity on an
  adaptive base (rather than baking a flat resolved colour) keeps them correct
  over *any* backdrop, exactly like the original `white.opacity(...)` pattern
  did on the dark-only canvas. These four tokens replace **11 ad-hoc**
  `Color.white.opacity(...)` fills that were scattered across 9 view files with
  no shared token at all.
- **`textSecondary`, `barDefault`, `barPlayed`** are baked as flat resolved
  colours per appearance (not `ink.opacity`) because the same literal opacity
  value produces meaningfully *different* contrast once the base flips (e.g.
  `textSecondary` at a shared 60% opacity would land at 7.38:1 on dark but only
  4.23:1 on light) — each got its own contrast-matched pair instead:
  `textSecondary` #9B9B9B/#494644 (~7.4:1 both), `barDefault`
  #5C5C5C/#88817A (~3:1 both), `barPlayed` #313131/#C1B6AD (~1.5:1 both, an
  intentionally low-contrast "unfilled" state).
- **The six-colour loop-identity palette** (ADR 0023) gets a deepened light twin
  per hue, hue preserved, lightness/saturation retuned for ≥4.5:1 on cream (none
  of the originals cleared even 3:1 as-is). `waveformBar`'s base blue is
  similarly deepened for its light appearance, opacity layering (85%/40%)
  unchanged.
- **Left untouched:** `active`/`confirm` (green), `danger` (red), `marker`
  (orange), `pin` (purple) — these were already `Color.green`/`.red`/etc., which
  are system dynamic colours and already resolve per appearance today. Dimming
  scrims (`Color.black.opacity(...)` behind sheets/loading overlays) and shadow
  colours are left as literal black in both appearances — standard iOS
  convention, not a themed surface.

Full paired hex table and contrast ratios were computed and reviewed before
implementation; see the design-brief colour section for the summary table.

## Alternatives considered

- **Single hex value reused for both appearances.** Rejected — measured
  contrast collapses on the opposite background for every accent tested (see
  Context); this isn't a matter of taste, the numbers fail outright.
- **Keep Metronome's cyan and Practice's indigo, add a light twin for each as
  literally computed (deepen the existing hues).** Rejected — doesn't fix the
  underlying tonal clash with the brand teal; would still look like unrelated
  UI-kit colours next to the muted mark, just in both appearances now.
- **In-app Appearance override (System/Light/Dark) in Settings.** Deferred, not
  rejected — the system-follows-automatically behaviour is the standard/expected
  default and needed no new UI; an override is an easy follow-up if wanted.
- **Bake `surfaceSubtle`/`surfaceStandard`/etc. as flat resolved colours** (like
  `textSecondary`) instead of adaptive-ink-plus-opacity. Rejected — several of
  these composite over non-background surfaces (mastery dots on a card, minimap
  lines over the waveform canvas); a translucent composition stays correct over
  any backdrop, a flat bake would only be correct over the exact background it
  was computed against.

## Consequences

- `PocketColor` now depends on the Asset Catalog (`Assets.xcassets/Colors`);
  hex values live there, not in Swift, for the 15 tokens that needed a pair.
- Every screen now genuinely supports Light Mode — verified on device in both
  appearances, not just by contrast math.
- The functional-hue-separation contract from ADR 0023 (colour = identity, never
  decorative) is preserved and now extended across two appearances, not one.
