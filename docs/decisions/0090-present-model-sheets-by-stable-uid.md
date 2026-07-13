# 0090 — Present @Model edit sheets by stable `uid`, not `persistentModelID`

- **Status:** Accepted (2026-07-13)
- **Date:** 2026-07-13
- **Relates to:** `Loop.uid` / `Marker.uid` (the stable business ids these models already carry); ADR 0019
  (loop edit-sheet undo); ADR 0088 (journal authoring on the loop edit sheet, which also saves the context).

## Context

The loop edit sheet (and the marker and automator sheets that share its shape) could **dismiss itself
mid-edit** — reported as the sheet "regenerating" while you were still in it. Intermittent: it only hit
loops/markers **created in the same session**, never ones loaded from a previous launch.

Root cause: the sheets are presented with `.sheet(item: $model.editingLoop)`, and `Loop`/`Marker` are
SwiftData `@Model`s, so `.sheet(item:)` keys presentation on the default `Identifiable` id —
`persistentModelID`. For a freshly `insert`ed model that id is **temporary** and flips to a **permanent**
value on the next save. Autosave is on (and ADR 0088's journal writes save explicitly), so a save firing
while the sheet was open changed the presented item's `id`, which SwiftUI reads as "a different item" and
dismisses. Models loaded from the store already carry a permanent id, which is why older loops never
reproduced it. The codebase already anticipated this hazard: `uid` (a `UUID` assigned at init) exists
precisely because "the SwiftData `persistentModelID` is unstable before insert" (`Loop.uid` doc comment),
and it's already the id used for active-loop/selection tracking.

## Decision

- **D1 — Present editing sheets through a `uid`-keyed wrapper.** A small `StableRef<Model: UIDIdentified>`
  (`Identifiable` with `id: UUID { value.uid }`) wraps the model for presentation. `Loop` and `Marker`
  conform to `UIDIdentified` (they already have `uid`). The three waveform edit sheets —
  `editingLoop`, `editingMarker`, `editingAutomatorLoop` — hold `StableRef<…>?` instead of the raw model.
  The sheet now stays put through a save because `uid` never changes.
- **D2 — The wrapper holds the live model, not a copy.** The sheet still edits the real `@Model` (Cancel
  discards, Done writes through, per ADR 0019); only the *presentation identity* changed. The strong
  reference in the ref keeps the model alive for the sheet's lifetime.
- **D3 — Rule going forward:** any `.sheet(item:)` / `.fullScreenCover(item:)` bound to a SwiftData
  `@Model` that can be presented on a freshly-created instance should present by `StableRef` (stable
  `uid`), never bind the model directly. Binding the model directly is the closed-off alternative.

## Consequences

- `Loop.uid` is a stable `UUID` assigned at init, so the invariant `StableRef(value:).id == model.uid` is
  pure and unit-tested (`StableModelRefTests`) — no `ModelContext` needed (context inserts trap in the test
  host).
- Scope: the three edit sheets. The "Practice now" `fullScreenCover(item: $model.practiceLoop)` was left on
  the raw model — it launches only after the edit sheet's Done (by which point the loop has been written),
  so it doesn't share the fresh-insert window; move it to `StableRef` too if that ever changes.
- Verify on device: create a new loop, open its edit sheet, keep it open across an autosave (e.g. add a
  journal entry, or just wait), and confirm the sheet stays open with your edits intact.
