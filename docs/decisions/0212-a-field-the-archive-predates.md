# ADR 0212 — a field the archive predates

- **Status:** Accepted
- **Date:** 2026-09-10 (`pocket-313-attachment-name-absent-tolerant`)
- **Amends:** ADR 0205 — D5 stated the absent-tolerance rule, named `attachmentFileName` as the one
  sibling that shared the shape, and deliberately left it alone as safe-for-now. D1 here fixes it and
  D3 extends D5's rule to cover scalars, which D5 had no mechanism for. The named-overload discipline
  D5 established is unchanged and still governs collections.
- **Relates to:** ADR 0167 (phase 2, which added the field), ADR 0181 (the format the field arrived
  after), ADR 0188 (`SchemaVersionGate`, which D4 leaves where it is), ADR 0189 (why a backup that
  will not open is the failure that matters)
- **Schema:** none in the store — `ReferenceLink.attachmentFileName` is untouched (D2). The **archive
  format** changes one field from a required string to an optional one; `schemaVersion` does not move,
  see D4.

## Context

ADR 0205 D5 found that Swift's synthesized `Decodable` ignores a property's declaration default: it
calls `decode(_:forKey:)`, which throws `keyNotFound`. An archive written before a field existed
therefore fails to decode **entirely** — a whole backup dies on one absent key. D5 bought tolerance
for the two collections it added, and closed by naming a sibling it did not fix:

> `ReferenceLinkRecord.attachmentFileName: String` was added by ADR 0167 phase 2 (`b135422`), after
> ADR 0181 defined the format, with the same non-optional-plus-default shape and no tolerance.

It was left because it was safe: export and that field were both still unreleased, so no archive in
anyone's hands lacked the key. That is a statement with an expiry date on it. The moment a build puts
an archive in a player's hands, every archive written by it is a file that a *later* build — one that
adds a field this way again, having read a rule that only covers arrays — cannot open.

This is the ADR 0189 failure in its worst form. A migration that fails traps at launch and Restore is
unreachable; an archive that will not decode is the copy that was supposed to be the way out of that.

## Decisions

### D1 — the record's field is `Optional`, read through `?? ""`

`ReferenceLinkRecord.attachmentFileName` becomes `String?`. `Optional` is the one shape the
synthesizer already decodes with `decodeIfPresent`, which is why `RoutineItemRecord.orphanLabel` was
genuinely safe and why ADR 0181 could say an additive field does not move `schemaVersion`.

It has exactly two read sites — `PracticeArchive.referenceAttachmentFileNames`, which stages the
files into the zip, and `ArchiveRestoreWriter.references`, which puts the rows back — and both
already filtered or defaulted the empty string, so neither gains a branch.

**The alternative was a hand-written `init(from:)` on the record**, eight fields rather than
`SongRecord`'s twenty-five, and it is rejected on the failure it would create rather than the typing
it would cost. A hand-written `init(from:)` does not have to assign a stored property that has a
declaration default, so the *next* field added to that struct would compile, never be decoded, and
restore as its default with nothing to say so — trading a loud total failure for silent data loss,
which is the trade a backup format must not make. `Optional` fails the other way: the compiler
enumerates every read site, and a site that is forgotten does not build.

### D2 — the model keeps its non-optional `String`, and that is not an inconsistency

`ReferenceLink.attachmentFileName` stays `String = ""`. The two shapes answer different questions.
The `@Model` property obeys this codebase's CoreData 134110 rule — a declaration default, never an
`init`-only one — because what it has to survive is a **migration**, where a default is applied. The
record has to survive a **decode**, where it is not. The mapping between them is the `?? ""` at the
one restore site.

### D3 — an additive scalar is declared `Optional`; it never takes a container overload

D5's mechanism does not extend here, and the reason is the point. Those overloads are safe because
they name a type this format owns: `[SnagRecord]`, `[LoopSpanChangeRecord]`. `String`, `Int` and
`Bool` are not owned by anything, so an overload on one would silently default *every* missing string
in *every* `Codable` type in the app — the blast radius D5 refuses, in a wider form.

So the rule now has two halves, both in `ArchiveCoding.swift` beside the overloads:

- an additive **collection** takes a named `KeyedDecodingContainer` overload;
- an additive **scalar** is declared `Optional` and read through `??` at its call sites.

Either way it is a per-field decision taken once, in the change that adds the field.

### D4 — `schemaVersion` does not move, and `SchemaVersionGate` is untouched

Nothing changes meaning. A file with the key reads as it always did; a file without it reads as a
reference that is a link rather than a picture, which is what the absence meant. A v1 file from last
month and a v1 file from today are both v1 and both read — the same reasoning as ADR 0205 D4.

### D5 — absent and empty are the same reading, deliberately

`nil` does not become a third state. A reference with no attachment name is a link, and the two ways
of saying so — the key absent, or the key present and empty — are not distinguished anywhere, in the
export path or the restore path. Giving `nil` its own meaning would invent a distinction that no
writer has ever produced and that no reader could act on.

## Consequences

- The archive format has no field left that fails a whole backup on its own absence. The rule from
  ADR 0205 D5 now covers every shape a new field can take, rather than the one shape that happened to
  come up first.
- `docs/backlog.md` loses the entry that parked this against "the release that first puts an archive
  in a player's hands". It is done before that release rather than at it.
- The test is built by **encoding a real archive and renaming the key**, as ADR 0205's is, and for
  the same reason: a hand-written JSON fixture has to name every key the format requires, so it goes
  stale as the format grows and then fails for the wrong reason. Its negative control was run — with
  the field back to `String = ""` the decode dies with `keyNotFound` at `songs[0].references[0]`,
  which is the bug, observed.
- What this does **not** do is make the next field safe by itself. Nothing mechanical catches an
  additive field declared the wrong way; the doc comment in `ArchiveCoding.swift` and these two tests
  are the whole of it. A check that walks the record types and fails on a non-optional with a
  declaration default is the obvious next thing and is not built here.
