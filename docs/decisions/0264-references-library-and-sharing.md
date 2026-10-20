# ADR 0264 — References: a library in the Toolkit, and sharing into Red Moon

- **Status:** Accepted, not built. Decided with Tomisin on 2026-10-20, from a nine-screen mockup
  (canvas *Red Moon References*). The two questions it first left open were settled the same day,
  with the recommended answers (D11, D12). It lands **after 1.4**: the library first, then the share
  extension.
- **Date:** 2026-10-20
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
- **Files never group.** A picture or a PDF has no link to match on, so each one is its own source.
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
- **A file is its own source** (D3), so removing one always sends it to *Not filed*. Its bytes are
  never deleted from an owner's section.
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

After 1.4, one branch at a time:

1. **Keep references:** D1, D2 (the delete rules, the toast, the device store check), and D7.
2. **The library:** D3, D4, D5 (without *Attach to…*), D6's rules as pure, unit-tested logic, and
   D11.
3. **Attach to…** and *Start an exercise from this*.
4. **The share extension:** D8, D9, D10 and D12.

Slices 1 to 3 need no new target and no signing work.

## Alternatives rejected

- **Moving the store into the App Group** so the extension can read it. That relocates every
  player's library to power a picker. 0186 D9 refused it for the widget.
- **An extension that only saves to *Keep for later***, with no picker. It's simpler and avoids the
  snapshot, but filing then always takes a second trip into the app, which is the slowness this
  exists to remove. The snapshot is small and has a precedent.
- **One reference row with many owners.** See D3.
- **Deleting an owner's references with it** (0167 as it stood). See D2.
