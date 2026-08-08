# 0095 — Saved custom chords: a reusable "My chords" library

- **Status:** Accepted (2026-07-17; shipped — see build note below)
- **Date:** 2026-07-17
- **Builds on:** ADR 0084 (movable grips + the custom-chord placer), ADR 0065 (the Chords template —
  `ChordVoicing` / `ChordProgression`), ADR 0011 (SwiftData persistence).
- **Relates to:** ADR 0093 (the chord identifier — makes naming a bespoke shape effortless, which is what
  makes saving worth it), ADR 0096 (the future chord/theory/resources hub, where this library later
  gets a home of its own).

## Context

A custom voicing built in the placer (ADR 0084 slice 3) lives **only inside the one progression it was
inserted into** — `ChordProgressionEditor.apply(_:to:)` appends it to that exercise's `ChordProgression`
and nothing more. Build the same bespoke shape for another exercise and you start from scratch on the
tappable board. Now that the identifier (ADR 0093) names a shape for you, authoring one is quick and the
result is *named* — which makes it worth keeping. Players asked to **save custom chords** and reuse them.

There is no user-owned chord persistence today. The curated shapes the Add menu offers come from the
static in-house `ChordVoicing.library` table; progressions themselves persist as a Codable `Data` blob on
`Exercise.templatePayload`, never as child `@Model`s. So "save my chords" needs a *new* place to live.

Two questions: **how to persist** (this project has been bitten by SwiftData four times — see
`docs/swiftdata-gotchas.md`), and **where to surface** save + reuse without adding a whole new screen
before the larger hub (ADR 0096) is scoped.

## Decision

- **S1 — A new `SavedChord` `@Model`, voicing stored as an encoded blob.** A standalone model:
  `uid: UUID`, `name: String`, `createdAt: Date`, and **`voicingData: Data`** — the `ChordVoicing`
  JSON-encoded, decoded through a computed `voicing` accessor. This mirrors the established
  payload-as-blob pattern (`templatePayload` / `StrumPattern` / `FretboardContent`) and **deliberately
  avoids storing the `ChordVoicing` struct (or any custom type / enum) as a stored attribute** — the
  migration footgun that crashes on device with old data (ADR 0011, gotchas §1). `name` is a separate
  primitive column so the list sorts/filters without decoding every blob. No relationships: a saved chord
  is a library entry that intentionally **outlives** any exercise, so nothing owns or cascades it.

- **S2 — Adding the model is an additive schema change.** `SavedChord.self` joins the container schema
  (`PocketApp`). A brand-new model creates a new empty table; existing models and their rows are
  untouched — **not** a data migration of anything that exists, so it can't hit the enum/lossy-migration
  traps. (Still device-tested over an existing install per the gotchas, since it's a schema change.)

- **S3 — Save is explicit, from inside the custom placer.** `CustomChordSheet` gains an **optional
  `onSave` seam** and, when wired, a **"Save to My chords"** button (enabled once the shape is valid and
  named). Save and Insert are **separate intents** (the product call): you can save without inserting or
  insert without saving. The sheet stays persistence-agnostic — the editor owns the `ModelContext` and
  does the insert — matching the existing `onInsert` seam. Tapping Save shows a brief **"Saved"**
  confirmation and de-dupes: an identical name+geometry already saved isn't stacked again (pure
  `SavedChord.isAlreadySaved(_:among:)`, unit-tested).

- **S4 — Reuse is surfaced where you add chords.** The Add-chord menu and the per-row swap menu in
  `ChordProgressionEditor` gain a **"My chords" section** (shown only when non-empty) listing each saved
  chord as a one-tap insert — above the curated `ChordVoicing.library`, because the place you look for a
  chord to add *is* that menu. A **"Manage…"** item opens `SavedChordsSheet`, a `List` of the saved chords
  (diagram + name) supporting **swipe-to-delete** and tap-to-insert — because a dropdown `Menu` can't
  host a swipe action, and a growing library needs pruning. The editor reads them with a plain
  `@Query` sorted by `name` (a primitive column — no optional `#Predicate`, gotchas §2).

- **S5 — This is the interim home; the hub is where it graduates.** Surfacing inside the chord editor
  keeps the footprint small and discoverable now. The dedicated **"My Chords" library screen** — and the
  broader theory / ear-training / glossary space it would sit in — is deferred to ADR 0096; `SavedChord`
  and `SavedChordsSheet` are built so that screen can consume them unchanged.

## Consequences

- **Custom chords stop being single-use.** A shape authored once is one tap away in every progression,
  and the identifier (ADR 0093) means it arrives already named.
- **Migration-safe by construction.** New standalone model + blob-stored payload + primitive-only columns
  = none of the four known SwiftData traps apply. Device-verified over existing data regardless.
- **No new top-level surface yet.** Save lives in the placer; reuse lives in the add-chord menu; delete
  lives in a small list sheet. The larger hub can adopt these types later without rework.
- **The renderer and progression are untouched.** A saved chord round-trips to the same plain
  `ChordVoicing` a grip or placer emits (ADR 0084 M5), so nothing downstream changes.
- **Local-only for now.** Whether the library syncs via CloudKit follows the app's existing container
  posture; nothing here forces a sync decision.

## Alternatives considered

- **Store the `ChordVoicing` as a SwiftData attribute (or a child `@Model` with `[Int?]` columns).**
  Rejected — storing a custom Codable type/enum attribute is the exact device-only migration crash the
  gotchas warn against, and a child model buys nothing over a blob for an immutable value payload (the
  same reason `templatePayload` is a blob). Primitives + a `Data` blob is the proven pattern.
- **Persist to `@AppStorage`/`UserDefaults` as a JSON array.** Rejected — clunky for a growing,
  individually-deletable list, no `@Query` integration, and out of step with every other user-owned
  collection here (all `@Model`s). A model is the consistent choice.
- **Auto-save every inserted custom chord (no explicit Save).** Rejected — clutters the library with
  one-off shapes the player never wants again; explicit Save keeps "My chords" curated (the product call,
  matching the chosen explicit-Save-button option).
- **Build the dedicated "My Chords" screen now.** Deferred to ADR 0096 — it's part of a larger hub
  (theory / ear-training / glossary / resources) the player was excited about, and that deserves its own
  design pass rather than being half-built as a chord-only screen here.
- **Cram delete into the dropdown menu.** Not possible — SwiftUI `Menu` items can't carry a swipe action;
  hence the small `SavedChordsSheet` `List` for management (S4).

## Build

**Shipped.** The `SavedChord` `@Model` (`Pocket/Core/Models/SavedChord.swift`) stores the voicing as
an encoded payload, not a child `@Model`. Management moved from the planned `SavedChordsSheet` to
`MyChordsView` in the Toolkit hub (ADR 0096) — the "own design pass" this ADR's last alternative
asked for — with `CustomChordSheet` in "Save" mode as the build path, and the library also inlined
into the chord picker's *My chords* group (ADR 0103).
