# ADR 0318 — A save says when it fails

- **Status:** Accepted on 2026-11-24, for 1.6.1, and built on `pocket-477-save-errors`. Tomisin asked
  about saves that "ignore their errors", and took the split proposed here (D3) as written.
- **Date:** 2026-11-24
- **Relates to:** 0188 D7 (a restore writes its rows before its files; D6 here is what happens when the
  rows can't be written) · 0239 (no analytics, so a failure is logged on the device and nowhere else) ·
  0058 and 0088 (the Journal sheet and its hosts, D7) · 0069 (takes, and the line that says one was
  saved) · 0243 (temporary sessions) · 0090 (a `@Model` presented by `StableRef`)
- **Schema:** none. Nothing stored changes.

## Context

All but three of the app's saves were `try? context.save()`: 117 of them in 73 files, five in debug
seeding. The error was thrown away. Nothing suggests a save fails today, but if one did (a full disk is
the likely way), the change stayed on screen, was gone after the next launch, and nothing anywhere
recorded it.

How bad that is depends on the context. The main context autosaves, so a single failure there is
retried, and only a failure that keeps happening loses anything. The routine editor's sandbox has
autosave off: its Save left edit mode as if it had saved, and the edit was gone. Some failures did
worse than lose a change:

- **A take** said *Take saved* whether or not it was.
- **Starting a new session** saved the routine and then looked it up in the store to open the player.
  If the save failed, the player didn't open, and nothing said why.
- **Receiving** a shared exercise, routine or song said *Added* whether or not it was.
- **A restore** saved its rows and then wrote its files, by 0188 D7. If the save failed it wrote the
  files anyway, with no saved row to own them, which is what *Reclaim space* deletes. The rows stayed
  pending, to be saved later without their files.

## Decision

### D1 — One way to save, and a lint rule that keeps it the only way

`ModelContext.saveOrLog()` (`Core/Storage/ModelContext+SaveOrLog.swift`) saves, and if the save fails
it logs to the device's log and returns false. The log line names the file and line that saved and the
error's domain and code in the clear, so a sysdiagnose says what failed. The error's description is
marked private, because a SwiftData error can quote a model's values, and those are the player's.
Nothing leaves the device (0239).

All 117 `try?` saves, and the one backfill whose `catch` returned without a word, now call it. A caller
with something to do on failure reads the result. The rest ignore it, which changes nothing a player
sees. `.swiftlint.yml`'s `save_error_discarded` rule bans `try? ….save()` in the app, so the count stays
at zero.

### D2 — What a failed save says, and what *Try again* does

**Couldn’t save** — *It’s still here, but it isn’t saved yet. If your iPhone is nearly full, freeing
up some space should fix it.* — with **Try again** and **Cancel** (`SaveFailedAlert`).

- **The screen stays as it was.** A sheet stays open rather than closing on work that hasn't been
  kept. The change is still in memory, and the next save that works keeps it, so *Cancel* loses
  nothing that wasn't already at risk.
- **Try again repeats the save, never the edit.** Every site splits its edit from a `commit()` that
  saves and then does what followed (closes the sheet, leaves edit mode, opens the player), and *Try
  again* calls `commit()`. Repeating the edit would add a moment twice, or find nothing changed and
  save nothing.
- **Save again doesn't write twice either.** A sheet that stays open can be saved again from its own
  button instead of the alert. A new goal, long-term goal or skill is remembered once made, and Save
  edits it. A take moment remembers the note it wrote. Where the writer can't hand back what it wrote
  (the quick note, the link editor), the fields lock after the write, so what's on screen is what was
  written, and Save only saves.
- **On the screen's root, never on a `Section` or a row.** A modifier inside a `Section` builder has
  crashed a screen before while every test stayed green. Where a component draws inside a list (the
  note composer, Count the notes), the alert goes on one row that is never disabled.

### D3 — Which saves say so

*Proposed here, decided by Tomisin.* The ones that follow a tap that asks for something to be kept:

- **Writing:** a take's note, renaming a take, a take moment, the Journal sheet's add and edit, the note
  composer, the quick note, a snag's line (both places), *Name the notes*' Done, Count the notes' Save.
- **Goals and skills:** a goal, a long-term goal, a custom skill.
- **Editing:** Edit shape (one save now, where Done made five), the routine editor's Save, a new or
  temporary session's Save, *Start* on one (D5), *Save as a routine* on the finish screen, a new
  routine from *Add to routine*.
- **References:** adding or editing a link or a source, attaching one.
- **Takes:** stopping a take (D4), a trim.
- **Bringing something in:** receiving, restoring (D6).

The rest log and say nothing:

- **What runs on its own:** launch backfills, preset seeding, the practice log a run writes, a
  waveform's cache, debug seeding, previews.
- **Leaving a screen:** the run screens save on the way out, when there is no screen left to say it on.
- **Toggles and small edits on a screen** (the metronome, mastery, a pin, a reorder, linking a song):
  the change stays on screen, and the next save that works keeps it.
- **Deletes:** a delete that fails to save only brings the row back after a relaunch.

### D4 — A take is saved only when it's saved

`RecordingController` sets `lastSaved`, which *Take saved* reads, only when the take's save works.
When it fails, the take is `unsavedTake`. `reportsUnsavedTake(_:)` sits beside
`endsTakeOnInterruption` on every screen that records, so each says *Couldn’t save*, and *Try again*
saves it and then says *Take saved*.

### D5 — *Start* opens the player only on a saved session

A new or temporary session is saved before the player opens on it. If that save fails, the routine
screen says *Couldn’t save*, and *Try again* saves and then opens the player. The routine editor's saves
live in `RoutineDetailView+Saving.swift`, which also keeps the main file under 400 lines.

### D6 — Bringing something in

- **Receiving** says *Added* only once the save works. Before then it says *Couldn’t save*.
- **A restore that can't save adds nothing.** It stops before writing a file, takes its rows back out
  with `rollback()`, and says **Couldn’t restore**: *Nothing was added. If your iPhone is nearly full,
  freeing up some space and restoring again should fix it.* Restoring again is the retry. 0188 D7's
  order stands; this is the case D7 didn't cover.

`rollback()`, not deleting the rows: after a failed save, deleting the inserted rows doesn't cancel
them, and a rollback does (`SaveOrLogTests`). A rollback drops every unsaved change in the context,
which the failed save had already failed to keep.

### D7 — The Journal sheet writes its own entries

`JournalSheet` writes through `JournalWriter` and saves for itself. Its four hosts (the exercise and
loop run screens, the freeform block, the loop's sheet on the waveform) passed the same three
callbacks, and a host that passed none got a journal whose Add, edit and delete did nothing, which the
freeform block once shipped. Saving in the sheet is also what lets a failed save say so on the sheet
rather than on the screen under it.

### D8 — A UI test can fail a save on purpose

`-failSaveIn <file>`, under `-uiTesting` in a Debug build, fails the first save made from that file,
once (`SaveFailureDrill`). `SaveFailedUITests` uses it on the quick note: the alert shows, the sheet
stays open, and *Try again* saves the note once and closes it. No build a player holds can fail a save
this way.

## Alternatives considered

- **One alert at the app's root.** One modifier instead of thirty. Rejected: an alert at the root
  can't present over a sheet, and most of these saves happen on one.
- **`assertionFailure` in Debug.** Rejected: it would stop a UI test on any failing save and still
  say nothing in a build a player holds.
- **Undo the edit on a failed save.** Rejected: it throws away the player's work at the moment they
  asked for it to be kept, when the next save may well work.
- **Restore into a context of its own,** so a failure never touches the main one. Rejected: a
  sibling context's save doesn't reach the main context's relationships (a loop's song), which is the
  graph a restore writes.
- **A message on every save.** Rejected in D3: a toggle that fails to save is still on screen and is
  kept by the next save, and a background save has nowhere to say it.

## Consequences

- A failure is now in the device's log under `click.decooperations.pocket`, category `store`, with the
  file and line. It isn't in the app's Diagnostics screen, which reads only crashes and hangs.
- **After a failed restore, the screen can show the restored rows until a relaunch.** After a failed
  save and a rollback, SwiftData's fetches in that context are unreliable: its count and its fetch
  disagree. Nothing is pending and nothing is stored, so the rows go at the next launch.
- A save that fails in the background (a backfill, the practice log) is logged and retried at the next
  launch or the next save. None of them say so, by D3.
- Tests: `SaveOrLogTests` (works, fails without throwing, a rollback after a failed save, a temporary
  session's save, the switch's parsing), `RestoreCoordinatorTests.testARestoreThatCantSaveAddsNothing`,
  `SaveFailedUITests`. The lint rule, the helper and both new tests were each broken on purpose and
  caught.
