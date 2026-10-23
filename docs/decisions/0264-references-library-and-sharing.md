# ADR 0264 — References: a library in the Toolkit, and sharing into Red Moon

- **Status:** Accepted. **Slice 1 built** 2026-10-20 on `pocket-378-keep-references` (D1, D2's
  delete rules, D7), with ADR 0263's free line on the same branch, merged as #370. **Slice 2 built**
  2026-10-20 on `pocket-379-references-library` (D3, D4, D5 without its slice 3 actions, D6's rules as
  pure logic, D11, D2's toast line). **Slice 3 built** 2026-10-20 on `pocket-380-references-attach`
  (D5's *Attach to…* and *Start an exercise from this*, over D6's rules). **Slice 4 built** 2026-10-21
  on `pocket-381-save-to-red-moon` (D8, D9, D10, D12: the share extension), checked on the simulator,
  and from Safari on a device once D10's signing was done; the other apps are still to check on a
  device. See §Build notes. Decided with Tomisin on 2026-10-20, from a nine-screen mockup
  (canvas *Red Moon References*). The two questions it first left open were settled the same day,
  with the recommended answers (D11, D12). It lands **before 1.4**, all four slices including the
  share extension. Tomisin: *"we're in no rush to launch, I'd rather we have it in place before we
  launch."* The library comes first, then the share extension.
- **Date:** 2026-10-20
- **Amended by:** ADR 0275 (2026-10-23) — **D4**: *Not filed* then *Everything* is now the default of
  three layouts, chosen from an ⋯ menu; the library can also be grouped by site or by where each source
  is used. Slice 2's build note 2 (no ⋯ until there was an option) is met by it. The rest of D4 stands.
- **Amends:** ADR 0167 — **The model**: an owner is now *at most one* of the four, not exactly one,
  and a reference with none is *kept for later* (D1). The owners' inverses become `.nullify`, not
  `.cascade`, so deleting an owner keeps its references (D2). With that, **Consequences**' "deleting an
  exercise now deletes its links silently" is reversed, and phase 2's note that `OrphanSweep` is the
  *primary* collector of reference files no longer holds: it is a backstop again, as it is for songs
  and takes. **The 2026-08-19 revision's hold menu**: *Delete* on an owner's reference becomes
  *Remove*, which sends a source used nowhere else to *Not filed* instead of deleting it (D11).
  Everything else in 0167 stands: http and https only, no title fetching and no thumbnails, the
  `PasteButton`, and nothing on the run screens.
- **Relates to:** 0263 (keeping is free, so References is free: D6 here) · 0151 (a take outlives its
  loop, the same delete-rule change, and its precedent for migration cost) · 0186 D9 (the widget's
  snapshot, the pattern D9 here follows) · 0183 D1 (a snapshot holds only what it renders) · 0235 D2
  and D6 (the Toolkit's rows, and the tile beside Toolkit) · 0128 (one insert path for a new
  exercise) · 0126 (toolbar grammar) · 0181 (Your data) · 0019 (the undo toast)
- **Schema:** none in shape. Four delete rules change (D2), which 0151 showed leaves the store as it
  is. The archive gains one optional field (D7).
- **Positioning:** `docs/positioning.md` §1. Tomisin: *"I think this would be the final piece for the
  app, because it truly makes the app interconnectable with a user's sources, making a strong case
  for it being a multiplier."*

## Context

ADR 0167 lets a player say where they learned something: a link or a file on an exercise, a song, a
loop or a routine. It has two gaps, and both came up while sharing a YouTube video on a phone.

1. **You can only keep a source once you've made the thing it's for.** A lesson found today, before
   its exercise exists, has nowhere to go. It ends up back in a watch history, which is the problem
   0167 set out to fix.
2. **Getting it in is slow.** You copy the link, open Red Moon, find the exercise, open its
   References, paste, and name it. Every other app on the phone takes a link from the share sheet in
   two taps.

Tomisin, on the share sheet: *"you know when you share a video from youtube, you get the following
options that pop up. Is this something we could do for Red Moon?"* On *Keep for later*: *"It's even
brought about the idea of having something like a reference library in the app, within the
toolkit."*

**The hard part is that a share extension can't see the library.** It runs as its own small app,
with its own storage. Red Moon's store sits in the app's private Application Support (0186 D9 found
the same for the widget), so the extension can't list the exercises or write a reference. Moving the
store to a shared container would migrate every player's whole history to power a picker, which
0186 D9 already refused. The approach most apps take, and the one Tomisin chose, is that the app
gives the extension a list of names, and the extension hands back what to save (D9).

## Decisions

### D1 — A reference can be filed nowhere

A reference with no owner is **kept for later**. That is a state, not an error: the library's
*Not filed* section is where it lives (D4). 0167's "exactly one owner" becomes **at most one**.
`ReferenceLinkStore` stays the single write path. It gains adding with no owner, filing an unfiled
reference to an owner, and copying one to a second place (D3).

### D2 — Deleting an owner keeps its references

Tomisin: *"Let's keep it in the library."* The four inverses (`Song.references`, `Loop.references`,
`Exercise.references`, `Routine.references`) become `.nullify`. A reference whose owner goes moves to
*Not filed*, note and file intact.

- **Why this reverses 0167.** 0167 called a reference *"a record of the owner"*, meaningless once the
  owner is gone. With a library it is a record of *where you learned something*, and that outlives
  the drill you made from it. The lesson is still the lesson. It is 0151's reasoning for takes and
  notes, reached from the other side.
- **The store keeps its shape.** Changing a delete rule moved nothing in 0151, and was checked on a
  device holding real rows. This gets the same device check, against a store with references on all
  four owner kinds.
- **The undo toast says so** when the owner had any: *"Deleted CAGED shape 2. Its 2 references stay in
  References."* A delete that keeps something should say what it kept.
- **Files stop being stranded.** 0167 phase 2 recorded that the cascade deleted reference rows
  without running any of our code, which left their files for `OrphanSweep` to find. The rows now
  stay, so the files are still referenced. The sweep already fetches every `ReferenceLink` row
  (`StorageSection`), filed or not, so no sweep change is needed.

### D3 — One row per use, grouped by its link

A source used in two places is **two rows**, one per owner, and each keeps its own note. Tomisin
accepted this over one shared row with many owners, which would mean a join model and a migration
for the same screen.

- **The library groups rows by `urlString`**, which the store already normalises (a scheme-less paste
  is read as `https`). A group is *filed* if any of its rows has an owner, and *not filed* if none
  does.
- **A file groups by the file it names.** A picture or a PDF has no link to match on, so a file
  attached in a second place is a second row naming the same file on disk, and the two are one
  source. *(Changed while building slice 3, from "files never group": see its build note 4.)*
- **An unfiled row whose link is filed elsewhere stays.** Its note may be the only copy of what the
  player took from that source on a drill they've since deleted. The source's screen lists it under
  *Kept for later*, beside the places it's used.

### D4 — References is a Toolkit row

- **A new `ToolkitSection`, `.references`**: *References*, subtitle *Where you learned it*, after My
  tabs and before the Tuner, because it is a thing you keep. Its trailing value is *N to file* while
  anything is unfiled, otherwise the count of sources. It can be the tile beside Toolkit (0235 D6),
  like any row.
- **The library screen:** a search field, then **Not filed** (newest first), then **Everything**
  (newest first). A row shows the title, then the host or the file's kind and when it was saved,
  then *On Triad climb · Morning routine* in each owner's colour, then the note's first line.
- **The toolbar** is 0126's: `ellipsis.circle`, then **＋**. ＋ adds a link, a photo or a file, kept
  for later, through the same editor and pickers the owner sections use.

### D5 — A source's screen

Tapping a row opens the source:

- **Open link**, or the file's viewer, as 0167 has it;
- **What you took from it**: the note;
- **Where it's used**: each place with its own note, and any *Kept for later* row (D3);
- **Start an exercise from this**, the main action while the source is not filed. It runs New
  exercise (0128's one insert path) with the reference already attached. A source that isn't filed
  moves to the new exercise. One that is filed elsewhere is copied. Caption: *"New exercise opens with
  this link already attached."*
- **Attach to…** (*Also attach to…* once filed): the same owner picker as the share extension (D8);
- **Delete**: once filed in two places, *Delete from both places…*. It always confirms first, and
  names every place it will leave. Tomisin: *"I'm happy with this approach."*

### D6 — Free, with one line drawn inside it

References is free (0263 D2: it keeps). What it can attach to follows what the player can open:

- **Never bought:** *Keep for later*, a song or a loop. Exercises and routines are not offered, and
  the picker's footer says *"Exercises and routines come with the plan."* *Start an exercise from
  this* opens New exercise, which shows the wall (0256 D3). Tomisin: *"A free user won't have access
  to a lesson, so they wouldn't be able to share it."*
- **Lapsed** (StoreKit has seen a purchase: `hasBoughtBefore`): everything, with a lock and *"opens
  with the plan"* on exercises and routines. The reference attaches, and the exercise opens again with
  the plan. Footer: *"Your drills and routines are just as you left them. They open again with the
  plan."* (0263 D4's returning sentence). Tomisin: *"they'd still be able to attach it to a lesson,
  they just wouldn't be able to access that lesson."*
- **On the plan:** everything, no locks.

Lapsed and on the plan differ only in the lock, and nothing ever moves a player from *bought before*
back to *never bought*. So the extension's copy of the plan state can be stale without harm (D9).

### D7 — Backups carry references that aren't filed

`ArchiveBuilder` writes references only under their owners (songs, loops, exercises, sessions). An
unfiled reference would be missing from every export, which 0181 doesn't allow. The archive gains
**`unfiledReferences: [ReferenceLinkRecord]?`** at its top level. It is `Optional`, so an older archive
still decodes, and additive, so `schemaVersion` doesn't move, as with `folderMarkers`. Restore writes
those rows with no owner. Their files are staged into `references/` like any other reference's.

### D8 — The share extension: *Save to Red Moon*

- **What it accepts:** one web URL, or one picture, PDF, `.txt` or `.md` file, which are 0167's kinds.
  The activation rule names exactly those, with a maximum of one, so Red Moon doesn't appear for
  things it would refuse.
- **Its screen**, as drawn: *Cancel* and *Save*; the item with an optional *What you took from it*;
  then **Where it goes**. *Keep for later* is the default, then recent places (songs, loops,
  exercises, routines, most recently practised first), a search field and *Show everything*. D6's
  rules decide what's offered and what's locked.
- **Save writes and closes.** There is no *Open Red Moon*: iOS gives a share extension no public way
  to open its app, and the reference will be there the next time it opens.

### D9 — The extension never opens the store

Two files in an App Group container. Neither is the store:

- **The owner snapshot**, written by the app when it comes to the foreground and after an owner is
  added, renamed or deleted. It holds each song, loop, exercise and routine as its uid, kind, name,
  parent name (a loop's song) and when it was last practised, plus the plan state (*never*, *lapsed*
  or *on*). **Names and kinds only**: no notes, no history, no tempos. 0186 D9 and 0183 D1's
  discipline is that a snapshot holds only what its reader renders.
- **The inbox**, written by the extension: one small JSON file per save (the link or file name, the
  title, the note, the target's uid and kind, or none), plus the shared file's bytes copied beside
  it.
- **The app drains the inbox** on foreground, through `ReferenceLinkStore`, so the http/https rule
  and the attachment rules (0167 phase 2: downscaling, the 25 MB ceiling, the five-file cap) apply
  exactly as they do in the app. **Pictures are downscaled in the app, not in the extension**, which
  runs under a much tighter memory limit than an app.
- **Nothing is dropped.** If a target has been deleted since the snapshot was written, if it's full
  (five files), or if the player can't attach to it any more, the item lands in *Not filed* instead.
- **Pure where it can be.** Turning an inbox item into a write is a pure plan
  (`ShareInboxPlan`-style), unit-tested on values, as `PlanAccess` is.

### D10 — What a second target costs

These are the backlog's widget notes (`docs/backlog.md`, *Six things that will bite*), and they apply
unchanged:

1. **Signing**, the one part that can't be done in code: a second bundle id, an App Group, and new
   profiles. Fastlane's `match` is `readonly: true` and pinned to one id, so Tomisin registers the
   group and the id in the developer portal and the match repo is repopulated. CI builds unsigned and
   is unaffected.
2. **The lint rule that keeps "Pocket" out of user copy** covers only `Pocket/`, and so does
   `check-manual.py`'s C9. Keep the extension's sources under `Pocket/`, or widen both.
3. **The scheme builds only the app's dependency graph**, so the extension is embedded in the app or
   nothing builds it.
4. **Asset-catalog colours don't cross targets.** The colours move to a catalog both targets include.
   `Font.futura` needs nothing.
5. **`TempContainerFileManager` doesn't reach an App Group**, so the snapshot and inbox stores take
   their directory injected.
6. **No UI test can drive another app's share sheet.** The drain is unit-tested, and the extension's
   screen is checked in previews and on a device.

The App Group and the signing work are done once and shared with the parked widget (0186), which
needs both. This ADR doesn't unpark the widget.

### D11 — Removing a reference from one place

Today a hold on an owner's reference offers *Edit link* and *Delete*, and *Delete* is immediate
(0167, 2026-08-19 revision). With a library, **Delete becomes Remove** on an owner's References
section. Tomisin took the recommendation.

- **If the source is used nowhere else, it moves to *Not filed***, with its note and file. Nothing
  is lost, so nothing needs confirming.
- **If the same link is used elsewhere, this use's row goes**, and its note with it. The source
  stays in the library through its other places.
- **A file follows the same rule** (D3, as slice 3 left it). If nothing else holds it, it moves to
  *Not filed*, bytes and all. If another place holds it too, this use's row goes and the bytes stay
  for that place. Its bytes are never deleted from an owner's section.
- **The library is the one place a source is deleted for good** (D5), and it confirms first. That is
  D2's rule seen from the other side: nothing the player kept leaves Red Moon as a side effect.
- **The routine editor keeps its contract** (0167 phase 1, constraint 3): a Remove there waits for
  *Save*, and *Cancel* undoes it.

### D12 — Shared text with a link in it

Some apps share a sentence with a link in it, not a bare URL. The extension also accepts **plain
text**. It takes the first http or https link in it, found on the device by `NSDataDetector`, which
makes no request. Text with no such link isn't saved: the extension says *"There's no link in this to
save."* and offers only *Cancel*. The link then goes through the store's own rule (0167: a scheme-less
link reads as https, anything else is refused).

The title is whatever the sharing app hands over with the item, if it hands one over. It is never
fetched (0167), and the player can always type one. Tomisin took the recommendation.

## Build order

Before 1.4, one branch at a time, each merged on green before the next starts:

1. **Keep references:** D1, D2 (the delete rules and the device store check), and D7. ADR 0263's
   free line rides on this branch too. The toast's *"stay in References"* line waits for slice 2,
   because until then there is no References to point at.
2. **The library:** D3, D4, D5 (without *Attach to…*), D6's rules as pure, unit-tested logic, D11,
   and D2's toast line.
3. **Attach to…** and *Start an exercise from this*.
4. **The share extension:** D8, D9, D10 and D12.

Slices 1 to 3 need no new target and no signing work. Slice 4 waits on D10's signing step, which is
Tomisin's work in the developer portal and can be done at any time before it, alongside the App Store
Connect setup 1.4 already needs (0256 Consequences). 1.4's sandbox pass then covers the extension on a
device as well.

## Build notes — Slice 1 (2026-10-20, `pocket-378-keep-references`)

- **Built:** the four inverses nullify; `ReferenceLink.isFiled`; `PracticeArchive.unfiledReferences`,
  newest first, with its files staged; and restore landing those rows with no owner, skipping a uid
  the library already has, outside `rowCount`. The toast line waits for slice 2, as the build order
  says.
- **Tests:** the three cascade tests in `ReferenceLinkTests` are now nullify tests, and `isFiled` is
  checked on all four owners. `UnfiledReferenceArchiveTests` has 12. Nine are on uninserted models.
  Three are on an in-memory store, for the three lines that touch one: the export's fetch, the
  restore's existing keys, and its insert.
- **Mutants:** 19, in three batches with no two on one line, and every one failed a test. Five were
  caught only by tests added after the first checkpoint: `isFiled` without its song or loop clause,
  and the three store lines. The checkpoint commit's tests let all five through.
- **The store check (D2), on the simulator.** Main's build (`b62a752`) wrote a store, and main's code
  added a reference to a drill, a song, one of its loops and a routine. This branch's build was
  installed over it and opened it. It was the same store: its oldest history transaction predates
  the launch. The app ran for 30 seconds with no crash. Deleting the drill, the song (and with it
  the loop) and the routine through this branch's model left all four rows on disk with every
  owner key null. D2 named a device check. Tomisin took the simulator check in its place
  (2026-10-20: *"the simulator is fine"*).
- **A side effect, as D2 intends:** a temporary session (ADR 0243) replaced by the next Start now
  leaves any references on it not filed, where it used to delete them.

## Build notes — Slice 2 (2026-10-20, `pocket-379-references-library`)

- **Built:** the Toolkit row (D4), `ReferencesLibraryView` and `ReferenceSourceView` (D4, D5 without
  *Attach to…* and *Start an exercise from this*, which are slice 3), **Remove** on every owner's
  References section (D11), and the toast's second line on all four owners' deletes (D2): the
  Exercises, Routines and song libraries, and the loops panel, a song counting its loops' references.
  The rules are pure: `ReferenceLibrary` (grouping, sections, search, the row's value, the toast line,
  the delete dialog's words), `ReferenceRemoval` (D11's verdict), and `ReferenceAttachRules` over
  `PlanStanding` (D6, unused by any screen until slice 3). The store gains `remove(_:from:in:)`,
  `delete(_:in:)` for a whole source, and `KeepForLater`, a `ReferenceLinkOwner` with no list that lets
  the library's ＋ reuse the owner sections' editor and pickers with no owner. The per-owner
  `delete(_:from:in:)` is gone: nothing calls it once owners remove.
- **Decided while building, from what D4 and D5 leave open.** Each is small; each is a call to check.
  1. **A `bookmark`, not the books the mockup drew.** The Toolkit's own Home tile is
     `books.vertical.fill`, and this row can be the tile beside it.
  2. **No `ellipsis.circle` yet.** D4 names 0126's grammar but nothing for the menu to hold: the order
     is fixed and search covers finding. ＋ stands alone, as on My tabs, until there is an option.
  3. **Everything lists the sources not under Not filed**, as drawn, rather than every source again.
  4. **Every row says when it was saved**, as D4's text has it; the drawing left the day off the
     filed rows.
  5. **Edit writes a source's name and link to every row of it, and the note to one row.** D3 makes a
     source one name and one address with a note per place, so that is what Edit edits. With more
     than one row, Edit is a menu naming the places, because the note is the place's.
  6. **The delete button reads *Delete*, *Delete from both places…* or *Delete from all N places…***,
     by distinct places. The dialog always opens, and its message names them.
  7. **A row added and removed in one routine edit goes outright.** The routine editor holds every
     change until Save (0167 phase 1, constraint 3), so a link added and then removed before Save was
     never kept, and sending it to *Not filed* would keep it anyway. `remove` knows by the context's
     unsaved inserts, which only the routine editor's sandbox ever has.
  8. **Remove is a swipe as well as a hold**, red, as the other owners' row deletes are. The routine
     editor's edit-mode minus then reveals that same red *Remove*, not a system *Delete*: a row with
     swipe actions of its own shows them there. `.onDelete` stays for the editor's edit mode and calls
     the same `remove`. Seen on the simulator, minus to Remove to the row gone.
  9. **A source filed nowhere reads *Not filed yet*, however many rows it has, and lists each note
     under *What you took from it*.** D5 drew one row, but two are easy to reach: the same link on two
     drills, both deleted, keeps both rows and both notes (D2). Listing them under *Where it's used*
     drew two identical *Kept for later* rows and no place; with no place to tell them apart, a row
     with no note shows nothing, and Edit edits the newest. Found by a walk that saved one link twice.
- **Tests:** `ReferenceLibraryTests` (19), `ReferenceRemovalTests` (15, 8 on an in-memory store),
  `ReferenceAttachRulesTests` (5), with the two tests that called the per-owner delete moved onto
  `remove` and the library's delete, a removed picture keeping its file, the coordinator carrying the
  toast's line, and `ToolkitSectionTests` pinning the new row's place and stored name.
- **Mutants:** 34. The first 31 ran in three batches with no two on one line, each with a witness test no other mutant
  in its batch could fail. Every one failed its witness. Reading for mutants first found one line of
  dead code (an unfiled row handed back to the "elsewhere" list, which never counts it) and two guards
  that each hid the other; the line is gone and both guards have a test of their own. Three more
  after the walks: two on item 9's rule, and one on the search, rewritten as typed statements for CI's
  type-checker. All three failed their witness.

## Build notes — Slice 3 (2026-10-20, `pocket-380-references-attach`)

- **Built:** the source screen's *Start an exercise from this* and *Attach to…* (D5), and the owner
  picker they share with slice 4 (D8's list, D6's rules). The rules are pure: `ReferenceFiling` (move or
  copy, and the screen's words), `ReferenceDestination` (a place as a value, the shape D9's snapshot
  will hold) and `ReferenceDestinationPicker` (offered, locked, unavailable, *Recent*, *Show
  everything*, search). The store gains `attach`, over a `hold(_:)` on the owner protocol. *Start an
  exercise from this* runs `newExerciseFlow` with the row's uid on `NewExercisePlan`, and
  `finalise(in:)`, 0128's one insert path, files the source after the insert.
- **Decided while building, from what D5, D6 and D8 leave open.** Each is a call to check.
  1. **A tap attaches and closes.** D8's picker holds a choice until *Save*, because what the extension
     saves doesn't exist yet. Here it does, so the pick is the save, as a move-to-folder picker is.
  2. **No *Keep for later* in the app's picker.** The source is either kept for later already, or
     filed, where a second row with no place and no note would keep nothing.
  3. **Moved or copied** (D5's *"moves… is copied"*, made exact). A row kept for later moves, with its
     note. A filed link is copied as a new row with **no note**: each place keeps its own (D3), and
     the note copied from was written about somewhere else. A filed source that also has a row kept for
     later moves that row instead of copying a third. Of two rows kept for later (D2's two deleted
     drills), the newest moves.
  4. **A filed file is copied as a link is: a second row naming the same file.** First built as
     *Move to…*, with no new drill, because D3 said files never group. Tomisin asked *"could we simply
     duplicate files?"* Copying the bytes would have made a second source that looked like the first,
     and *Also attach to…* would have seemed to do nothing, because the screen it was tapped on would
     still show one place. So the copy shares the file, and D3 now groups files by the file they name
     (`ReferenceLink.sourceKey`). That gives a file what a link has: *Also attach to…*, *Start another
     exercise from this*, both places on its screen, and *Delete from both places…*. A PDF of 25 MB
     isn't stored twice. What follows from it:
     - **The bytes go with the last row naming them.** Delete, and a row never saved going outright,
       keep a file another row still names. If the store can't be read to check, the bytes stay for
       *Reclaim space* (ADR 0182) rather than going from under another place.
     - **Remove follows D11's link rule**: one use of a file filed elsewhere goes, and the bytes stay.
     - **Edit renames every row of a file**, as it writes a link's name to every row.
     - **No schema change.** Every file stored before this is named for its own row's uid, so no two
       share a name and the library groups them as before. Backups export each file once (the names
       are a set), and restore never overwrites a file already on disk. References don't travel in a
       shared practice pack, so there is no receive path to change.
  5. **A place it's already on is shown ticked and greyed, not left out**, so a search for it doesn't
     come back empty. A place with five files is greyed the same way for a file (0167 phase 2's cap).
  6. **Recent is the five places practised most recently.** A loop keeps no date of its own and takes
     its song's, as the routine editor's *Recently Added* does. A place never practised isn't recent,
     so a new library opens on everything, by kind: exercises, routines, songs, loops, as the Practice
     hub leads with drills. A song and its loops practised the same day list the song first.
  7. **Temporary sessions (ADR 0243) are not offered**: the next Start replaces them.
  8. **Before StoreKit has answered, the picker reads as on the plan**, as no lock draws in that
     moment (`showsPlanLocks`): a paying player's drills must not vanish from the list.
  9. **The start button wears the plan's lock while the plan is off**, as a gated door does (0256
     D3), so a free player knows before the tap that New exercise will show the wall.
  10. **The second line reads *Loop · Slow Bend*, not the mockup's *Loop in Slow Bend***, which is
      *Where it's used*'s grammar on the next screen. A song adds its artist, *Song · Jack Trader*.
- **The picker's list takes values only** (`ReferencePlaceList`), with a store-side shell
  (`ReferenceAttachSheet`) that turns models into destinations and a pick back into a write, so slice
  4 can hand the same list its snapshot.
- **Tests:** `ReferenceDestinationPickerTests` (16) and `ReferenceFilingTests` (18, 8 of them on an
  in-memory store, 4 through `finalise(in:)`, 2 on Edit); `ReferenceFilingUITests` (2): on the plan, a link kept
  for later starts a drill that takes it and is then attached to a second drill by search; and under
  `-plan free`, the start button's lock, the picker's free words and footer, no drill under *Show all
  songs and loops*, and the wall. Build note 4's revision rewrote the file rules in
  `ReferenceLibraryTests` and `ReferenceRemovalTests`, and added three tests with real bytes to
  `ReferenceLinkAttachmentTests`: with one file in two places, Remove keeps the bytes and Delete takes
  them, and a row deleted outright leaves a file another row names.
- **Mutants:** 28 on the rules and the store, each with a witness test, and every one failed it. Two
  batching lessons. Two mutants that together left a binding unused stopped the build, as warnings are
  errors in Debug. And B5 with B6 made every attach a copy, so three move-path mutants were caught by
  the wrong cause (or, for the own-place guard, passed); run apart, each failed its own assertion. One
  more on the screen: the picker reading every resolved store as on the plan failed the free UI test at
  its search prompt, the line aimed at. Reading for mutants first found a test that couldn't fail:
  *Show everything*'s loops sorted the same by name as by song, so the song-first rule went unchecked
  until its data changed. Build note 4's revision: 17 more (grouping key, the copy's fields, the
  last-row delete, Remove's rule, Edit), in five batches with no witness shared inside a batch and
  none whose break would fail another's witness; every one failed its own. The order mutant first
  left its binding unused and didn't build, the same lesson again; as `order * 0` it was caught.
- **Seen on screen, not in a test:** a List draws a row's Label icon in the screen's indigo, ignoring
  the button's tint, so the start button's glyph was indigo on teal. It is now white on the wide button
  and teal on the plain one. Found by the UI test's screenshots.

## Build notes — Slice 4 (2026-10-21, `pocket-381-save-to-red-moon`)

- **Built:** the `PocketShare` target, embedded in the app (D10.3), with its sources under
  `Pocket/ShareExtension/` (D10.2: the lint rule and C9 read them, nothing widened) and a named list of
  the app's pure files compiled in beside them. The colours moved to `Colors.xcassets`, a catalog both
  targets include (D10.4). The App Group `group.click.decooperations.pocket` is on both targets. The
  extension's id is `click.decooperations.pocket.share`. D9's two files are `ShareOwnerSnapshot`
  (`owners.json`) and `ShareInbox` (`Inbox/<uuid>/`, bytes first and `item.json` last), both taking
  their folder as a parameter (D10.5). The app's half is `ShareInboxHost` at the root, `ShareInboxDrain`
  through `ReferenceLinkStore`, and the pure `ShareInboxPlan`. The extension's half is
  `SharedItemLoader`, the pure `SharedContent` (what an attachment offers, D12's first link, titles, the
  25 MB check) and `SaveToRedMoonView` over slice 3's place list.
- **Found while building, and fixed before anything shipped: SwiftData moved the store.** A
  `ModelConfiguration` left at its default has `groupContainer: .automatic`, which puts the store in the
  first App Group the app is entitled to. The first simulator launch with the group copied the whole
  store into the group container and ran from the copy, with the original left unread in Application
  Support. That is this ADR's first rejected alternative, done silently by the framework. The app now
  runs on `PocketStore.container()`, pinned to `groupContainer: .none` (and `cloudKitDatabase: .none`).
  `PocketStoreTests` pins the URL. In-memory tests can't see this, and CI builds unsigned, with no group,
  so the test bites on a local simulator run, which is signed with the group. Recorded in
  `docs/swiftdata-gotchas.md`.
- **And XcodeGen wiped the entitlement.** `entitlements: path:` with no `properties:` rewrites the file
  whenever its keys differ, so the group written in the file vanished on `xcodegen generate`. Both
  targets now declare it in `project.yml`, and the app's file-comment (why there is no iCloud and no
  Sign in with Apple) moved there with it.
- **Decided while building, from what D8, D9 and D12 leave open.** Each is a call to check.
  1. **The snapshot is written when the app goes to the background, not after each edit** (D9 says
     *"after an owner is added, renamed or deleted"*). On an iPhone, another app's share sheet is only
     reachable with Red Moon in the background, so a write as it leaves holds every edit made while it
     was open, with no hook on each edit site. It is also written on the foreground (after the drain)
     and when the plan standing or the appearance changes.
  2. **Nothing is written until StoreKit has answered**, so a snapshot never carries a guessed standing.
     The drain, which can run first, reads an unanswered StoreKit as on the plan: the save was picked
     from a snapshot written with the standing known, and a standing never moves back (D6).
  3. **The snapshot carries the appearance**, since the extension draws it: a player who pinned Light
     or Dark in Settings sees the same.
  4. **The title is editable in the card**, its placeholder the site or the file's kind. It starts as
     what the sharing app sent with the item, with the link taken out and only the first line kept (D12:
     never fetched). A document starts with its own name; a picture with none, since a camera's name says
     nothing.
  5. **The search sits under *Where it goes*, as drawn**, not in the navigation bar: the item comes
     first on this screen. A pick in *Show everything* marks the place and comes back to *Save*.
  6. **A save the store can't take at all is cleared, not kept.** The extension checks the kind and the
     25 MB ceiling before *Save*, so this is a file whose bytes turn out unreadable; it would be refused
     on every launch. Everything the store *can* take is kept, in *Not filed* if its place can't (D9).
  7. **A save's id is the reference's uid**, so a drain stopped between the store's save and clearing
     the inbox finds it already there and doesn't file it twice. It is also dated by when the player
     tapped *Save*, not by when the app next opened.
  8. **Before the app has written a snapshot** (installed or updated, not yet opened), the extension
     offers *Keep for later* alone and says the places show once Red Moon has opened. It doesn't guess a
     standing for a footer it can't back.
  9. **The activation rule is a predicate**, since the dictionary keys can't say *a web link but not a
     file link* or *at most one picture among the attachments*. One item; at least one attachment that is
     a web link, a picture, a PDF or text; at most one picture or PDF. A video app that sends a link and
     a sentence passes; two photos don't. `ShareActivationRuleTests` evaluates the rule out of the built
     extension against those shapes. The shapes are written from what each kind of app sends, and the
     device check with the real apps is owed.
  10. **A folder with no `item.json` is cleared on the drain**, with no file timestamps read: the drain
      runs only on the foreground, when no extension can be mid-write on an iPhone. So the app's privacy
      manifest gains no required-reason API. The extension carries a manifest of its own that declares
      none.
- **Checked on the simulator:**
  - The App Group reaches both signatures.
  - The app writes `owners.json` with every place: 8 on the test simulator, temporary sessions left out.
  - Saves written into the inbox by hand, the way the extension writes them, drained on the next
    launch: a link filed on a song with its note, a `.txt` and a `.md` kept for later with their bytes
    named by the save's id, and a link aimed at a drill kept for later on a never-bought simulator
    (D6). An abandoned folder was cleared. (The first of these runs is how the store move above was
    found: the rows landed in the group container's copy.)
  - **The real path, driven by a throwaway UI test (not kept):** Safari on the simulator, its share
    sheet, which lists Red Moon for a web page, then *Save to Red Moon*: the title Safari sent (*Example
    Domain*), *Keep for later* ticked, *Recent* from the snapshot. Picking a song moved the tick, a note
    was typed, *Save* closed the sheet, and bringing Red Moon forward filed it on that song with the
    note and the page's address. Screenshots looked at; it draws as the mockup in dark appearance.
- **D10.1's signing, done 2026-10-21** under team `2L35PZ86GP`. A development build from
  `scripts/run-device.sh` registered `click.decooperations.pocket.share` and turned App Groups on for
  both ids, but its profiles came down with an empty group list and the build failed on the
  mismatch. Automatic signing doesn't create or assign a group. Tomisin registered
  `group.click.decooperations.pocket` in the developer portal and assigned it to both ids, and the
  next build signed. Read off the built binaries: the app and the extension are signed by the team,
  and both carry the group.
- **Checked on a device** (Tomisin's iPhone, that build, installed over an earlier development build):
  - The store stayed in Application Support. Its files there were touched at the new build's launch,
    and no store appeared in the group container.
  - **Safari:** its share sheet lists Red Moon, and *Save to Red Moon* showed the page's title and
    site, *Keep for later* ticked, and *Recent* holding the phone's own song and loops, read from the
    snapshot the app wrote. A song was picked, a note typed and *Save* tapped; Red Moon, brought
    forward, had it filed on that song.
- **Owed:**
  - **The match repo**, the one part of D10.1 left: `fastlane/Matchfile` names both ids, so
    `fastlane beta` fails until it is repopulated (`fastlane match appstore` without `readonly`). An
    archive from Xcode's Organizer, the way releases are made today, signs automatically and doesn't
    need it.
  - **On a device:** the extension from YouTube, Photos and Files; what each sends against the
    activation rule; the title each hands over; a large photo through the drain; and the store staying
    in Application Support on an upgrade from the 1.3 build (that build first, this one over it, read
    by the store files' timestamps, not by counts).
  - The manual's figures for the extension, with the all-slices reshoot. A share sheet belongs to
    another app, so these are hand-shot on a device.

## Alternatives rejected

- **Moving the store into the App Group** so the extension can read it. That relocates every
  player's library to power a picker. 0186 D9 refused it for the widget.
- **An extension that only saves to *Keep for later***, with no picker. It's simpler and avoids the
  snapshot, but filing then always takes a second trip into the app, which is the slowness this
  exists to remove. The snapshot is small and has a precedent.
- **One reference row with many owners.** See D3.
- **Deleting an owner's references with it** (0167 as it stood). See D2.
