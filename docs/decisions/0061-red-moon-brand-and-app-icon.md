# 0061 — "Red Moon" brand mark, app icon, and display-name rename

- **Status:** Accepted
- **Date:** 2026-07-02

## Context

The app shipped with **no app icon and no brand mark** — a blank launch screen and the
placeholder name "Pocket". A brand exploration (the `Red-Moon-Rebrand` working folder) produced a
logo: a crescent **moon** with the Southern-Cross **stars**, the **"Red Moon"** wordmark, and a
quiet easter egg — the **"d" of "Red" is an open half-note** (its bowl is the notehead, its
ascender the stem). The mark is rendered in a muted slate-teal **`#799BA9`** on two backgrounds —
**cream** (light) and **near-black** (dark) — matching the app's dark-first surface.

We needed to get this into the app without destabilising signing/CI or over-reaching into a full
palette rebrand.

## Decision

Integrate the logo as **app icon + in-app brand mark**, and rename only the user-facing name.

- **Display name → "Red Moon"** via `CFBundleDisplayName` in `Info.plist`. The internal target,
  scheme, `PRODUCT_NAME` (`CFBundleName`) and bundle id (`click.decooperations.pocket`) stay
  **Pocket**, so code signing, CI and DerivedData are untouched.
- **App icon**: the crescent + stars (no wordmark — text doesn't read at icon sizes), centred on
  the brand near-black, in a new `Assets.xcassets/AppIcon.appiconset` (single 1024² universal iOS
  icon). Wired via `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`.
- **In-app brand mark**: a `RedMoonLogo` image set (full moon + wordmark) with **light + dark
  appearances** (cream card for light, near-black card for dark). Shown centred in the **Settings →
  About** footer. Because every surface is hardcoded to `PocketColor.background` (`#0F0F0F`)
  regardless of system appearance, the view **pins the image to the dark variant**
  (`.environment(\.colorScheme, .dark)`) so it always blends. The dark artwork is recomposited onto
  exactly `#0F0F0F` so there is no visible panel seam.
- The assets live under `Pocket/Resources/Assets.xcassets` (the app's **first** asset catalog),
  auto-included by XcodeGen's `sources: Pocket`.
- **Typeface → Futura** for all prose/UI text, echoing the wordmark. A single
  `Font.futura(_:weight:)` token (in `DesignTokens.swift`) maps each Dynamic Type text style to
  Futura at the right size with `relativeTo:` scaling; Futura's Medium/Bold faces cover weight
  (semibold+ → Futura-Bold, `.headline` → Bold). All ~167 semantic `.font(...)` call sites route
  through it; the **numeric `pocketMono`** token is unchanged (tempo/time stay monospace so live
  readouts don't jitter). System `Font.custom` falls back gracefully if Futura is ever absent.

## Alternatives considered

- **Full brand pass** (retint the functional palette to the teal, branded launch screen). Rejected
  for now — `PocketColor` is a **functional** colour system (hue carries meaning, ADR 0023);
  `#799BA9` is a brand/marketing hue, not a functional role. Kept out of the token table to avoid
  muddying that contract. Can be revisited as a dedicated theme task.
- **Rename the target/bundle id to Red Moon.** Rejected — breaks signing, provisioning and CI for
  zero user benefit; the home-screen name is all that shows.
- **Appearance-driven logo without pinning to dark.** Rejected — on a light-mode device the asset
  would resolve the cream card onto the app's dark canvas.
- **Transparent-background logo.** Rejected — the moon's texture uses the paper colour as part of
  the artwork, so knockout transparency mangles it; compositing onto the known canvas is cleaner.

## Consequences

- First app icon and first asset catalog in the project; `xcodegen generate` must run after pulling
  this (as ever).
- The functional palette is unchanged; the brand teal only appears in the icon and the About mark.
- Source artwork and iteration history are archived outside the repo
  (`~/Downloads/red-moon-logo-archive/`); the shipped master is `red_moon_logo_final_v2.png`.
