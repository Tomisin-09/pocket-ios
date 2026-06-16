# 0007 — Practice-screen state lives in an @Observable view model

- **Status:** Accepted
- **Date:** 2026-06-16

## Context

`WaveformPracticeView` had grown to **exactly 400 lines** — SwiftLint's
`file_length` warning threshold — holding ~15 `@State` properties, ~10 computed
properties, and ~190 lines of gesture/loop handlers. Landing the previous branch
(region looping, ADR 0006) required gutting handler comments just to fit, and
ADR 0006 explicitly flagged that "the next addition should be preceded by
extracting a view model or splitting the file." Several screen features are
queued next (pinch-zoom, undo toast, snap-to-marker, automator), none of which
can land without first making room.

The handlers couldn't simply be split into a second file: they mutate the view's
`private @State`, and a cross-file `extension` can't reach `private` storage. So
the state itself had to move somewhere the handlers could share.

## Decision

- **Introduce `@MainActor @Observable final class WaveformPracticeModel`** that
  owns all practice-screen state, computed properties, the `PracticeAudioEngine`,
  and every handler. `WaveformPracticeView` keeps only `@State private var model`,
  the `body`, the sheets, and the `onChange`/`task` wiring — it reads `model.*`
  and binds via `@Bindable var model = model` (Apple's `@Observable` binding
  pattern).
- **Split across three files**, mirroring the prior class/extension layout:
  `WaveformPracticeModel.swift` (state + computed + `loadSample`),
  `WaveformPracticeModel+Actions.swift` (the handlers, moved verbatim), and the
  slimmed `WaveformPracticeView.swift`. The view dropped 400 → ~130 lines; no
  file exceeds ~190.
- **`InteractionMode` stays nested in `WaveformPracticeView`.** It's a pure
  presentation enum referenced as `WaveformPracticeView.InteractionMode` by six
  sibling files; keeping it there meant zero churn. `CaptureDraft` / `NamingDraft`
  are model state and move to `extension WaveformPracticeModel`.
- **Model members are `internal`.** Both the view and the cross-file actions
  extension need access. Encapsulation is preserved in practice because only this
  one view owns the model and nothing else references its internals.

## Consequences

- This branch is **behaviour-preserving** — a pure extraction, no UX change. The
  pure math the handlers call (`WaveformGesture`, `AudioMath`, `TempoMath`) is
  already unit-tested, so no new test is introduced; the bar is that existing
  tests stay green.
- The practice screen now has headroom for the queued features without tripping
  the file-length limit.
- The model is `@MainActor` and owns the engine, so it isn't a "pure logic" unit
  in the AGENTS.md sense (it touches audio + UI); it stays verified via build +
  existing tests + on-device/preview smoke, not a unit test.

## Alternatives considered

- **Split handlers to a second file, state stays in the view** — impossible:
  cross-file extensions can't access `private @State`. Making the state
  `internal` on the *view* would leak it to the whole module without the
  organisational win of a model.
- **Promote `InteractionMode` to a top-level type** — rejected: more churn across
  six files for no benefit; the enum is genuinely view-facing.
- **Forward every engine property through the model** (`model.isPlaying`, …) —
  rejected as boilerplate; exposing `engine` and reading `model.engine.isPlaying`
  is observation-correct (nested `@Observable`) and simpler.
