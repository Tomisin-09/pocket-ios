# ADR 0307 — A take is numbered where it was recorded

- **Status:** Accepted (2026-11-18). **Built 2026-11-20** on `pocket-452-take-numbers`; see *Build notes*. Tomisin agreed the decisions in conversation on
  2026-11-18 (*"I'm happy with your recommendations"*), and chose D3's wording the same day against
  the canvas mockup *Takes, numbered* (https://claude.ai/artifact/9sDFnr8fVXdNrjk2hamAPu): *"let's go
  with the recommended"*.
- **Date:** 2026-11-18 (`pocket-444-take-naming`)
- **Amends:** ADR 0069 — the 2026-08-05 amendment's point 4, *A take can be named*: a take the player
  hasn't named shows its number, *Take 3*, rather than *Take* (D3), and the hold menu reads *Rename*
  on every take (D4). Naming is still offered on takes and on no other entry kind.
- **Amends:** ADR 0236 — **D2**: a take with no name of the player's exports as its caption and its
  number, then the date (D6). The rest of D2 stands.
- **Amends:** ADR 0303 — **D4**'s take row: the title is the take's number where it said *Take* for
  an unnamed take. The line beneath is still the Journal's caption.
- **Relates to:** 0151 (a take outlives its owner, and keeps its number) · 0224 (a take recorded
  against nothing) · 0265 (the mode a loop take was recorded in, which the count ignores) · 0287 (the
  metronome's takes) · 0305 (the other schema addition planned for 1.5) · 0189 (its criteria are for
  a destructive change; this one is additive)

## Context

A take the player hasn't named is called *Take*. On the Journal feed every unnamed take reads the
same, with its caption underneath and a time. In a loop's or exercise's Takes sheet an unnamed take
shows its date and time as its title, so a list of six is six timestamps. Naming one has been
possible since 2026-08-05 (0069), but it's a step after the take, and most takes are never named.

Tomisin, 2026-11-18: *"Let's name it after the exercise/loop it was recorded in and let's name it
incrementally. we'll still give them the option of renaming but I think this is a more user friendly
option"*

What's already there:

- `Recording.title: String?` is the player's name. `displayTitle` falls back to *Take*.
- Every place a take's name appears already has a line beside it that names what it was recorded on:
  the Journal row's caption (*Slow Bend · Chorus*, *Spider walk · exercise*), the lock screen's line
  beneath (0303 D4), the take screen's caption, and a unit's Takes sheet, which lists one unit's takes.
- A take is recorded in five places: a loop run in any of its three modes, an exercise run, a freeform
  block (an exercise), the metronome (0287) and the Journal's ＋ (0224). `RecordingOwner.song` exists,
  but no screen records against a song.
- A loop's Takes sheet already lists every take on the loop whatever mode recorded it
  (`RecordingOwner.recordingsByRecent`).
- The export file name uses the player's title first, then the caption (0236 D2).

## Decision

### D1 — Every take is counted where it was recorded

A take gets a number when it's saved: one more than the highest number among the takes already
recorded on the same thing, starting at 1. The groups are:

- **a loop**, every mode together (the ramp, Active listening, Improvise). The mode decides where a
  take's caption leads (0265), not which count it's in, as the Takes sheet already lists them.
- **an exercise**, freeform blocks included.
- **the metronome**, all its takes as one count.
- **the Journal's ＋**, all takes recorded against nothing as one count.
- **a song**, if a screen ever records against one.

A take recorded in a routine block counts with the loop or exercise the block plays.

**Deleting the newest take lets its number come back.** If *Take 5* is deleted, the next take is
*Take 5* again. That's accepted, rather than a stored counter on every loop and exercise (see
*Alternatives*). Deleting any other take leaves a gap, and nothing renumbers. A number, once given,
never changes.

**A take whose owner is deleted keeps its number** (0151), and keeps being shown by it.

### D2 — The number is stored; the name is built when it's shown

`Recording.takeNumber: Int?`. Additive and optional with **no declaration default**, the shape
`title` and `ownerLabelAtTake` already have (CoreData 134110). The player's name stays in `title`,
which this doesn't touch.

The name isn't written into `title` at capture, for three reasons:

- the export would lose the song, since it reads `title` before the caption (D6);
- a loop renamed later would leave its old takes under the old name;
- a numbered take and one the player named would look the same to the app, and D4 needs to know which
  is which.

This is additive, so 0189's criteria for a destructive change don't apply. It still gets the store
upgrade check (*Build*).

### D3 — The take says its number, and the unit is said once

A take the player hasn't named is called *Take 3*. What it was recorded on stays where it already is,
on the line beside it, so the unit isn't said twice:

| Where | Title | Beside it |
|---|---|---|
| Journal row | *Take 3* | its caption, *Slow Bend · Chorus* |
| a loop's or exercise's Takes sheet | *Take 3* | its length and date (the line a named take already uses) |
| the take's screen | *Take 3* | its caption |
| the lock screen | *Take 3* | the Journal's caption (0303 D4) |
| a metronome take | *Take 3* | *Metronome*, and the click it was played to (0287) |
| a Journal ＋ take | *Take 3* | nothing; it belongs to nothing (0224) |

The Takes sheet's row changes the most: it showed an unnamed take's date as the title, and now shows
its number, with the date in the line beneath.

Where nothing beside the name says the unit, the unit is joined in (D6).

**Settled against a mockup on 2026-11-18.** The canvas *Takes, numbered*
(https://claude.ai/artifact/9sDFnr8fVXdNrjk2hamAPu) put today's screens, this wording and the unit in
the title (*Chorus · Take 3*) side by side: the Journal feed with takes from two loops, an exercise,
the metronome and the Journal's ＋, a loop's Takes sheet, the take's screen and the lock screen.
Tomisin chose this wording: *"let's go with the recommended"*.

### D4 — Your name wins, and clearing it brings the number back

A title the player gives shows instead of the number everywhere the number would. Renaming works as
today, from the same places: a right swipe or the hold menu in the Journal, the hold menu in the Takes
sheet, and the take screen's ⋯.

- **The hold menu reads Rename on every take.** No take is unnamed now, so *Name this take* goes.
  The alert keeps its title and message.
- **The field opens empty on a numbered take**, with the numbered name as its placeholder, and holding
  the player's name on a named one.
- **Saving an empty field puts the number back.** It clears `title`. Today an empty field is refused,
  because a blank title rendered as a blank row; a cleared title now renders as *Take 3*.

### D5 — Search finds the name that's shown

The Journal's search matches the shown name, as it matches a player's title today (0069's point 4):
*take 3* finds every unit's third take, and with a unit's name, *chorus take 3*, the one.

### D6 — An exported take carries its caption and its number

A take the player named exports as today: its title, then the date. A numbered take exports as its
caption and its number, then the date:

- `Slow Bend · Chorus · Take 3 · 1 Oct 2026.m4a`
- `Spider walk · exercise · Take 3 · 1 Oct 2026.m4a`
- `Metronome · Take 3 · 1 Oct 2026.m4a`
- `Take 3 · 1 Oct 2026.m4a`, a Journal ＋ take

A take with no number, which D8 should leave none of, exports as today.

### D7 — How the number is worked out

The rule is pure and Foundation-only, beside `TakeExportName`: the next number for a set of numbers
already given, and the numbering of a group of takes in recorded order. Both are unit-tested.

At capture, the number is assigned through `RecordingOwner.attach(to:)`, the one choke point that
already gives a take its owner and its caption, so no take can get an owner without a number. A loop or
exercise reads its takes off the relationship, in the context that inserts the take. A metronome or
Journal ＋ take has no relationship to read, so it counts over a fetch of all takes filtered in memory.
Neither uses an optional comparison in a `#Predicate` (`docs/swiftdata-gotchas.md`).

### D8 — Takes already on the phone are numbered once

A backfill gives every take without a number one, group by group (D1), in the order they were
recorded, starting above the highest number the group already has. Named takes are numbered too, so
the count includes every take; their names still show.

It runs at launch beside the other backfills, because a restored archive from before this build
arrives without numbers. One fetch of all takes, filtered in memory. After the first run it finds
nothing to number.

The archive carries the number as an optional key. An additive scalar is declared `Optional`
(`ArchiveCoding.swift`, ADR 0212 D3), so an older archive decodes with no number and the backfill
numbers it after the restore.

## Alternatives not taken

- **Write the name into `title` at capture.** No schema change, but D2's three costs.
- **The unit in the title**, *Chorus · Take 3*. It says the unit twice beside every caption, and on a
  loop's Takes sheet it repeats *Chorus ·* on every row. Shown on the mockup beside D3's wording, and
  not chosen (2026-11-18).
- **The unit and a bare number**, *Chorus 3* or *Spider walk 3*. It reads like a third exercise, or a
  loop called *Chorus 3*.
- **A counter stored on each loop and exercise**, so a number is never used twice. It would add a field
  to two more models, to avoid a repeated number after deleting the newest take, which is a duplicate,
  not a wrong one.
- **A count per mode on a loop.** A loop's takes are one history, and the Takes sheet already lists
  them together.
- **Leave unnamed takes on *Take*, and prompt for a name at Stop.** It asks for typing at the moment the
  player wants to play again, and an unanswered prompt leaves the list as it is now.

## Build

One branch, one PR, about M. In order:

1. **The pure rule** (D7) and `TakeExportName.stem` with the number (D6). Unit tests: the next number
   after a gap and after a deletion of the newest; a group numbered in recorded order above its highest;
   the export stem for a named, a numbered and a Journal ＋ take. Each test watched failing once against
   a deliberate mutant.
2. **The model:** `Recording.takeNumber`, assigned at capture (D7); `displayTitle` reads the title,
   then *Take N*, then *Take* for a take with no number.
3. **The backfill and the archive key** (D8), with a restore of an archive written before this build.
4. **The screens:** the Takes sheet's row (D3), the hold menu's label and the alert's field (D4), and
   the search haystack (D5).
5. **Docs in the same PR:** `docs/manual/journal-and-practice-log.md` (the take bullets that say an
   unnamed take is called *Take*) and `docs/manual/reference/tools-and-journal.md` (the hold menu's
   first item); `CHANGELOG.md`; `PROJECT.md` (the data model). Figures that show take rows go on the
   reshoot list.

**Checks:**

- The store upgrade check on the simulator and on the device, proved by timestamps, not counts
  (`docs/swiftdata-gotchas.md`). It also checks that the phone's existing takes come out numbered in
  the order they were recorded.
- Hosted-window snapshots of a Journal take row and a Takes sheet, on iOS 26.5 and 18.5, light and
  dark.
- On the device: two takes on one loop in two modes, one on an exercise, one at the metronome, and one
  from the Journal's ＋. Read the Journal, a Takes sheet and the lock screen; export one; rename one,
  then clear the name.

## Build notes (2026-11-20)

What the build settled that the decisions above didn't say:

- **`attach(to:in:)` takes the context as a required `ModelContext?`.** Only a metronome or Journal ＋
  take reads it; a loop, exercise or song counts off its relationship. Required so the one capture site
  can't forget it; `nil` is for tests that build uninserted takes.
- **A take whose owner was deleted counts by the caption it kept** (ADR 0151) when the backfill numbers
  it. It has no relationship left, and its caption is what it still says it was recorded on. A take
  with no caption at all (from before 0151) counts with the others like it.
- **The backfill also runs right after a restore**, not only at the next launch, so a restored take
  from an older archive doesn't read *Take* in between.
- **Search matches the shown name**, so *take* alone finds every take now, and the matcher's
  substring rule means *take 3* also finds *Take 13*. That is how search already treats every word.
- **Checks done on the branch:** unit tests for the rule, the name, the export stem, capture (a loop
  in two modes, an exercise, the metronome, the Journal ＋), the backfill and the archive key, each
  watched failing against a deliberate mutant (count instead of highest; newest first; the number
  dropped from the stem). A hosted-window render of a Takes sheet and Journal rows on iOS 26.5, light
  and dark. The store upgrade check on the simulator, proved by timestamps (see the PR).
- **Owed on the device:** the store upgrade on the phone's real store, and the device pass under
  *Checks*. Figures that show take rows go on the reshoot list.

## Consequences

- 0069's point 4 stands in what it decided: naming is offered on takes and on no other entry kind.
  What it no longer describes is an unnamed take with nothing but a timestamp.
- 0236 D2 and 0303 D4 carry an `Amended by` note pointing here.
- Tests that pin *Take* or *Name this take* change with the build: `RecordingTests`,
  `NowPlayingClaimsTests`, `ExportUITests`, and the archive writer and reader tests.
- 1.5 plans two schema additions, this and 0305's slice 2 (`Song`). Each gets its own upgrade check,
  and neither waits for the other.
