# ADR 0210 — a folder you can hand over

- **Status:** Accepted — **S1 built** (2026-09-09, `pocket-311-folders`). S2 (share a folder) and
  S3 (receive a bundle) are designed below and **not built**; D11 and D12 describe them and nothing
  in the app implements them yet.
- **Date:** 2026-09-09 (`pocket-311-folders`)
- **Amends:** ADR 0033 — its naming rule gains a **third scope** (D1): songs are Collections, loops
  are Tags, exercises and routines are **Folders**. 0033's three failure modes (no reuse, no
  normalisation, no payoff) are answered here rather than rediscovered, and its promotion trigger —
  *"a real playlist needs a many-to-many relationship and a browse surface, which isn't justified
  until the library/planner needs it"* — is what this ADR argues has arrived. Song collections
  themselves are untouched.
- **Amends:** ADR 0188 — the archive gains three **optional** fields (`ExerciseRecord.folders`,
  `RoutineRecord.folders`, `PracticeArchive.folderMarkers`) and the restore mints marker rows (D8).
  0188's version gate, its trust asymmetry, its skip-don't-merge restore rule and every existing
  record shape are untouched, and an archive written before this one still restores.
- **Amends:** ADR 0209 — D2's subtraction list gains one entry: a drill handed over on its own now
  also loses its **folders**, and gains its folders' leaf names in `tags` (D8). Everything else 0209
  decided about the exercise door is unchanged.
- **Relates to:** ADR 0068 (template sections, which folders sit above rather than replace),
  ADR 0159 (multi-select facets — deliberately not applied, D6), ADR 0189 (the criteria a
  destructive schema change has to meet, and the reason D7 is a value migration), ADR 0121 (the
  backfill this one is shaped like), ADR 0205 (the decode overload D8 refuses to write), ADR 0126
  (the toolbar grammar that puts *New folder…* in the options menu), ADR 0120 (the event D13 adds),
  ADR 0197 (the six-tile Home, and why there is no folders door on it)
- **Schema:** additive only. `Exercise.folders: [String] = []`, `Routine.folders: [String] = []`,
  and a **new entity** `PracticeFolder`. Declaration-defaulted primitive arrays and a brand-new
  entity are all migration-exempt (CoreData 134110), so none of ADR 0189's D1–D4 applies: no
  `VersionedSchema`, no `SchemaMigrationPlan`, no retype, no rename, no removal. **`Exercise.tags`
  is retired in place, not dropped.**

## Context

A guitar teacher wants to organise drills and routines by proficiency — *Beginner*, *Grade 2*,
*Technique/Alternate picking* — and then hand a **set** to a student. Neither half was possible.

What organisation existed:

| Model | Grouping | User-defined? |
|---|---|---|
| `Song` | **Collections** — `[String]`, multi-select filter, "build a session from this collection" | yes |
| `Loop` | **Tags** — `[String]` | yes |
| `Exercise` | Template sections (Basic, Scales, Chords…), collapsible (ADR 0068) | **no** |
| `Routine` | A flat list. No sections at all. | **no** |

`Exercise.tags` existed, was canonicalised through `Labels`, was shown on the ⓘ sheet, and travelled
in shared files — and **nothing browsed or filtered by it**. `PracticeLibrarySort.exerciseMatches`
searched the name only, so a drill tagged `warm-up` was not findable by typing "warm-up". That is
exactly what ADR 0033 called *"a grouping you can't filter by is just a note."* `Routine` had no
label axis at all.

### Why S3's model, and one correction to the vocabulary

In Amazon S3 a **bucket** is the top-level container and does not nest. What a folder tree actually
is in S3 is the *key prefix* convention: a flat namespace of `key → object` where `/` is just a
character, and `ListObjects(prefix:delimiter:)` returns matching objects plus **CommonPrefixes**.
The console renders those prefixes as folders. There are no directories. So: not buckets —
**prefix-delimited keys**.

That distinction is the whole reason it fits here:

- **It stays a flat `[String]`.** `Song.collections` is already that shape, and it is the
  migration-exempt one: a declaration-defaulted primitive array.
- **No relationships means no cascade decisions.** Real folders need parent pointers, reparenting,
  and an answer for "what happens to the children when a folder dies". This project has paid for
  that class of problem twice (ADR 0151's cascade→nullify; orphaned routine blocks). Derived
  hierarchy has none of it.
- **Multi-membership falls out free.** `["Beginner/Warm-ups", "Technique/Alternate picking"]` — one
  drill, two places. For a teacher that is the normal case, not the edge; real folders need symlinks
  to do it.

## Decisions

### D1 — the word is **Folders**, and it is a third scope

Songs are **Collections**, loops are **Tags**, exercises and routines are **Folders**. ADR 0033's
naming rule — the word follows the scope, so "is this a tag or a collection?" is never a judgement
call — is extended, not broken.

"Folder" is chosen knowing the storage is flat prefixes, because the browse surface renders exactly
what a folder tree looks like and the player never sees a path string unless they ask for one. The
one expectation it borrows and must **not** honour is *move-not-copy* — so the verb everywhere is
**"Add to folder…"**, never "Move to". A drill sitting in *Grade 2* **and** *Picking* is the feature.

### D2 — membership is a flat `[String]` on the item, never a relationship

```swift
var folders: [String] = []   // on Exercise, and on Routine
```

Additive, defaulted, primitive: migration-exempt, and nothing ADR 0189 gates. Each entry is a
canonical path (`"Technique/Alternate picking"`).

**This is the field a future reader will want to tidy into a `@Relationship`. Don't.** It is what
buys multi-membership, the exempt migration, and the absence of every reparenting decision.

### D3 — one namespace, two libraries

`"Beginner"` means the same folder in the Exercises library and the Routines library. The libraries
are two **views** onto one namespace, each showing its own members — so a folder holding six drills
and no sessions reads `6` in one and `0` in the other, which is the honest reading rather than a bug.

The alternative — a namespace per model — was rejected because it makes the teacher retype the same
structure twice, guarantees the two drift, and makes D11 impossible: a shared *Beginner* folder
carrying both the drills and the routines is the actual deliverable.

### D4 — `PracticeFolder`: a marker row, and what it is **not**

Empty folders must exist — a teacher builds *Grade 1…4* before filling them, and a folder emptied by
a delete must not vanish under the player mid-task. S3 solves this with **zero-byte marker
objects**; this is that.

```swift
@Model final class PracticeFolder {
    var uid: UUID
    var path: String = ""
    var dateAdded: Date = Date.now
}
```

- **It records existence, never membership.** Membership stays D2's string array. A second source of
  truth about where a drill sits would be invisible in both the first time they disagreed.
- **The folder list is the union** of marker paths and paths derived from members (ancestors
  included). A marker is written whenever a folder is created *or filed into*, so the two converge;
  the union exists so a library restored from an archive written before markers, or edited by a
  build without them, still browses correctly.
- Named `PracticeFolder`, **not** `Collection` (shadows the stdlib protocol — 0033 flagged this
  already) and not `Folder` (too close to `FileManager` vocabulary in a project that also does real
  file I/O).

**Considered and rejected: `Profile.folderMarkers: [String]`.** Cheaper — one additive array on an
existing model, no container change. Rejected because `Profile` is the local artist profile
(ADR 0113), not app state, and because 0033 named **per-folder metadata (colour, pinned order)** as
a promotion trigger. A row is where that goes when it comes; an array on the wrong model is where it
cannot.

### D5 — `FolderPath`: pure, and where the real bugs live

A new pure type beside `Labels` (`Pocket/Core/Models/FolderPath.swift`), SwiftUI- and SwiftData-free
per AGENTS.md, unit-tested first because everything else is drawn from it.

| Function | What it does |
|---|---|
| `canonical(_:)` / `segments(_:)` | split on `/`, `Labels.canonical` **per segment**, drop empties |
| `folding(_:into:)` | **segment-wise, positional** case folding against existing paths |
| `children(of:in:)` | S3's `CommonPrefixes` — the immediate child folders at a prefix |
| `isUnder(_:prefix:)` | membership at or below a prefix |
| `contains(_:within:)` | whether an item's folders put it in the list shown at a prefix (D6b) |
| `renaming(_:to:in:)` | the prefix rewrite |

Three carry a trap worth naming:

1. **Segment-wise folding is more than `Labels` does.** `Labels` folds whole strings, so a path that
   differs anywhere is a brand-new label to it and a stray `beginner/…` survives into the namespace
   — the exact fragmentation 0033 exists to prevent, reintroduced by the `/`. Folding here compares
   segment by segment and adopts the form used at *that position in the tree*, so `Grade 1/Picking`
   never renames `Grade 2/picking`.
2. **`isUnder` must not be `hasPrefix`.** `"Beginners/Warm-ups".hasPrefix("Beginner")` is `true`,
   and they are different folders. Segment arrays are compared. Pinned by a test named for the bug.
3. **Renaming is a copy-then-delete across every holder** — S3 cannot rename a prefix either,
   because there is nothing to rename. One pure function, applied to exercises, routines and markers
   in one pass by `PracticeFolderStore`, is what stops the three drifting. Renaming onto a folder
   that already exists **merges**, because a folder *is* its path.

**`/` is reserved.** The New-folder field creates **one segment at the current level**; a typed `/`
is folded to a space, not silently obeyed. A teacher naming a folder `Rock/Blues` gets one folder
called *Rock Blues*, not two levels they did not ask for. Nesting is done by standing inside a
folder and creating there — which is also what keeps the breadcrumb honest.

### D6 — navigate, don't filter (and ADR 0159 deliberately does not apply)

Folders are a **prefix walk**, one at a time. ADR 0159 governs multi-select **facets** (OR within a
facet, AND across facets); a path is a *place*, and you stand in one. Ticking two folders at once is
not offered, and that is a decision rather than an omission.

- **Folder rows sit above the template sections; both survive.** Folders group by *intent*,
  templates (ADR 0068) group by *kind* — orthogonal axes, and collapsing one does not want to be the
  other.
- **The folder rows are their own collapsible section, closed until asked for.** This was not in the
  design, and the built screen is why it is. D7's backfill turns every tag into a folder, so the
  seeded library opened with **ten one-drill folders filling the display** and every actual drill
  below the fold — the axis burying the library it organises. Two things found it, and neither was a
  green build: the first screenshot of the screen, and four UI tests that had always found a seeded
  drill and suddenly could not, because a SwiftUI `List` does not create a row that far off screen.

  So the section uses the same `CollapsibleLibrarySection` the template sections use, but with the
  **opposite default**: those store what is *collapsed*, so a bucket of new content arrives open,
  while this one arrives shut. Folders are not new content — they are a second axis over a screen
  that already worked, and it is D6b's own claim that the root stays the library you already had.
  Expanded by default, that claim was false. Shut, the axis costs exactly one header row carrying
  its own count: visible, tappable, and out of the way until it is wanted.
- **Search, sort and favourites narrow within the current prefix.** The no-match state offers
  *Search all folders*, which clears the prefix and keeps the query — the one escape hatch, so a
  player never concludes a drill is gone when they are merely standing somewhere else.
- The breadcrumb appears **only once you have left the root**, the progressive disclosure the
  instrument filter already uses.

### D6b — a level shows everything at or below it (a deliberate divergence from S3)

`ListObjects` with a delimiter returns only the objects sitting **directly** at a prefix. Copying
that faithfully would make a fully-filed library's root list **empty**, and `Beginner` would hide its
own `Beginner/Warm-ups` drills until you descended again.

So a level lists every item at or below it, and a folder row's count is that total. The root is
therefore exactly the library that existed before this ADR, unchanged — which is the property that
makes the axis additive to the *screen* as well as to the schema.

Two consequences, both visible and neither a bug:

- **The counts do not sum to the library total**, because a drill in two folders is counted in both.
- **`children(of:)` stays pure S3** — only the *item* list widens. The `CommonPrefixes` computation
  is unchanged, and is still what the folder rows are drawn from.

Found by drawing the screens rather than by writing the plan, which is the argument for having drawn
them.

### D7 — you start with **no folders**, and an offer to make one

**This decision was reversed after the build was on a phone, and the reversal is the decision.**

The design said: fold tags in as a *value* migration. Not a schema one — removing `Exercise.tags` is
destructive under ADR 0189 and would cost D1–D4, while copying values costs none of it. So an
`ExerciseFolderBackfill`, shaped like `ExerciseNoteRateBackfill`, turned every canonical tag into a
top-level folder at launch, and the payoff was to be the empty state: a library that opens *already
organised* rather than showing a new axis with nothing in it, which is how a fresh grouping feature
usually fails.

What it actually produced, on a real device and in the first screenshot of the built screen, was
**ten folders holding one drill each** — `chords`, `fretting`, `lead`, `legato`, `picking`,
`rhythm`, `scales`, `synchronization`, `technique`, `warmup` — derived from the seeded presets'
keyword tags. That is not organisation. It is a tag list rendered as folders, in a vocabulary the
player never chose, filling the screen and pushing every actual drill below the fold. The failure
mode the backfill existed to avoid is *an empty new axis*; what it produced instead is a worse one,
**a full axis that is somebody else's**.

So: **no backfill, and no folders at the start.** A library that has none shows a single
`FolderInviteRow` — a folder glyph, *New folder*, and one line saying what folders are for —
modelled on the empty song library's offer to import (`LibraryEmptyState`), scaled to a row because
this library is not empty, it merely has no folders yet. It disappears the moment a folder exists.

Two consequences follow, and both are restorations rather than new decisions:

- **`Exercise.tags` is not retired.** Nothing copies it anywhere now, so hiding it would lose
  information with nothing put in its place. The chips are back on the ⓘ sheet exactly as they were,
  the column is live, and the **Folders** section sits beside them. ADR 0033's *"a grouping you
  can't filter by is just a note"* still indicts tags — folders are the answer to it, but only for
  the drills a player deliberately files.
- **The folder section is expanded by default again.** It was shut only because the backfill made
  ten of them; a folder now exists because somebody asked for it, and hiding what they just made is
  its own kind of wrong. A library with no folders shows no section at all.

### D8 — the wire keeps `tags`, and gains an **Optional** `folders`

`ExerciseRecord.folders: [String]?` and `RoutineRecord.folders: [String]?` — **Optional, and that is
load-bearing**. A non-optional `var folders: [String] = []` does nothing on the way in: Swift's
synthesized `Decodable` calls `decode(_:forKey:)` and throws `keyNotFound`, so **every archive
written before the field would fail to decode entirely** — not lose its folders, fail. `Optional` is
exempt (`decodeIfPresent`). Pinned by a test that encodes a real archive, strips the keys from the
JSON, and decodes it.

And **no `KeyedDecodingContainer` overload for `[String]`.** ADR 0205 D5 forbids a generic over
`[T]` because it would default every missing array everywhere; `[String]` is barely narrower — it
would silently cover `tags`, `collections`, and anything added later. Optional makes the overload
unnecessary, which is the point.

`PracticeArchive.folderMarkers: [String]?` carries the **empty** folders only; everything else is
implied by its members' paths, and writing both would put one fact in the archive twice. Restored
markers are **not counted as rows**: a folder is not a library item, and the restore preview
promises a number of drills and sessions.

**A drill handed over on its own arrives unfiled.** Its paths are positions in the *sender's* tree
(`Students/2026/Beginner/Warm-ups`), and reproducing that on a stranger's phone would be handing
over a filing cabinet with the drill. Its own `tags` cross exactly as they did before folders
existed; an earlier cut added the folders' leaf names to them, which was harmless while `tags` was a
retired column and stopped being so the moment it was not — it would put the sender's filing
vocabulary into a field the receiver can see and did not write. Sharing a whole folder is a
different act with a different answer (D11).

`schemaVersion` is **not** bumped — third time, same argument as ADR 0209 D1: the version is about
record *shapes*, and bumping would make files written by this build refused by every build in the
wild for nothing.

### D9 — where you file something, and one picker for both

- **The ⓘ sheet.** `ExerciseDetailSheet`'s tag chip row becomes a **Folders** section, in a new
  `ExerciseDetailSheet+Folders.swift` — the sheet sits against the 400-line cap and already spilled
  `+Share` for the same reason.
- **The row hold menu**, through the existing `pocketRowActions(menu:)` seam: *Add to folder…*.
  Both libraries.
- **One `FolderPickerSheet`** serves both models: the folders already in use offered as tappable
  suggestions (0033's convergence mechanism, and the reason a label set stops fragmenting), plus
  *New folder…*. The picker makes **top-level** folders only; nesting is done by standing somewhere.
- **Making a folder is not gated.** It is organising, not authoring — it mints no drill and no
  routine, and a padlock there would read as the app charging for tidiness.

### D10 — deleting a folder never deletes a drill

The verb removes the marker and strips the prefix from its members. Members are untouched and remain
in whatever other folders they sit in; a drill left with none is simply unfiled. The confirmation
says so **in words, with the counts** — "The folder goes. The 6 exercises and 2 routines in it stay
in your library" — because *Delete folder* in nearly every other app on the device means something
considerably more frightening.

### D11 — share a folder (S2, **not built**)

A third `SharedPracticeKind.folder`, carrying:

- the root path and its subfolder marker paths — **including the empty ones**: an empty folder is
  the only object in this design a person makes deliberately with nothing behind it, so it is pure
  intent, and intent is the wrong thing to drop on the way over. A teacher can hand a student the
  skeleton of a term before building it;
- its exercises, and its routines **plus the exercises those routines name**, deduped by `uid`;
- every item's `folders` **rebased to the shared root**, so the student gets `Beginner/Warm-ups`
  rather than the teacher's `Students/2026/Beginner/Warm-ups`.

Filename from the folder's leaf name. **Not gated on send** — same reason as ADR 0209 D3.

### D12 — receive a bundle (S3, **not built**)

Through the `PracticeReceiveHost` that ADR 0209 D4 already generalised — both existing doors accept
it for free. `ReceivedFolder` + a preview sheet stating exactly what lands and where.

**The gate is all-or-nothing.** If any item needs Pro, the whole bundle walls: a partial landing
hands a student a pack with holes and no way to tell which holes. New `PaywallTrigger.receivedFolder`,
its own case for the reason `.receive` and `.receivedExercise` already have one.

Landing into a folder that already exists **merges**. Items are new copies with new `uid`s, matching
ADR 0188 D1's mint — so **re-receiving an updated pack duplicates it** rather than updating in place.
Stated rather than hidden, and logged to `docs/backlog.md`.

### D13 — analytics

`folderCreated(depth:)` → `folder_created`, built in S1. `depth` is the one property worth carrying
and it answers the design's open question: nesting is derived from a `/` in a flat key, so whether
anybody goes below the top level is what says if the prefix walk earns its screen. No name, ever —
a folder name is player-authored text (ADR 0120), and the lint rule makes a free `String` impossible
here by construction.

`folderShared(exercises:routines:)` and `folderReceived(exercises:routines:)` arrive with S2 and S3.

## Slices

**S1 — the axis. Built.** `folders` on both models; `PracticeFolder`; `FolderPath`;
`PracticeFolderStore`; browse (folder rows, breadcrumb, prefix-scoped search) in both libraries;
`FolderInviteRow`; `FolderPickerSheet`; the ⓘ and hold-menu doors; rename and delete; the archive
fields. Answers *"can I organise this at all"* and ships alone.

**S2 — share a folder.** The `.folder` payload kind and the share control on the browse surface.
Writes a file and reads none, so nothing in it can damage a library — 0188's own reason for shipping
a send half first — and it produces the fixture S3 is built against.

**S3 — receive a bundle.** `ReceivedFolder`, the preview sheet, the paywall trigger, the merge.

## Consequences

- **The Routines library gains sections for the first time.** It had no grouping of any kind.
- **A folder can be empty and still real**, which is a state the app has to draw and a marker row to
  keep. That is a new entity in the container — additive, but a real addition.
- **Counts do not sum** (D6b), and the library total is not the sum of its folders. This is inherent to
  multi-membership, not a rounding problem to be fixed later.
- **A decision was reversed by looking at it**, and D7 records the reversal rather than the tidied
  outcome. The backfill was reasoned about carefully, cost nothing under ADR 0189, and was wrong on
  a phone in about two seconds. The general form: *a migration that invents structure on the
  player's behalf has to be judged by the structure it invents, not by what it costs to run.*
- **`Exercise.tags` is unchanged and still unbrowsable.** ADR 0033's *"a grouping you can't filter
  by is just a note"* still indicts it. Folders answer that complaint only for the drills somebody
  deliberately files, which is now the point rather than a shortfall.
- **Two analytics events were found unpinned** while D13 was being added — ADR 0209's
  `exercise_received` had never been listed in `AnalyticsEventTests.everyEvent`, which is the third
  time that file has caught itself out. Both are pinned now, and the fix its own header has asked
  for twice — moving the sample list next to the enum — is logged in `docs/backlog.md`.

## Not in scope

Loop `Tags` and song `Collections` folding into folders (three scopes, one word each, per D1);
per-folder colour or pinned order (the metadata that would justify moving membership onto the row);
drag-to-file; smart/saved folders; a depth cap; moving a folder to a different parent (rename changes
the leaf only); a shared identity that lets a re-sent pack update in place rather than duplicate
(D12, logged).

**A folders door on Home — parked, deliberately.** ADR 0197 has just cut Home to six tiles so that
what changes is not competing with a fixed menu, and a folder rail is more of what changes. The
larger cost is hidden: folders are *one* namespace across *two* libraries (D3), so a folder tapped on
Home must open the exercises in it, the routines in it, or a combined folder-first view that no slice
here builds. Revisit after living with S1 — and if the three taps do turn out to grate, the likely
answer is a rail that appears only once a couple of folders exist, the progressive disclosure the
instrument filter already uses. Logged in `docs/backlog.md`.
