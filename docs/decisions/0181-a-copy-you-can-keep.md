# ADR 0181 — a copy you can keep

- **Status:** Accepted
- **Date:** 2026-08-23 (`pocket-283-a-copy-you-can-keep`)
- **Relates to:** ADR 0150 (take sharing — **superseded in part**, see §7), ADR 0148 (Red Moon owns
  its song copies), ADR 0069 (practice takes and their retention), ADR 0151 (a take outlives its
  loop), ADR 0090 (stable `uid`s, never `persistentModelID`), ADR 0117 and ADR 0070 (a record, never
  a grade), ADR 0162 (the Settings hub this adds a destination to), ADR 0165 (the manual quotes the
  app), ADR 0120 (one third-party dependency, pinned), ADR 0182 (storage, which shares this screen)
- **Schema:** none. No `@Model` changed, no field added, no migration. The archive is a separate DTO
  tree, which is the whole point of §2.

## Context

Everything a player builds in Red Moon lives in one SwiftData store plus two directories of audio in
Application Support. There is no sync, no server, and — until this ADR — no way out. A blind-spot
review on 2026-08-22 found that the app had **zero** file-out machinery: no `ShareLink`, no
`fileExporter`, no `Transferable`, no `UTType` anywhere in `Pocket/`.

Two consequences follow, and both are already being paid.

**A lost phone without a backup is a lost library.** Not just songs — those can be re-imported — but
years of journal entries, every loop with its mastery and its ramp settings, every take, every
moment pinned inside a take. None of it exists anywhere else.

**The schema is frozen against destructive changes** (`schema-freeze-audit`, 2026-08-07) precisely
because a bad migration is currently unrecoverable. That freeze is a real tax on every subsequent
ADR, and it is levied by the absence of an export rather than by anything about the schema itself.

CloudKit sync is the real answer and it is Phase 4. This is the cheap thing that can ship now.

## Decision

**`Settings ▸ Your data ▸ Export` writes everything the player has built into one zip and hands it
to the system share sheet.**

### D1 — one new destination, and it is not a new word

`Your data` joins the Settings hub, taking it from nine shipping rows to ten.

The name already exists in two places: `FAQEntry.privacy` is titled *"Your data"* and so is
`docs/manual/privacy.md`. Inventing a tenth word for a concept the app has named twice would be the
expensive kind of tidy.

It sits in the **unheaded bottom group**, above Privacy — not under *Preferences*. ADR 0162 D2 groups
by *"what am I trying to change?"*, and an export changes nothing. It belongs beside Privacy and
Help & About, the other two rows you visit to find something out.

The row carries a trailing value (0162 D3) because one number dominates the destination: what Red
Moon is holding on disk. It is a real measurement, so it starts blank and fills in. A hub row that
guessed would be worse than one that waits.

**One destination, not two.** ADR 0182's storage section lands on this same screen, because export
and storage are halves of one question — and because the number that says how much space your
recordings take is the same number that says how big your archive will be.

### D2 — a separate DTO tree; no `@Model` becomes `Codable`

`Pocket/Core/Export/` holds a parallel value tree — `PracticeArchive` and its records — built by
`ArchiveBuilder` from live models.

Making the models `Codable` would have been fewer files and is wrong three times over: SwiftData will
not persist a `Codable` attribute; the models carry installation-scoped state that must never leave
the device (`Song.bookmark`); and a class graph with both cascade *and* nullify relationships has no
single correct serialisation. The DTO tree is also where the rules about what may cross into an
archive can be **written down and tested**, which is the part that matters most.

Cascade relationships nest (a song owns its loops, a routine its blocks, a take its moments) because
the owner's deletion takes them along, so they have no life of their own to record. Nullify
relationships are written as ids, because both ends outlive each other — ADR 0151 exactly.

### D3 — six rules the builder holds, and each one is a test

| Rule | Why |
|---|---|
| `Song` is keyed on `sourceID`, not `uid` | It is the one model with no `uid`, and `sourceID` is what its audio file on disk is named for. |
| `Song.bookmark` never crosses | A security-scoped bookmark encodes access granted to one installation. Exporting one ships a value guaranteed to be dead wherever it is read — the entire premise of ADR 0148. |
| `Song.amplitudes` never crosses | 512 `Double`s per song, derived, re-extractable, and would dominate the file. |
| The three JSON-in-`Data` columns are decoded and nested | `Exercise.templatePayload`, `SavedChord.voicingData`, `JournalEntry.practisedUnitsRaw`. Real nested JSON, never base64 — an archive nobody can read is a backup nobody can check. |
| Stored properties only, never computed ones | `RoutineItem.canRecordTake` (ADR 0180 D2), `Song.hasImportedAudio`, `RoutineItem.isOrphaned` are all **derived**. Exporting one freezes a rule that is meant to be re-derived. |
| No computed statistics | ADR 0117 and ADR 0070 permit a count and a date and refuse anything that grades. An archive emitting a streak would breach a standing product decision in a file the player keeps forever. |

`SessionRecord` (`Pocket/Core/Stats/`) was already a flat, `Sendable`, export-shaped record one-to-one
with `PracticeRun`'s columns, and `PracticeRun.record` already produced it. Adding `Codable` was a
one-word change; writing a parallel DTO beside it would have been two things to keep in step.

### D4 — every collection is sorted, and none of them by chance

Two exports of an unchanged library must produce byte-identical JSON. Otherwise a player cannot diff
two archives to see what changed, and a test cannot assert on output without sorting it first.

Natural orders are used where the app already has one — a loop's position in its song, a block's
place in its routine, a link's authored order (ADR 0167) — and `uid` breaks every tie. The encoder
uses `.sortedKeys` for the same reason.

### D5 — a zip, staged with hard links

JSON alone cannot carry audio, so the archive is a directory that gets zipped:

```
red-moon-practice-2026-08-23/
  practice.json
  takes/
    <recording-uid>.m4a
```

`practice.json` names each take by `fileName`, and that name is the join to the file in `takes/`.

**Zipping is Foundation's.** `NSFileCoordinator.coordinate(readingItemAt:options: .forUploading)`
hands back a zipped copy of a directory. Aptabase is this project's one third-party package and
`project.yml` pins it deliberately (ADR 0120); spending that restraint on a dozen lines of zip would
be a bad trade.

**Takes are staged with `linkItem`, not `copyItem`.** A copy would double the recordings on disk
before the zip is even written — on a library that is mostly audio, that is the difference between an
export that works on a full phone and one that does not. Both paths are inside the app container and
therefore on one volume, which is the condition a hard link needs; `copyItem` remains as a fallback
for the case where it is not. This is asserted by comparing inodes, because it is otherwise
invisible: a copy produces an archive that is correct in every respect except the one that matters.

The folder is dated in the **player's** time zone while `exportedAt` inside the file is ISO-8601 in
GMT to the millisecond. GMT is right for a timestamp and wrong for a name a person reads: exporting
at half past eleven at night should not produce an archive dated tomorrow.

### D6 — preparing and sharing are two taps

`ShareLink` needs its file to exist before the row is built, and building an archive of a real
library is not instant. So *Prepare a copy* does the work and reports what it produced, and only then
does a share row appear, showing the archive's actual size.

The alternative — one button that spins silently and then throws up a share sheet — hides both the
cost and the result. Two taps also make the size honest: the figure before the tap is an estimate
("About 412 MB") because zip compression is not predictable from the inputs, and the figure after it
is the real one.

Reading is on the main actor because a `@Model` is not `Sendable`; `ArchiveBuilder.snapshot` returns a
plain value, so encoding, staging and zipping — all of the expensive work — run on a detached task.
That is `SongImporter`'s split (ADR 0148 §6) turned around, for a job whose costly end is the writing
rather than the reading.

### D7 — *Include recordings* is a toggle, defaulting on

Takes are the irreplaceable half and the large half. The default therefore produces a **complete**
archive. Someone who only wants their notes gets a small file, and their takes are still fully
described in it — every note, every moment, and the name of the audio that is missing.

Turned off, no `takes/` directory is written **at all**. An empty one reads as "your recordings are
gone", which is the opposite of what happened.

It is deliberately **not** `@AppStorage`. This is a choice about one export, not a standing
preference.

### D8 — the export is cleaned up, on both paths

A stranded archive is a second full-size copy of the library sitting in `tmp/`, where the player can
neither see it nor reclaim it. So: the staging tree and the zip live inside one working directory,
leaving the screen deletes it, preparing again deletes the previous one, and a **failure** deletes
the partial one on its way out — that last is the path that leaks, because the caller never gets a
handle to clean up with.

### D9 — a missing take file is reported, not fatal

A take can outlive its audio. The export carries on, and the screen says how many were missing rather
than failing the whole archive over a gap the player can do nothing about.

## §7 — what this does and does not decide about ADR 0150

ADR 0150 is *Proposed — parked pending legal advice*, and says in its own status that it **must not
move to Accepted on the evidence currently in it.** That remains true. This ADR is deliberately
explicit rather than quiet about the line it takes.

**It takes the narrow route 0150 itself drew.** 0150 §29-43 already reasons that *export* — a file
handed to the OS share sheet, never received, stored or served by us — carries none of the hosting
obligations, and that "none of the above attaches". A self-export archive sits squarely in that half.
What this ADR adds is that a **whole-archive backup the player keeps for restore** is a materially
weaker case on the App Store *Content Rights* axis than a single take one tap from Messages: the
artefact's purpose, its shape and its natural destination are all restore, not distribution.

**It does not unpark per-take sharing.** No `ShareLink` on a take row, no share action in
`TakesSheet`. 0150 stays *Proposed* for that question and its open questions (§92-110) stay open.
0150's status becomes **superseded in part by 0181, for self-export only**.

**It records the decision as the owner's, and dates it.** The decision to proceed for the
self-export case was taken on 2026-08-22. No legal review happened. The rights questions 0150 raises
— the EULA, the Content Rights declaration, commercial audio captured through the mic — are
**scoped**, not resolved, and this ADR should not be read as evidence that they were.

**It carries 0150's speaker-bleed warning across.** 0150 designed that warning against ADR 0069's
route classifier. At archive scale it becomes one honest line on the export screen and in the manual:
a take recorded next to a playing song may have picked that song up through the mic. Cheap, and it is
the thing 0150 asked for.

**One claim re-verified rather than assumed:** `docs/site/redmoon-privacy.html` states *"the app has
no audio upload path."* A share sheet is not an upload path — the app transmits nothing and does not
know where the file goes — so the sentence stays true. 0150 §118-121 banks on it explicitly, which is
why it was checked rather than taken for granted.

## Alternatives considered

**Make the `@Model`s `Codable` and encode the graph directly.** Rejected — D2. SwiftData will not
persist a `Codable` attribute, and the bookmark would have to be excluded by hand anyway, which is
the same rule with nowhere honest to write it down.

**A per-item share instead of a whole archive.** That is ADR 0150's question, and it is parked. It is
also the wrong shape for the problem this ADR is solving: a player who loses their phone needs
everything, not the ability to have exported each take individually beforehand.

**Add a zip library.** Rejected — D5. Foundation does it.

**Ship import at the same time.** Rejected as scope. A merge-vs-replace importer with id collisions
and cross-version schemas is its own ADR. `schemaVersion` in `practice.json` is the seam that keeps
that door open; nothing else here needs to anticipate it.

**Write the archive to a browsable Documents directory instead.** Rejected: it would need
`UIFileSharingEnabled` and `CFBundleDocumentTypes` in `Info.plist`, which exposes the whole container
to Files for the sake of one file the share sheet can already deliver. AGENTS.md's rule against
permissions the app does not exercise applies to capabilities too.

## Consequences

- **The schema freeze can be reconsidered** — not lifted by this ADR, but the argument for it was
  "a bad migration is unrecoverable", and that is now false for anyone who has taken an archive.
- **Export without import is half a loop**, and the manual says so in as many words. This is a copy
  the player keeps, not a restore. The importer is in `docs/backlog.md`.
- **Every future `@Model` field is now also an archive decision.** A stored field added without a DTO
  field silently stops being exported. The mapping tests are the guard; they are not automatic.
- **`SessionRecord` is now part of a file format.** It was internal; it is now the shape of
  `practiceRuns` in every archive anyone has taken. Changing a field's meaning is a `schemaVersion`
  bump, not a refactor.
- **The `Your data` row makes `check-manual.py` C1 load-bearing in a new place.** Ten shipping rows,
  and the script's own three "nine"s were updated with it.
- **This is the app's first file-out surface.** `Info.plist` is unchanged and the container stays
  un-browsable; nothing about it should be read as a precedent for opening that up.
