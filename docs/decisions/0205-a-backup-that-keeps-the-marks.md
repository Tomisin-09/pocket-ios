# ADR 0205 — a backup that keeps the marks

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-308-snags-read-back`)
- **Amends:** ADR 0181 — the archive gains `SongRecord.snags` and `LoopRecord.spanChanges` (D1, D2).
  The format's rules, its nesting discipline and its two deliberate exclusions are unchanged.
- **Amends:** ADR 0188 — restore hydrates both (D3). `SchemaVersionGate`, D1's trust asymmetry and
  the raw-enum-column rule are untouched; `currentSchemaVersion` does not move (D4).
- **Relates to:** ADR 0199 (the span history), ADR 0200 (the mark), ADR 0152 (relinking, which is why
  `songDuration` travels), ADR 0148 (why bookmarks do not)
- **Schema:** none in the store. The **archive format** gains two additive optional collections; see
  D4 for why that does not move `schemaVersion`.

## Context

ADR 0200's Consequences listed what it had not built, and the list ended with *"no export"*. ADR 0199
did not mention the export at all, which is the more dangerous of the two omissions: a span history
is the only record of how a loop got where it is, and `Loop.start` / `Loop.end` are overwritten in
place, so an archive that skipped it would restore a library where every loop looked deliberately
placed and none of them had a way back down (ADR 0201).

`PracticeArchive`'s own doc comment sets the standard this has to meet: an export that named
something it did not carry would be *"a record the player cannot put back together"*. Two cascade
-owned children of a song and a loop were being left on the floor.

**Scope note.** The request was snags in the export. The span history is included because it is the
same gap in the same two files, lands under the same additive rule, and leaving it would mean the
next author opens `PracticeArchive+Songs.swift` for the second half of one omission.

## Decisions

### D1 — a snag nests under the **song**, not under a loop

`SongRecord.snags: [SnagRecord]` — `uid`, `markedAt`, `seconds`, `speed`, `loopUID`.

It nests where the store puts it. `Snag` is cascade-owned by `Song` (ADR 0200) and only *tagged* with
a loop, because 2:01 is 2:01 whether or not the loop that was armed still exists. Nesting it under
`LoopRecord` would have done two bad things at once: asserted an ownership the model does not have,
and **silently dropped every mark made with no loop armed** — a real case the model has a `nil` for.

`loopUID` is written as the loose id copy it is, and it resolves on the way back in **because** a
restore preserves the loop's own `uid` rather than minting one (ADR 0188 D1). When it does not
resolve — a snag whose loop was deleted before the export — the mark is still right, and the app
already draws it with no caption (ADR 0203 D2).

### D2 — the span history nests under the loop, with the duration it was written with

`LoopRecord.spanChanges: [LoopSpanChangeRecord]` carries both pairs of bounds, the speed, and
`songDuration`.

Both pairs travel because each row is **self-contained by design** — that is what lets one row answer
"widen back to where it was" without walking the chain, and it is what stops a dropped row corrupting
its neighbours' meaning.

`songDuration` is the duration **at write time**, and it must land unchanged. It exists so a span
reads back in seconds after a relink (ADR 0152) or a re-encode; recomputing it from the song's
current duration on restore would quietly rewrite every historical span the first time a file
changed length. The archive's job is to say what the store says.

### D3 — restore rebuilds both, uids and all

Snags come back on the song; span changes come back on the loop. `uid`s are the file's, which is ADR
0188 D1's restore column: this is the same player's library coming home, and a minted uid would break
the one pointer a snag has.

**The receive door is untouched.** `SharedPractice` (ADR 0188 D5) carries routines and drills, and it
carries no loops at all — its own doc comment records why: *"a `loopUID` is meaningless without the
song that owns it"*. So there was never a hole to close there, and there is nothing here a stranger's
file could deliver.

### D4 — additive, so `schemaVersion` stays at 1

`PracticeArchive.currentSchemaVersion` is bumped *"when a field changes meaning rather than when one
is added"* — the rule `RoutineItemRecord.orphanLabel` already tested. Nothing here changes a meaning.

Both collections take a **declaration default of `[]`**, so an archive written before this reads as
an empty list rather than failing. That keeps `SchemaVersionGate`'s equal-proceeds path honest: a v1
file from last month and a v1 file from today are both v1, and both read.

The default alone does not achieve that, which is D5.

### D5 — a declaration default does not survive a missing key, and that is a rule now

**Swift's synthesized `Decodable` does not fall back to a property's default value.** It calls
`decode(_:forKey:)`, which throws `keyNotFound`. A declaration default on a new record field does
nothing on the way *in*: an archive written before that field existed fails to decode **entirely**,
and a restore of a real backup dies on one absent key.

This was found by the test written to assert the opposite, which is the only reason it is written
down here rather than discovered by a player whose backup would not open.

An `Optional` field is exempt — the synthesizer uses `decodeIfPresent` for those, which is why
`RoutineItemRecord.orphanLabel` was genuinely safe and why ADR 0181 could say an additive field does
not move `schemaVersion`. A **non-optional collection with a default** is not exempt, and that is the
shape an added child list wants to be.

So `ArchiveCoding.swift` carries a `KeyedDecodingContainer` overload per additive collection type,
which decodes it as absent-tolerant. They are **named types, not a generic over `[T]`**: a generic
overload would make every missing array in every `Codable` type in the app decode as empty, including
required ones, turning a corrupt file into a silently half-read one — the single failure a backup
format must not have. Adding an entry is a per-field decision, taken once, when the field is added.

**One sibling shares the shape and is safe today.** `ReferenceLinkRecord.attachmentFileName: String`
was added by ADR 0167 phase 2 (`b135422`), after ADR 0181 defined the format, with the same
non-optional-plus-default shape and no tolerance. It has never shipped absent, because export and
that field are both still in `[Unreleased]` — no archive in anyone's hands lacks the key. It is
therefore left as it is rather than changed under this ADR, and it is parked in `docs/backlog.md`
against the release that first makes the format public.

## Consequences

- An exported archive is once again a complete record of everything the player has written *and* of
  everything the app recorded on their behalf. A restore brings back the marks on a passage and the
  ladder of narrowings that led to the loop's current bounds.
- The two new records are written in the archive's usual deterministic orders — snags in song order,
  span changes oldest first, `uid` breaking every tie — so two exports of an unchanged library stay
  byte-identical.
- **The format has a stated rule about additive fields now**, and one place to obey it. Before this
  it had a habit that happened to have held, because every field added since v1 was either optional
  or shipped in the same unreleased window as the format itself.
- The export grows by a few dozen bytes per mark. Against take audio, which the archive makes
  optional precisely because it can run to hundreds of megabytes, this is not a size question.
- **Not built:** the restore preview still counts top-level kinds only (ADR 0188), so a restore says
  "3 songs" rather than "3 songs and 41 snags". That is right — the preview exists to say what will
  land, and a snag lands with its song by definition.
