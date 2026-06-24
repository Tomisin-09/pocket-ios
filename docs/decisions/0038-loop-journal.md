# 0038 — Loop journal: context snapshots + entry kind (narrowing 0012)

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

ADR 0012 deferred a **practice journal** and sketched it as a dated journal
scoped *three* ways — per-loop, per-marker, and per-song — each snapshotting the
item's context (tempo, automation) alongside an optional annotation. That was a
forecast, not a commitment; it was right to keep the model decisions from boxing
in whatever shape the journal eventually took.

Building it for V1 (the journal/notes feature was moved ahead of the planner —
see `docs/backlog.md`), the three-scope shape is more than the practice loop
needs, and the scopes don't all carry the same value:

- **A loop is the unit you actually practise against.** "Got the bend clean at
  0.85×", "still rushing the triplet" — that progress is loop-scoped. A loop has
  a *mastery* and a *command tempo* that change over time, so a dated entry that
  records where those stood is a genuine practice log.
- **A marker is a signpost, not a practice unit.** It carries no mastery/tempo
  state to snapshot and nothing to journal *against* — journalling a single point
  in the song is noise.
- **A song doesn't need a timestamped journal; it needs free-text notes.** "Tune
  down a half step", "capo 2" — standing facts, not dated progress. `Song.comment`
  already exists for exactly this; surfacing it (slice 2) covers the song scope
  without a second journal model.

So the journal collapses to **one scope — the loop** — and the song gets **notes,
not a journal**. This ADR records the loop journal; song notes are a separate,
smaller slice on the same feature.

## Decision

### Scope: loop-only journal, song-only notes

- **Loops get a journal** (dated, append-mostly entries). Markers get nothing.
  Songs get free-text **notes** via the existing `Song.comment` (surfaced in the
  song detail sheet — slice 2, not this ADR). This **narrows ADR 0012's
  three-scope forecast** to one; 0012's per-marker and per-song *journal* ideas
  are dropped (song keeps notes, which it always had).

### `JournalEntry` model + context snapshot

- **New `@Model JournalEntry`**, cascade-owned by `Loop`
  (`@Relationship(deleteRule: .cascade, inverse: \Loop.journal)`), mirroring how
  `Song` owns its loops/markers. Fields:
  - `uid: UUID` — stable identity for list diffing / undo, like `Loop`/`Marker`.
  - `createdAt: Date` — the timestamp; entries sort newest-first.
  - `text: String` — the user's annotation (the only editable field).
  - `masteryAtEntry: Int`, `commandTempoAtEntry: Double` — **the context
    snapshot**, copied from the loop at creation.
  - `kindRaw: String` + computed `kind: EntryKind` — see below.
- **The snapshot is immutable.** An entry records *where things stood when it was
  written*. Mastery and command tempo keep moving on the loop; the entry must not
  move with them or it stops being a log. Only `text` (and `kind`) are editable
  after creation; the timestamp and the mastery/tempo snapshot are fixed. This is
  the whole point of snapshotting rather than referencing live loop state — and it
  makes a future AI summary of a song's loop journals (late-phase) rich, because
  each entry carries the conditions it was written under.

### Entry kind (brought forward to V1)

ADR 0012 floated an optional tag; the user opted to bring a small, closed,
**typed** set into V1 rather than ship plain text first and migrate later.

- **`EntryKind` enum, primitive-backed** — stored as `kindRaw: String` with a
  computed `kind` accessor, **never** as a raw enum attribute on the `@Model`.
  This is the standing rule from the SwiftData enum-attribute migration crash
  (a custom enum stored directly on a `@Model` wipes the store on migration;
  in-memory tests miss it, the device catches it). `Loop.loopType` already
  follows this shape and is the precedent.
- **Closed set, default Note:** 🎯 Goal · ⚡️ Breakthrough · 🧗 Struggle ·
  📝 Note · 🎬 Session. Unknown/empty raw → Note, so a migrated or malformed
  value degrades gracefully. Each kind renders as a small coloured chip on its
  entry row.

### Access point: a journal icon on the loop row

- The journal opens from a **journal icon on the loop row, left of the automator
  "A" button** — *not* from inside the automator sheet. The earlier ADR 0012
  framing tied the journal's context snapshot to the automation control; in
  practice journalling and ramp-automation are different actions, and burying the
  journal one modal deep made it a thing you'd forget. A dedicated row affordance,
  next to the existing "A", keeps it one tap from the loop it belongs to. (The
  automator "A" placement from ADR 0012 is unchanged; the journal sits beside it.)

### Entry lifecycle

- **Add** from the loop journal sheet: snapshots the loop's current mastery and
  command tempo, stamps `createdAt`, defaults kind to Note, inserts and attaches.
- **Edit** an entry: `text` and `kind` only — the snapshot and timestamp are
  read-only.
- **Delete** an entry: removed from the loop's journal (cascade already covers
  deleting the loop or song).

## Consequences

- The journal model is one `@Model` and one relationship, not three scopes — less
  surface, and every entry is a real practice log because the only thing journaled
  is the only thing with evolving mastery/tempo state.
- Snapshots are denormalised *on purpose*: an entry never changes after the moment
  it's written. The cost is a few copied scalars per entry; the payoff is a
  truthful timeline and a clean input for a later AI summary.
- Entry kind ships typed from day one, so there's no plain-text→enum migration to
  do later. The closed set keeps the chip vocabulary small and legible.
- `Song.annotationCount` (ADR 0012) can later fold in journal entries; out of
  scope here.

## Alternatives considered

- **Keep all three scopes from ADR 0012** — rejected: markers have no state worth
  snapshotting and a per-point journal is noise; the song's needs are met by
  free-text notes, not a dated journal. One scope covers the actual practice loop.
- **Reference live loop state instead of snapshotting** — rejected: the entry
  would silently rewrite its own history as the loop's mastery/tempo moved,
  defeating the purpose of a dated log.
- **Ship plain-text entries now, add a kind tag later** — rejected by the user in
  favour of bringing the typed kind into V1; avoids a later migration and gives
  entries legible categories immediately.
- **Open the journal from inside the automator sheet** (ADR 0012's framing) —
  rejected: it couples two unrelated actions and hides the journal a modal deep.
  A dedicated loop-row icon beside the "A" keeps it discoverable and direct.
