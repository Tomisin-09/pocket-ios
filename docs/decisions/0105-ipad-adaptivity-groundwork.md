# 0105 — iPad adaptivity groundwork, universal deferred

- **Status:** Accepted
- **Date:** 2026-07-22 (`pocket-167-ipad-adaptivity-groundwork`)

## Context

Red Moon is deliberately **iPhone-only** for v1: `TARGETED_DEVICE_FAMILY: "1"`
in `project.yml`. That flag was set during the v1 submission because going
universal (the Xcode default) triggers App Store validation **90474** — iPad
multitasking requires all four orientations incl. `PortraitUpsideDown` — and
would require a full set of **iPad screenshots**. Staying iPhone-only sidesteps
both; the app still runs on iPad in **compatibility mode** (a letterboxed phone
UI), which is a legitimate v1 posture.

The layout, however, was written phone-first with no adaptivity at all. There is
**no** `horizontalSizeClass` branching, no `NavigationSplitView`, and no idiom
checks anywhere in the codebase — the root is a single `NavigationStack`
(`HomeView`, ADR 0044) in a bare `WindowGroup`, and the ~30 `.sheet(...)` call
sites (12 with `presentationDetents`) are tuned to phone width. So the day we do
flip to universal, content would stretch edge-to-edge at 1024 pt and the detent
sheets would read as oversized phone cards.

The tension: we want the app to be a *good* iPad app eventually, but flipping to
universal now re-opens the 90474 / screenshots / re-review surface on an
**in-flight, paused v1 submission**. We do not want to gate this design work on
that submission, and we do not want to take on iPad submission risk to land it.

## Decision

### 1 — Write the adaptivity now; keep the flag at `1`
We build the size-class-adaptive SwiftUI (width caps, form-sheet widths,
selective two-pane layouts) **now**, but leave `TARGETED_DEVICE_FAMILY: "1"`
untouched. The code lands **dormant**: it changes nothing user-facing in v1
(iPad stays compat mode), carries no submission risk, and does not block on the
submission. The eventual flip to universal then becomes a **one-line build-flag
change plus the screenshot/review work** — not a layout scramble.

### 2 — The future flip opts out of multitasking
When we do go universal, the intended Info.plist posture is
`UIRequiresFullScreen = YES` — opt **out** of Split View / Slide Over. That
resolves 90474 without adding `PortraitUpsideDown` or taking on the much larger
multitasking QA surface, and it keeps the existing portrait/orientation model
(ADR 0042, `OrientationGate`) intact. Full multitasking is a deliberately
separate, later decision, not foreclosed here.

### 3 — Verification is preview-driven while the flag is `1`
Because the flag stays `1`, **none of this renders on an iPad or the iPad
simulator in v1** — the app runs there in compatibility mode. The honest test
surface for dormant regular-width layout is:

- **Previews** that force `.environment(\.horizontalSizeClass, .regular)` (and a
  wide frame), added alongside the existing compact previews on the screens we
  touch; and
- **iPhone Pro Max in landscape**, which is genuinely regular-width horizontally.

New adaptive code in this line of work ships with a regular-width preview variant
so the dormant layout stays inspectable without an iPad build.

### 4 — Scope guard: cap first, split sparingly
The default adaptive treatment is a shared **readable-width cap**, not a
rearchitecture. Only Home and Library are candidates for a two-pane
(`NavigationSplitView`) treatment; every other screen consumes the width cap and
is otherwise unchanged. We do not blanket-convert the app to split views.

## Alternatives considered

- **Flip to universal now (full v1 iPad app).** Rejected for v1: re-opens 90474,
  demands iPad screenshots, and adds re-review risk to a paused submission for no
  v1 user benefit. Not foreclosed — this ADR is exactly the groundwork that makes
  that flip cheap later.
- **Universal + full multitasking (Split View / Slide Over).** Rejected as the
  first step: largest QA and layout surface, forces all four orientations, and
  would require reworking `OrientationGate` (ADR 0042). Revisit as its own ADR if
  iPad becomes a first-class target.
- **Do nothing until we decide to ship iPad.** Rejected: the layout debt is real
  and cheap to pay down incrementally now; deferring it bundles a large,
  untestable change onto the eventual (screenshot-gated) flip.

## Consequences

- No user-visible change in v1 and no submission risk: the flag stays `1`, iPad
  stays compat mode.
- Screens touched in this line of work gain regular-width preview variants;
  reviewers/authors inspect iPad layout there, not on an iPad build.
- The eventual universal flip is pre-scoped to: flip the flag, set
  `UIRequiresFullScreen = YES`, produce iPad screenshots, re-submit — with the
  layouts already in place.
- Sheet adaptivity must preserve the ADR-0090 `.sheet(item:)` / `StableRef`
  presentation pattern; width changes touch the compact path not at all.
