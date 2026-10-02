# ADR 0238 — A line on a snag, from the waveform

- **Status:** Accepted. Built on `pocket-346-a-line-on-a-snag`. Still owed: the device check under
  Consequences.
- **Date:** 2026-10-02
- **Amends:** ADR 0202 — **D2**: a hold on a *Snags* row now opens a sheet, with one field, a line on
  the snag (D1). No multi-select, the song-order sort, tap to go there and ✕ to remove all stand. **D3**
  stands too: removing a snag has no undo toast, because its line outlives it (D5).
- **Amends:** ADR 0234 — **D7**: a snag's line can be written from the waveform as well as from *Name
  the notes*, and it's read from **every** loop on the song, not only the loop being named (D2). A new
  line written on the waveform goes to the loop the snag was made under (D3), and is 🧗 Struggle for a
  stumble (D4). The rest of D7 stands: the line is a Journal note tied by `JournalEntry.snagUID`, never
  🧩, and it stays when the snag goes.
- **Relates to:** 0200 (the one-tap mark, unchanged: nothing is typed while playing) · 0203 (D2's row
  caption, which names the loop a new line goes to; D1's positional rule, the fallback in D3) · 0228 (a
  line's caption opens the mode it was written in) · 0151 (a loop's notes outlive it) · 0090 (sheets
  present by `uid`) · 0070 (never grades)
- **Schema:** none. `JournalEntry.snagUID` (ADR 0234) already holds the tie, and the export already
  carries it.

## Context

Tomisin, on 2026-10-02: *"we can comment on snags in the transcription feature but not in the song
waveform."*

ADR 0234 D7 gave a snag a line, but only in *Name the notes*, as a link under the strip. The song
player's *Snags* panel, where every snag is listed, had *go here* and ✕ and nothing else. ADR 0202 D2
trimmed it to that on purpose: a snag had nothing to rename, recolour or rate. Since 0234 that's no
longer true. A snag has one thing worth writing, and the panel is where you see all of them.

Three ways to add the line were offered: a hold that opens a sheet, an inline *Add a line* link on
each row as in *Name the notes*, and a button beside ✕. Tomisin chose the hold.

## Decisions

### D1 — Hold a *Snags* row to write its line

- A hold on a row opens **Snag at 2:08**, a sheet with one field, *What's stopping you here?*, and
  Cancel / Save. Its footer says which loop's Journal the line goes to, and that the line stays if the
  snag is removed.
- It's the panels' own grammar: a hold on a loop or marker row already opens that row's sheet. The tap
  still goes there and plays, and ✕ stays its own target, outside the part that takes the hold, so a
  long press on ✕ can't open the sheet.
- **A written line shows under its row**, in the row's text colour, under the time.
- A hold can't be seen, so while no snag has a line, a quiet line under the rows says *Hold a snag to
  leave a line on it, for when you come back.* Once one line shows, the row explains itself.
- VoiceOver gets *Add a line* or *Edit line* as a named action, beside *Go here* and *Remove*.

### D2 — One line, read the same from both places

- The sheet writes the same note *Name the notes* writes: a Journal entry tied by `snagUID`. A snag's
  line is the latest such note **in any of the song's loops' Journals** (`SnagLine.lines`), and both
  places read it that way.
- `Loop.line(forSnag:)` used to look only in its own loop's Journal. A snag is a point on the song
  (0200 D6), and it's listed in *Name the notes* for whichever loop's span covers it, so a line written
  under one loop has to show when the snag is reached through another. Read narrowly, the two places
  would each offer *Add a line* for a snag that already had one, and split it in two.
- A line on a loop that has since been deleted is an ordinary note in the Journal (0151), and no
  longer a snag's line.

### D3 — A new line goes to the loop the snag was made under

- That's the loop the row names (0203 D2), so the caption and the Journal agree. A snag made in *Name
  the notes* was made under the loop being named, which is where that sheet writes it too.
- If that loop has been deleted, the line goes to **the tightest loop whose span holds the snag now**,
  the earlier of two the same length (the positional rule, 0203 D1).
- If no loop holds it, there's nowhere to write: a line lives in a loop's Journal, and a song has
  none. The sheet says so, and that making a loop over the spot gives it one. It doesn't write a
  standalone note: that would lose which song it was about (0155 keeps a standalone note unattributed
  on purpose).
- A loop waiting out its undo window (0125) is never given a new line.

### D4 — A stumble's line is 🧗 Struggle

- A snag made while playing marks where you fumbled, and *Struggle — a sticking point* is what that
  is. A note snagged while naming (`markedWhileNaming`) gets 👂 Ear, as *Name the notes* writes it, so
  its Journal caption still opens that note (0228).
- Never 🧩: the song map reads 🧩 as the loop solved by hand (0234 D7).
- The kind isn't offered in the sheet. A line changed later keeps its kind, and the Journal is where a
  kind is changed.

### D5 — Saved on Save, and it outlives the snag

- Save writes it straight to the Journal; Cancel drops it. An emptied line is taken out, as in *Name
  the notes*.
- ✕ on a snag still has no undo toast (0202 D3). The toast guarded nothing because a snag was an
  anonymous timestamp, and the words, which are now the authored part, aren't on the snag. They stay in
  the Journal. The sheet's footer says so, because ✕ is one tap.

## What stays out

- **Typing at the moment of the tap.** The snag stays one tap with nothing to fill in (0200). The line
  comes after.
- **A song-level Journal**, for a snag that no loop holds. That would be a new owner for every Journal
  surface, for a case the Snag button can't create: it only shows while a saved loop is running.
- **Choosing a kind in the sheet.**
- **The Oracle.** A snag's line was already a loop note it could read. What it does with one is not
  decided here.

## Consequences

- **Code:** `SnagLine` (pure: `home`, `kind`, `lines`); `Loop.line(forSnag:)` reads every loop on the
  song; `SnagLineSheet` and `PanelRowSheets` (the marker sheet moves into it beside the new one, keeping
  `WaveformPracticeView`'s body inside its length budget); `SnagsPanel` rows take a hold and draw their
  line. `NamingPieceSeed` now also clears its loops' notes, since the UI test writes one.
- **Tests:** `SnagLineTests` (the rules); `SnagLineUITests` (hold a row, write, see it under the row,
  read it back in the sheet).
- **Manual:** the *Snags* panel in `reference/song-player.md`, and an eleventh hold in `gestures.md`.
- **Reshoot owed:** no figure shows the *Snags* panel today, so nothing is stale. The panel with a line
  is worth adding when the one reshoot runs.
- **Device check owed:** a tap on a row never opens the sheet and a hold never seeks; the keyboard and
  the sheet at medium height.
