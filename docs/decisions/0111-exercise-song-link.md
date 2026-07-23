# 0111 — Direct Exercise ↔ Song link

- **Status:** Accepted
- **Date:** 2026-07-23 (`pocket-182-exercise-song-link`)
- **Builds on / revises:** ADR 0043/0046 (Exercise is a click-only, audio-free, `Song`-free
  entity), ADR 0066 (routines reference `Exercise`/`Loop`/`Song` in a sequence), ADR 0011/0012
  (SwiftData model + migration discipline).

## Context

A player who is learning a song wants to line up the *drills that serve it*: the alternating-picking
warm-up for its solo, the chord set for its verse, the scale box its lead sits in. Today nothing in
the store records "this exercise is **for** that song." The only place an exercise and a song meet is
inside a `Routine` (ADR 0066): a `RoutineItem` can point at an `Exercise` and another at a `Song`.
But that association is **positional and disposable** — it means "play these in this order in this
routine," it lives and dies with the routine, and it is not reusable. Delete the routine and the
knowledge that the exercise belongs to the song is gone. There is no way to ask "what should I drill
for this song?" or "which songs is this exercise helping?"

`Exercise` was deliberately built **`Song`-free** (ADR 0043/0046). Its header states it plainly: a
`Loop` is bound to an audio file/region, an exercise has no audio source, "It is a standalone
top-level entity in the store (no relationship to `Song`)." That boundary was the right call for what
it protected against — it stopped audio assumptions (`Loop.speed` as a *fraction of a song*, waveform
regions, DRM source reality per ADR 0001) from leaking into a click-only entity, and it kept the
tempo vocabulary clean (`Exercise` is absolute BPM, `Loop` is × of a song). **That reasoning is about
audio and tempo semantics, not about repertoire association.** A plain user-authored "this drill is
for this song" edge carries none of the audio/tempo baggage the boundary was protecting against. So
the boundary is narrower than its wording: it forbids treating an exercise *as* song-bound audio, not
recording that a player associates the two.

## Decision

**Add a direct, user-authored, reusable many-to-many link between `Exercise` and `Song`**, reversing
the "no relationship to `Song`" clause of ADR 0043/0046 for this one purpose.

- `Exercise.linkedSongs: [Song]` — the songs this drill is *for*.
- `Song.linkedExercises: [Exercise]` — the inverse: the drills that serve this song.
- **`.nullify` semantics both ways, no cascade.** Deleting a song removes it from its exercises'
  `linkedSongs` (the exercises survive — they're standalone units); deleting an exercise removes it
  from its songs' `linkedExercises` (the songs survive). Neither owns the other; the edge is
  membership, not ownership. This mirrors the nullify discipline already used for
  `RoutineItem.exercise`/`.loop`/`.song` (ADR 0066 R5).
- **Additive optional relationship.** Both sides default to `[]`, so SwiftData lightweight migration
  fills every pre-existing row with an empty set — no store wipe (the CoreData 134110 mandatory-
  attribute rule, ADR 0012). No new type is registered in the container: `Song.self` and
  `Exercise.self` are both already in `PocketApp`'s `modelContainer(for:)`, so the join is created
  from the existing schema.

The edge is **the substrate only**. What it unlocks — a "Build a practice routine for this song"
generator that materialises a `Routine` from a song's `linkedExercises` + its `loops` + a `play`
block — is a **separate, later slice**. This ADR commits to the schema and the boundary change,
nothing more, so the migration lands and settles on its own.

### Follow-up (implemented, same PR): the generator

The generator shipped alongside this ADR and needed **no decision of its own** — it closes off no
alternative the way a new ADR would, because it reuses the planner's existing session-materialisation
seam wholesale. The pure `SongRoutineBuilder` (Core/Planner) reads a song's `linkedExercises` (`.focus`
blocks) + `loops` (`.focus` blocks) + the song itself (a trailing `.play` block) and emits the
planner's `[SessionBlock]`; the entry point (`SongDetailsSheet` → **Build a routine for this song**)
hands those to `RoutineDetailView(generatedSession:)` → `PracticePlanner.materialise`, so the routine
is reviewed in the normal editor and **only persists on Save** (Cancel/back leaves no orphan). This is
the "the planner becomes just a smarter producer of these same edges" consequence below, realised: the
direct edge is simply the *first* producer of session blocks, sharing the planner's materialiser.

### First many-to-many in the store

Every existing SwiftData relationship in Pocket is **to-one on its inverse** (`Loop.song`,
`Marker.song`, `RoutineItem.exercise/.loop/.song`, `*.journal`, `*.recordings`). This is the
codebase's **first many-to-many**. Per SwiftData rules, `@Relationship(inverse:)` is declared on
**exactly one side** — here `Exercise.linkedSongs`, with the inverse key path `\Song.linkedExercises`
— and the other side is a plain array property whose inverse SwiftData infers (declaring `inverse:`
on both sides is a circular-reference error). The to-many inverse's implicit delete rule is
`.nullify`, which is exactly what we want, so the un-annotated `Song.linkedExercises` side gets nullify
for free; the explicit `deleteRule: .nullify` on the `Exercise` side documents the intent.

## Consequences

- The store gains a reusable repertoire graph: a song knows its drills, a drill knows its songs, and
  the association outlives any routine. This is the durable edge the later routine-generator, and
  eventually the V2 planner (ADR 0064), both consume — the planner becomes a smarter *producer* of
  these same edges rather than a parallel mechanism.
- `Exercise` is no longer strictly `Song`-free. Its header is updated to scope the old absolute — the
  boundary now reads "audio/tempo-free," not "association-free" — so the next reader doesn't take the
  edge as an accident. **The audio/tempo firewall stands:** an exercise still has no audio source, no
  waveform region, and absolute-BPM tempos; `linkedSongs` is metadata, never an audio or tempo input.
- **Migration is the risk and it is contained:** a purely additive relationship on two already-
  registered models. Verified device-side, not just via the in-memory test, because SwiftData's
  store-wipe footguns are device-only (the enum-attribute and mandatory-attribute traps both pass
  in-memory then fail on device — ADR 0012).

## Alternatives considered

- **Routine-only association (status quo).** `RoutineItem` already co-locates an exercise and a song
  in a sequence. Rejected: the link is positional, disposable, and dies with the routine — it answers
  "what's next in this session," never "what should I drill for this song." Not reusable, not
  queryable.
- **Revive the planner's `Goal.targetSong` + `skillIDs`.** Route the association indirectly through
  the skill taxonomy (song → skills → exercises). Rejected as the *first* step: heavier, indirect, and
  it pulls the deferred V2 planner (ADR 0064) forward before its time. The direct edge is the simple
  primitive; the planner can layer skill inference on top later without contradicting it.
- **Keep `Exercise` strictly `Song`-free and store the link on `Song` only** (`Song.drillNotes` free
  text, or a one-way id list). Rejected: a one-way, untyped reference can't be traversed from the
  exercise, breaks referential integrity on delete (dangling ids), and forfeits the inverse the
  generator/planner need ("which songs is this drill helping?").
