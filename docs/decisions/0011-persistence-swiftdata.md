# 0011 — Persistence: SwiftData `@Model` domain (Song / Loop / Marker)

- **Status:** Accepted
- **Date:** 2026-06-17

## Context

The practice screen ran entirely on `WaveformMock` — a generated arpeggio plus
hardcoded value structs. Nothing survived a relaunch. To make Pocket a real tool, the
loops/markers (and the song they hang off) have to persist. PROJECT.md already commits
to "SwiftData models, CloudKit-backed" for app data, so this is about *how* the domain
is modelled, not whether to use SwiftData.

## Decision

- **The domain is SwiftData `@Model` classes** — `Song`, `Loop`, `Marker` — promoted
  out of `WaveformMock` into `Pocket/Core/Models/`. Not a parallel struct + repository
  layer: that would add a mapping boundary and diverge from the documented
  SwiftData/CloudKit path (an `@Model` graph syncs via CloudKit directly).
- **`Song` is the aggregate root.** It carries the metadata, the extracted
  `amplitudes`, the import identity (`SongRef`, flattened to `sourceID`/`sourceRaw`/
  `bookmark`), and `@Relationship(deleteRule: .cascade)` to its `loops`/`markers`.
- **`SongRef` (already built) is the identity**, stored on `Song`. `bookmark == nil`
  marks the generated demo sample; a real bookmark (Slice 2) points at an imported file.
- **The view model binds to a `Song` + `ModelContext`.** `loops`/`markers` are the
  song's relationships (sorted for display); create/delete go through the context;
  edits write straight to the `@Model` (auto-persisting), so the edit sheets keep their
  "edit a local `@State` copy → apply on Done" pattern and Cancel still discards.
- **A stable `Loop.uid` / `Marker.uid` (UUID)** is used for active/selection tracking,
  because SwiftData's `persistentModelID` is unstable before insert.
- **Transient UI state stays value-typed** — `CaptureDraft`, naming drafts, the live
  playhead, zoom — it isn't persisted, so it doesn't belong on the `@Model`s.
- **Seed on first launch:** an empty store gets one `Song.sample()` so the screen always
  has content (until the import UI lands in the next slice).

## Consequences

- Loops/markers and their edits now persist across launches; CloudKit sync is a
  configuration step later, not a re-model.
- The previously value-typed feature now passes `@Model` references around; the change
  was mechanical (`WaveformMock.Loop/Marker/Song` → the real types across the waveform
  files). `WaveformMock` is deleted.
- A new loop/marker is created detached and only inserted on save — cancelling a name
  sheet simply drops the unmanaged object (no cleanup needed).

## Alternatives considered

- **Value structs + a SwiftData repository (map at the boundary).** Keeps the feature
  100% value-typed but adds a mapping layer to maintain and still needs `@Model`
  entities underneath for CloudKit — so it's more code for the same persistence. Rejected.
- **Stay on mock.** The status quo; rejected — it's the thing we're fixing.

## Follow-ups (Slice 2 / later)

- File import (`SongImporter`/`WaveformExtractor`) + a `LibraryView`; resolve the
  bookmark to load the real file and extract its waveform. Retire the seeded arpeggio.
- CloudKit container entitlements (Phase 4).
