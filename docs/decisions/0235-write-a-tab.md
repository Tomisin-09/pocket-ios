# ADR 0235 — Write a tab: notes placed on the neck, kept in My tabs, and a Home tile that's yours

- **Status:** Accepted. Built on `pocket-341-write-a-tab`, one commit per step of the build order. Still owed:
  the reshoot (Consequences).
- **Date:** 2026-09-30 (notes 2026-09-29; one design round 2026-09-30)
- **Amends:** ADR 0211 — **D3**: the half beside Toolkit is the player's own tile (D6), no longer the
  Oracle's tile drawn hidden. The alternative refused there, *another destination in the empty slot*,
  is taken in a different shape: not a new destination, but a second way into a Toolkit tool the
  player picks. **D6**: deleting `learnRow`'s condition is no longer the whole of reopening the door,
  since the half it would unhide is the player's tile now; where the Oracle goes is left for when it's
  picked up again (D7). D1, D2, D4, D5 and D7 stand: the Oracle stays unreachable, and its launch
  argument, its test door and its negative test are unchanged.
- **Amends:** ADR 0197 — **D1**: six reachable tiles again, and two of them share a hue. The player's
  tile wears Toolkit's indigo, since it opens a Toolkit tool; the glyph and name tell the two apart.
  **D3**: a second tile carries a caption, *Hold to change*. It is also an instruction, and it goes
  once followed. D2 (the spoken labels are the UI-test contract) and D6 (one file owns the map) stand.
- **Amends:** ADR 0225 — **D10**: *no free-text tab document anywhere* is lifted for a tab written on
  the neck in My tabs (D1). Typing and importing tab stay out, and a song's chart stays derived from
  its pieces. *Order only*, *no playing the tab back* and *never detected, never suggested* stand.
- **Amends:** ADR 0227 — **D10**: *no free-text tab document* is lifted the same way, for the same
  tab. The rest of D10 stands, and a written tab takes the same marks with the same limits.
- **Relates to:** 0193 D4 (the two ways into a Home choice, reused, not changed) · 0163 (a hold beside
  a Settings row that stays findable) · 0162 (Settings ▸ Practice, which gains a card) · 0187 (the
  Oracle, left out: D7) · 0232 D10 and D12 (the map's tab stays drawn from pieces; no share
  or export; never imported) · 0150 (the legal review sharing waits on) · 0234 (the neck, the undo
  history and the drawn piece, reused) · 0229 (the Journal's Pieces, which written tabs stay out of) ·
  0218 (`SavedProgression`, the pattern the new entity follows) · 0181 and 0188 (the archive and
  restore) · 0189 (additive schema) · 0090 (identity by uid) · 0070 (never grades) · 0144 D2 (the
  Toolkit is free).
- **Schema:** one new entity, `WrittenTab` (`uid`, `title`, `createdAt`, `changedAt`, `tabData`),
  every non-optional attribute declaration-defaulted and the content in a blob, with no stored enum.
  Additive, so 0189's criteria are met. The archive gains `PracticeArchive.writtenTabs`, Optional, so
  an archive written before this ADR still decodes. One new `UserDefaults` key for the tile.

## Context

Tomisin's notes of 2026-09-29 ended with a ninth item that 0234 held back for its own record: **write
a tab**, reached from the empty Home tile beside Toolkit. *Name the notes* (0227, 0234) already had a
neck you tap, marks, joins, chords, undo and a drawing that reads. What it didn't have was a way to
write something that isn't a loop: a riff you already play, a line you worked out on the sofa, a bass
part for a song with no recording in the app.

Three things were settled while planning:

- **The tile says *My tabs* and opens the list**, where + writes a new tab. A tile names the place it
  opens (the note on `oracleTile` makes the same point), and *Write a tab* would name one action inside
  it.
- **Written tabs are not in the Journal.** My tabs is their only home.
- **Bar lines and sections are in** (*"yeah lets do it. lets also include sections"*), for written tabs
  only.

One design round ran on a playable mockup before any code: Home with the tile and its hold menu,
Toolkit and the list, the writer, and the drawn tab beside an unchanged loop piece. Tomisin's answers:
the tile in Toolkit's indigo; *Hold to change* until the tile has been changed once; a tab opens to be
read, with Edit; row captions off when a tab has sections; headings in ink; *The tab so far* keeps its
place under the neck; and the **+** goes back to the end when another note is tapped. The mockup's
other defaults stand.

## Decisions

### D1 — A tab you write on the neck

- A written tab is **notes placed on the neck, in order**, with bar lines and sections (D4). It belongs
  to no song and no loop.
- **Nothing plays.** There is no recording behind it, and the synth stays out (0227 D8). The reading
  view says so: *Written on the neck. Nothing plays, because there's no recording behind it.*
- **Order only, no durations.** A bar line groups notes and says nothing about time.
- **Never typed, never imported, never detected.** Every fret, mark and name is the player's.

### D2 — My tabs, a sixth Toolkit row

- The row sits **after My progressions**, so the three things you make sit together: *My tabs*, *Tabs
  you write on the neck*, trailing *None yet* or *N saved*, as My chords does.
- **The list puts the tab changed last at the top.** A row shows the title, when it last changed, and
  one line, *30 notes · 3 sections · Guitar · Standard*.
- **Empty:** *No tabs yet*, *Write a riff or a line you play, one note at a time on the neck.*, and a
  *Write a tab* button. **+** in the toolbar writes a new tab.
- **Tapping a row opens the tab to read**, with **Edit**. Once a tab is written you play from it far
  more often than you change it.
- **Hold or swipe a row** for *Rename* (an alert) and *Delete* (an undo toast).
- A new tab is kept on its first note or its first letter of title. **A tab left with no notes and no
  title isn't kept.** One with notes and no title is called *Untitled tab*.

### D3 — The writer is Name the notes' neck, shared, not copied

- Top to bottom: a title field (*Name this tab*), the strip with its line, ↶ ↷ with **| Bar line** and
  **§ Section**, the neck with *Where do you play it?*, the marks, *Into it*, *Chords*, and **The tab
  so far**, drawn as D5 draws it.
- **The strip has one open slot, a +.** Tapping the neck fills it and moves on, silently. With
  *Chords* on it stays, since a shape takes several taps. The marks follow the note just placed, and
  the three notes either side are drawn numbered (0234 D3, D4).
- **Picking a note** makes it current: the neck changes it, and the line under the strip offers
  *Insert before N* and *Take note N out*.
  - *Insert before* moves the + in front of that note, and each tap adds one more there.
  - **Tapping another note, or the + at the end, sends the + back to the end.**
  - *Take note N out* drops a hammer-on or slide into the note after it, because that note now follows
    a different one.
- **Instrument and tuning** use Name the notes' sheet. On a tab with notes, a new instrument asks
  first, then clears the frets, as one step ↶ brings back.
- **Undo and redo last the visit** and cover everything, bar lines and sections included. With a
  keyboard, ⌘Z, ⇧⌘Z and ⌘Y work.
- **It saves as you go.** *Done* goes back to the tab.
- **The accent is Toolkit's indigo**, as the tile is.
- No snags, no *By ear*, no *Next unnamed*: there's no recording to be stuck on or to hear, and every
  note is placed.

### D4 — Bar lines and sections are marks between notes

- **Both are stored against note positions**, not mixed into the notes. Joins, neighbours, the slot
  and undo keep working on note numbers, and a hammer-on across a bar line still works.
- **Bar line and Section act at the lit chip**: the + while writing, or the note picked. *Bar line*
  puts a bar before it, or takes one away. There is never a bar before the first note.
- **A section starts at a note, always on a new bar.** Pick *Intro*, *Verse*, *Pre-chorus*, *Chorus*,
  *Bridge*, *Solo* or *Outro*, or type a name. Tapping a heading in the strip picks its first note, so
  § renames it or takes it off.
- **Taking a heading off keeps its bar line.**
- **A note put in before another joins that note's bar and section**, and the marks after it move
  along by one.
- **When a section loses its only note, it goes**, unless it's the last, which waits for the next note
  written.
- **For written tabs only.** A loop's piece has neither, and draws exactly as it does today.

### D5 — The tab, drawn

- It is 0234 D8's drawing, with bar lines and headings added.
- **Each section starts a new row, under its heading, in ink.**
- **Rows keep whole bars together** and never scroll sideways. A bar too long for a row breaks at the
  edge.
- **Row captions (*Notes 12–23*) are off when a tab has sections**, since the headings already place
  you. A tab with no sections keeps them.
- The new layout runs **only for a tab with bars or sections**, so a saved piece takes today's code
  path unchanged.
- There is **no share or copy action** (D8).

### D6 — The tile beside Toolkit is the player's

- **It opens My tabs until changed.** Its choices are exactly Toolkit's rows: My tabs, My chords, My
  progressions, Tuner, Glossary, Help & FAQs. It takes the chosen tool's **name and icon**, so it always
  says where it goes, and its spoken label is that row's, *My tabs, tabs you write on the neck*.
- **Two ways to change it**, as Jump back in has (0193 D4):
  - **hold the tile**: a menu of the six, with no heading, as Jump back in has;
  - **Settings ▸ Practice**, a card of its own, *Beside Toolkit*, footed *The tile beside Toolkit on
    Home opens the tool you pick here. You can also hold the tile to change it.*

  Both write one key. An unknown stored value opens My tabs. The key is cleared under `-uiTesting`.
- **Toolkit's indigo.** It can open any Toolkit tool, so it wears Toolkit's colour; a hue of its own
  would have to suit six different tools.
- ***Hold to change* sits under the name until the tile has been changed once**, then goes. It's the
  second caption on Home, and like the empty library's it is an instruction that goes once followed.
- A tool opened from the tile looks as it does from the Toolkit, tint included.
- **It is a link with a context menu, never a button with a hold**, which fires both.
- It lives in `HomeView+Map.swift` with the other tiles (0197 D6).

### D7 — The Oracle is out of scope

This record decides nothing about the Red Moon Oracle, including where it goes if its door reopens:
that is decided when the Oracle is picked up again. Its code is untouched, and so is its test-only
door, which still draws the Learn row as before, Oracle and Toolkit, with no player's tile.
`-oracleDoor` still needs `-uiTesting`, and the negative test still fails if a player can reach it.

### D8 — Kept on the device and in the backup, nowhere else

- **`WrittenTab`** follows `SavedProgression`: a `uid` set in `init`, declaration defaults, and the
  content as one JSON blob with a version, the notes, the bar lines, the sections and the tuning.
- A note of a kind this build can't read decodes as an unnamed note, so a tab from a newer build loses
  nothing it can show.
- **The archive** carries `writtenTabs`, Optional, with each payload as raw JSON so a newer build's
  kinds survive. **Restore** skips a uid already present, a repeated uid, and a payload that won't read,
  and adds a *Written tabs* line to its summary.
- **Not in a `.redmoonpractice` file, and no share, copy or export.** A tab you write is still a
  composition, which is 0150's question and 0232 D12's *Export tab*. It joins the same legal review.
- **Not in the Journal** (Context).

### D9 — How it's built: one editor, two users

A second editor would copy about 400 lines of Name the notes, the *Into it* flow and its copy included,
and drift. Making the sheet generic would mean faking a player. So:

- **The editing is pure:** `NeckCursor` and `NeckEditing` hold the rules for placing, marking, joining
  and moving on, lifted from the sheet line for line and unit-tested.
- **The view is shared:** `NeckNoteEditor` draws the neck, the marks, *Into it* and *Chords* for both.
  Name the notes keeps every string byte for byte, and a snapshot before and after proves it draws the
  same.
- **The rest is pure too:** `PieceNotes` (a piece's notes without the seconds, which are never faked),
  `EditHistory` (Name the notes' history, made generic), `TabContent` (bar lines and sections, and how
  they shift), `TabDraft` (the slot), and `ToolkitSection`, the one list that both the Toolkit's rows
  and the tile's choices read.

## What stays out

- Typing or importing tab, and durations.
- Playing a tab back.
- Share, copy and export (D8).
- The Journal, and Map the song. A written tab has no song time to sit on.
- *By ear*, snags and *Next unnamed* in the writer (D3).
- The Oracle, and where it would go if it came back (D7).

## Build order

On `pocket-341-write-a-tab`, each commit able to stand alone:

1. This record, with the back edges in 0211, 0197, 0225 and 0227.
2. `PieceNotes`.
3. `EditHistory`.
4. A seeded route into Name the notes for UI tests, with 0234's owed tap-against-hold test.
5. `NeckCursor` and `NeckEditing`.
6. `NeckNoteEditor`, extracted.
7. The neck's accent as a parameter.
8. `TabContent`, and bar lines and headings in the drawing.
9. `TabDraft`.
10. `WrittenTab`, the archive and restore.
11. `ToolkitSection`, My tabs and the writer.
12. The Home tile and its setting.
13. Docs.

## Consequences

- **Manual:** `toolkit.md` and `reference/tools-and-journal.md` gain My tabs and the writer;
  `home-and-library.md`, `getting-started.md`, `reference/settings.md`, `gestures.md` and `subscription.md`
  gain the tile, its hold and its setting.
- **Reshoot owed:** the Toolkit hub, Home, and new figures for My tabs, the writer and a drawn tab, shot
  once with the other owed figures.
- **Device check:** done 2026-09-30 on an iPhone 16 Pro (iOS 26.6): the tile's hold menu; placing,
  inserting and taking out; bar lines and sections; a drawn tab at phone width; and a store with real
  data upgrading (the same songs and loops by row, and `ZWRITTENTAB` created).
- **Schema:** checked as an upgrade on the simulator (main's build made the store, then this one opened
  it: same store, a `ZWRITTENTAB` table with its five columns, and the app ran).
- `design-brief.md` loses *six destinations, six hues*: two tiles now share one on purpose.
