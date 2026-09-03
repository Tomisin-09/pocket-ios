# ADR 0188 — a copy you can read back, and a routine you can hand over

- **Status:** Accepted — **S1 built** (2026-09-03), S2 and S3 not started. Three slices (S1–S3),
  each independently shippable. **S1 and S2 are additive-only and touch no existing row**; the
  archive door in S3 is the one that reads a file the app did not write in this installation, and it
  is deliberately last.
- **Date:** 2026-09-03 (`pocket-293-import-both-doors`)
- **Relates to:** ADR 0181 (the export this closes the loop on — **amends its
  `CFBundleDocumentTypes` alternative, see D3**), ADR 0182 (the orphan sweep this must not trip,
  D7), ADR 0150 (take sharing, still parked — **D4 stays on 0181 §7's side of the line**),
  ADR 0090 (stable `uid`s, which become the join key here), ADR 0070 and ADR 0117 (a record, never
  a grade — the reason D5 drops mastery), ADR 0120 (one third-party dependency, pinned — the
  restraint D8 spends nothing of), ADR 0148 (Red Moon owns its song copies, which is why no audio
  crosses in a share), ADR 0151 (a take outlives its loop), ADR 0127 / 0177 / 0178 (the routine
  this hands over), ADR 0162 (the Settings hub), ADR 0165 (the manual quotes the app)
- **Schema:** none. No `@Model` changes and no field is added. Both doors write rows through the
  ordinary initialisers, which is what makes this ADR safe to build under the freeze — and what
  lets it argue, in Consequences, that the freeze can now end.

## Context

ADR 0181 shipped `Settings ▸ Your data ▸ Export` and said, in its own Consequences, that **export
without import is half a loop**. `docs/manual/privacy.md:36-38` says the same thing to the player in
as many words: *"The app cannot read an archive back in — it is a copy for you, not a restore."*

That sentence is the whole of this ADR's context. The machinery to read one is almost entirely
present and unused:

- `ArchiveBuilder.decode(_:)` already exists (`Pocket/Core/Export/ArchiveBuilder.swift:121-129`),
  carrying the fractional-seconds date strategy that Foundation's stock `.iso8601` would silently
  truncate. It is called only by tests, and its own comment says an importer was out of 0181's scope.
- `PracticeArchive.schemaVersion` is written into every archive and **read by nothing**
  (`Pocket/Core/Export/PracticeArchive.swift:31-33`). Its doc comment says it exists so that "an
  importer, whenever it is built, can tell what it is looking at instead of guessing from which keys
  happen to be present."

**But "import" is two jobs wearing one word, and conflating them is the mistake this ADR exists to
avoid.**

*Restore your own archive* is whole-library, and the file is trusted because you made it. *Receive
someone else's routine* is one unit, and the file is not trusted at all: it carries ids that mean
nothing here, blocks naming exercises you do not have, and references to audio that does not exist on
this phone. They share a decoder and almost nothing else.

The second one is also the one the product positioning actually asks for.
`docs/positioning.md` §5 argues the routine is what a teacher hands over, and §1's multiplier thesis
says a teacher handing over a session is the purest form of the product working. Today `Routine` has
no export, no import and no share, and `docs/backlog.md` has carried *"a routine cannot be given
away"* as thesis-critical since 2026-08-16.

## Decision

**Two doors, one decoder, and an asymmetry of trust that is the organising principle rather than an
implementation detail.**

### D1 — the trust asymmetry, stated once

Everything below follows from this table, and where a rule looks inconsistent between the two doors
it is this table being obeyed.

| | Restore your archive | Receive a routine |
|---|---|---|
| Who wrote the file | you | someone else |
| Scope | the whole library | one unit and what it needs to run |
| `uid`s in the file | **yours**, and meaningful here | meaningless here |
| On a `uid` that already exists | **skip it** — you already have this row | **mint a new one** — it is a different thing that happens to collide |
| Repeating the import | idempotent by construction | produces a second copy, on purpose |
| Destructive? | **no** | **no** |

The last row is the one that removes most of the risk in this ADR, and D6 argues it.

### D2 — `schemaVersion` becomes load-bearing, and this is its first reader

Both doors read `schemaVersion` before anything else and branch three ways: **equal** proceeds,
**lower** migrates (there is nothing to migrate at v1, and the branch exists so that the first time
there is, the door already has somewhere to put it), **higher** refuses.

A refusal names the cause in a sentence the player can act on — *this archive was made by a newer
version of Red Moon; update the app and try again* — rather than reporting a decode failure. A file
from the future is the one error case here that is entirely predictable and entirely the app's fault
to explain well.

### D3 — one file type for handing practice over, and it is declared

A shared routine travels as **`.redmoonpractice`**: plain JSON, the same record shapes as
`practice.json`, the same `schemaVersion`, plus a `kind` discriminator whose only value today is
`routine`.

**Why a `kind` rather than a `.redmoonroutine` extension.** `docs/backlog.md` describes the receiving
job as *"a teacher's routine, a friend's exercise"*. An extension that names the payload forces a
second file type, a second `Info.plist` entry and a second door the first time an exercise share
ships. A discriminator inside one type costs one field now and nothing later.

**This amends ADR 0181's last "Alternatives considered" entry, and should be read against it.**
0181 rejected `CFBundleDocumentTypes` on AGENTS.md's rule against capabilities the app does not
exercise. That rejection was right for what it was deciding and does not reach this case:

- 0181 was weighing **`UIFileSharingEnabled` plus `CFBundleDocumentTypes`** in order to write an
  archive into a browsable Documents directory. The objection was to *exposing the whole container
  to Files for the sake of one outbound file the share sheet could already deliver*.
- This ADR adds **`UTExportedTypeDeclarations` and `CFBundleDocumentTypes` only**, and **not**
  `UIFileSharingEnabled`. The container stays un-browsable. What is declared is one file type the app
  genuinely opens, which is precisely the capability AGENTS.md's rule protects: the app exercises it
  on every receive.

Without the declaration, a teacher's file cannot be opened by tapping it in Messages, Mail, Files or
AirDrop — and "the player must first know to go looking for it inside the app" is not a teacher
handing a session over. The in-app `.fileImporter` ships too, following
`Pocket/UI/ReferenceAttachmentPresentation.swift:111`, but it is the second door, not the only one.

`Pocket/Resources/Info.plist` is hand-maintained and XcodeGen is deliberately kept away from it
(`project.yml:61-65`); these keys are added there by hand, with the same care as the usage strings
already in it.

### D4 — what a shared routine carries, and what it must not

Reuses `RoutineRecord` / `RoutineItemRecord` (`Pocket/Core/Export/PracticeArchive+Session.swift`)
unchanged. On top of them:

| Carried | Not carried | Why |
|---|---|---|
| the routine: name, notes, blocks, order, reps, planned minutes, kind | `lastPracticed`, `isFavorite`, `presetSlug` | they are facts about the sender's practice, not about the routine |
| every **exercise** a block names, **inline** | `mastery`, `commandTempo`, `commandNotesPerBeat`, journal, takes | D5 |
| the block's `loopRunMode`, `recordsTake` | `canRecordTake`, `isOrphaned` | derived — ADR 0181 D3, and the reason is already written into `PracticeArchive+Session.swift:39-41` |
| a **named** placeholder for loop and song blocks | the loop, the song, any audio | below |

**Loop and song blocks cannot cross, and the file says so rather than dropping them.** A `loopUID` is
meaningless without the song that owns it — `LoopRecord` nests inside `SongRecord` and carries no song
key, and a loop's bounds are fractions of a song whose audio never leaves the device (ADR 0148, ADR
0181 D3). So such a block arrives as exactly what the app already knows how to draw: a block whose
unit did not resolve, `RoutineItem.isOrphaned` (`Pocket/Core/Models/Routine.swift:302-304`), which
the player is shown and can fill in with their own material. Silently dropping them would hand over a
routine that is quietly shorter than the one that was sent.

**No `Recording` crosses, ever.** ADR 0181 §7 keeps per-take sharing parked behind ADR 0150's
unresolved legal questions, and this ADR does not reopen them: a routine share carries no take audio
and no take rows.

### D5 — a received exercise arrives the way a duplicated one does

`Exercise.duplicated(named:)` (`Pocket/Core/Models/UnitDuplication.swift:68-94`) already drops
mastery, `lastPracticed`, `isFavorite`, `presetSlug`, journal entries and recordings. **A received
exercise takes exactly that path.** Inheriting the sender's measured command tempo would hand the
receiver a number ADR 0045 defines as *measured*, that they did not measure — a grade arriving with
someone else's name on it, which ADR 0070 rules out on the app's own side and should not permit
through a side door.

The teacher's *shape* crosses: the drill, the rhythm, the planned minutes, the notes. The teacher's
*achievement* does not.

### D6 — neither door destroys anything, and there is no "replace"

The obvious design for restore is merge-vs-replace. **This ADR ships only merge**, and the reasoning
is worth stating because it is what makes the rest cheap:

- The real restore — a lost phone, a new device — happens into an **empty library**, where merge and
  replace are the same operation.
- A restore into a populated library is the only case where they differ, and there "replace" means
  deleting rows the player did not ask to delete, from a file whose contents they cannot see first.
  That is the unrecoverable operation the schema freeze exists to prevent, arriving through a new
  door.
- Skipping a row whose `uid` already exists (D1) makes restore **idempotent**: running it twice
  produces the same library, which is the property that actually makes a restore trustworthy.

A player who genuinely wants to replace their library can delete it and restore into the empty one.
That path is two deliberate steps, both visible, and neither of them is this ADR inventing a
destructive button.

### D7 — the row is written before the file, and the sweep is why

ADR 0182's `OrphanSweep.run` builds its referenced set from **every row in the store**
(`Pocket/Core/Storage/OrphanSweep.swift:29-41`). A file written into `Recordings/` or `References/`
before its row exists is, for that window, an orphan by the sweep's own definition — and *Reclaim
space* is a button the player can press at any moment.

So: **write the row first, or write row and file in one transaction.** Never the file alone. This
applies to reference attachments on a restore and is the reason the leaf name has to be rewritten:
attachment files are `<uid>.<ext>` in one flat directory, so a preserved uid collides with an
existing attachment and a new uid means `attachmentFileName` is rewritten as the row is made.

### D8 — the zip reader is ours, and it only ever reads archives we wrote

`NSFileCoordinator` gives zip-**out** and has no read side; Foundation has no public unzip on iOS.
Two ways forward, and the third-party one is refused for the reason ADR 0120 already gives — Aptabase
is this project's one pinned dependency, and spending that restraint here would be the same bad trade
0181 declined for zipping.

So the archive door carries a **minimal reader scoped to archives this app produced**: stored and
deflated entries, no encryption, no spanning, no ZIP64. `libcompression` provides raw inflate.

This has a consequence that must be written down or it will be discovered the hard way: **the
export's zip method is now part of the file format.** ADR 0181 D5 chose `.forUploading`; changing it
is no longer an implementation detail, and the reader must be tested against a real archive the
current exporter wrote, not against a fixture.

### D9 — what lands is shown before it lands

Both doors present what they found before writing anything: how many of each kind, what will be
skipped as already present (restore), what did not resolve and will arrive as an orphan (receive).

A receive is one unit and its summary is small enough to read; a restore's is a count per kind. The
alternative — importing and then reporting — is the same information delivered after the point where
the player could have said no.

## Slices

**S1 — hand it over. Built 2026-09-03.** `Routine` → `.redmoonpractice`, `ShareLink` in the routine
detail screen's toolbar, the UTType declaration. Closes the *sending* half of `docs/backlog.md`
Routines item 4. No import yet, which means it is shippable and testable on its own: the file it
writes is the fixture S2 is built against.

**Two corrections this slice made to the text above, both worth reading:**

- **The document-type declaration is not part of S1.** `CFBundleDocumentTypes` declares the app a
  *handler* — it is what puts Red Moon in the system's Open-with list — and until S2 there is nothing
  behind that door. Shipping it here would advertise a capability the app does not exercise, which is
  exactly what AGENTS.md forbids and what D3 spends its length defending against. **S1 declares
  `UTExportedTypeDeclarations` only**; the handler declaration lands with S2, the code that honours
  it. This narrows D3's Info.plist change rather than reversing it.
- **D5's "exactly that path" is loose, and the tables are right.** `Exercise.duplicated(named:)`
  *keeps* `commandTempo` and `commandNotesPerBeat` — correctly, since a duplicate stays in the
  library that measured them. A share does not, so the built path is duplication's drops **plus**
  those two and `linkedSongIDs`, which is what D4's table and D5's own argument already say.

**One thing S1 deliberately does not carry, which this ADR did not decide:** references. Half of them
are attachments (ADR 0167 phase 2) whose bytes stay on the sender's device, and carrying only the
URL-backed half is a call D4's table does not make. `SharedPracticeBuilder` clears them in one line
that is easy to reverse once the call is made.

**S2 — receive one.** Both doors (tap-to-open and `.fileImporter`), D5's duplication path, D9's
preview. Closes practice-support item 2.

**S3 — restore an archive.** The zip reader, the uid-skip merge, the attachment rewrite. Closes *An
importer to close the export loop*. Largest, last, and the only slice that reads a zip.

## Alternatives considered

**Two ADRs, one per door.** Rejected in planning by the owner. They share a decoder, a
`schemaVersion` seam and one trust question that is only legible when both are on the page — D1 is a
table that cannot be written in either document alone.

**Ship replace alongside merge.** Rejected — D6. It is the only destructive operation either door
could perform, its real use case is indistinguishable from merge, and it would put an unrecoverable
button behind a file the player cannot inspect.

**Make the shared routine an archive-shaped zip.** Rejected: it would make S2 depend on the zip
reader that S3 exists to build, inverting the slice order for no gain. A shared routine carries no
audio (D4), so it has nothing a zip is for.

**Match a received exercise to an existing one by name and reuse it.** Rejected. Two exercises called
"Spider Walk" are not necessarily the same drill, and merging them silently rewrites the receiver's
own material — the exact non-additive behaviour D1 forbids on the untrusted door.
`RoutinePresets.makeRoutine` resolves seeded blocks by name (`RoutinePresets.swift:83-104`), but it is
resolving against exercises *it seeded itself* in the same pass, which is a different situation.

**A `.redmoonroutine` extension instead of a `kind` field.** Rejected — D3.

**Add a zip library.** Rejected — D8, on ADR 0120's grounds.

## Consequences

- **The schema freeze can end, and this ADR is the argument.** The freeze (2026-08-07) rests on "a
  bad migration is unrecoverable". 0181 made that false for anyone holding an archive; this makes it
  false for anyone who can *read one back*. The freeze is recorded only in memory and
  `docs/backlog.md:835` and has never been an ADR — **ending it is a separate decision and should be
  written as one**, not assumed to have happened here.
- **`docs/manual/privacy.md:36-38` becomes wrong on the day S3 ships** and must change in the same PR.
  It currently tells the player the app cannot read an archive back in.
- **Every future `@Model` field is now an import decision as well as an export one.** 0181's
  Consequences noted a field added without a DTO field silently stops being exported; it will now
  also silently fail to restore. The mapping tests remain the only guard.
- **The app declares a file type for the first time.** `CFBundleDocumentTypes` is a submission-visible
  change and appears in App Store Connect. `UIFileSharingEnabled` is **not** added and the container
  stays un-browsable — nothing here should be read as a precedent for opening it up.
- **The export's zip method is part of the file format** (D8).
- **A shared routine is a new user-facing artefact with the brand rule attached.** The type
  description the system shows is *Red Moon practice*, never *Pocket*; the UTType identifier is
  derived from the bundle id and needs a line-scoped lint suppression where it is declared.
