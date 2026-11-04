# ADR 0290 — The import sheet

- **Status:** Accepted. Planned with Tomisin as item 15 of the last feature push before 1.4 (the approved
  plan of 2026-11-02: *"Import: a friendlier loading screen"*), and built that week.
- **Date:** 2026-11-04 (`pocket-411-import-sheet`)
- **Relates to:** 0011 (persistence, whose Slice 2 brought file import; the card and the alert that grew
  around it were never an ADR of their own, so this records them rather than amending 0011) · 0273
  (audio shared in from another app, which keeps the card) · 0090 (a song opened after a sheet, by a
  Bool, never by its model id) · item 5a of the same push (the card made opaque and naming the file)
- **Schema:** none.

## Context

Picking several songs at once showed a card over the screen, *Importing "Binta"* and *2 of 5*, and then
an alert: *Some files were skipped. 2 files couldn't be read: Little Wing, take 3.* The alert said which
files failed but not why, and the songs that did import had to be found in the library afterwards. A
single file opened straight on its waveform, which is right, and stays.

## Decisions

**D1. Several files read under a sheet.** When more than one file is picked, a sheet lists every file
in the order picked, each row saying where it is: *Waiting*, *Reading the file…* (with a spinner),
*Added*, or why it was skipped. The title counts the file being read (*Importing 2 of 5*), then says
what happened: *Songs added*, or *Some files were skipped*. The sheet replaces both the card and the
alert for a batch.

**D2. Why a file was skipped**, in words that say whether trying again could help:
- *Red Moon wasn't allowed to open it. Try picking it again.* (the picker's access was refused)
- *There's no audio in it.* (an empty file)
- *It couldn't be read. A copy-protected file can't be imported.* (anything else, most often DRM;
  ADR 0001)

**D3. An added song opens from its row.** Tapping it closes the sheet and opens the song's waveform once
the sheet has gone, since a push can't start under a sheet. The open is Bool-bound, as every
open-on-create is (0090). *Done* closes the sheet. From Home, closing it after something was added
goes to the library, where Home used to send a batch.

**D4. One file keeps the card**, and opens on its waveform as before. A sheet raised and closed again
for one quick file would flash. A single file that's skipped shows the sheet, finished, with the one
row and its reason, in place of the alert.

**D5. It can't be swiped away while files are still being read.** That keeps the picker from being
opened again halfway through, which the card did by covering the screen. *Done* appears once every file
has been read.

**D6. Share-in keeps the card** (0273). Audio shared from another app is always one file, and it opens
on its waveform or says so where it lands.

**D7. VoiceOver hears the outcome** when a batch finishes: *Imported 2 songs. 1 file couldn't be read:
take 3.* This is the alert's old message, now `SongImportSummary.message`.

## Consequences

- New: `SongImportBatch` (pure, `SongImportBatchTests`) and `SongImportSheet`. `SongImportModel` keeps
  each file's state, the song each became, and the song to open after the sheet. The completion alert
  and `SongImportModel.summary` are gone. `songImportFeedback` takes `open` and `afterBatch`.
- The import path itself is unchanged: `SongImporter.prepare`, then `persist`, one file at a time, off
  the main actor.
- **Device check owed (Tomisin):** import several files with one that won't read, and open one from the
  sheet.
