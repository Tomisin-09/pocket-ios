# ADR 0291 — Watch the section held back from 1.4

- **Status:** Accepted — built (2026-11-04, `pocket-415-hold-back-section-watch`)
- **Date:** 2026-11-04 (`pocket-415-hold-back-section-watch`)
- **Amends:** ADR 0289 — both of its doors **close for 1.4** (D1): the section heading's hold-menu item
  and the eye in the song map's toolbar. Everything it built stays where it is, and every decision it
  records still holds, unreachable until the doors reopen.
- **Relates to:** 0211 (the same move for the Oracle: its door closed, its code kept) · 0254 (watching one
  loop, which this leaves exactly as it is)

## Context

Tomisin's device check on 2026-11-04 found *Watch the section* "kind of laggy". On reflection the lag was
most likely the Journal's, which was rebuilding its feed hundreds of times a render (fixed the same day,
#406). The verdict on the feature itself stood: *"I feel like it could be better thought out. let's drop
it then put it in the post 1.4 backlog"*.

## Decisions

**D1. Both doors close for 1.4.** `SongMapView.opensSectionWatch` is `false`, and while it is,
`watchDoor` and `watchSongDoor` return `nil`. So a section heading's hold menu has no *Watch it on the
neck*, and the map's toolbar has no eye. Reopening is that one line.

**D2. The code stays.** `SectionWatch` and `SectionWatchTests`, `WatchOnNeckSheet`'s span subject, the
span region in `LoopRunModel` and `ContinuousLoopPlayer(song:from:to:)` all stay in the tree. Reverting
#402 would also have reworked the loop player again the day before 1.4 is submitted, which is the larger
risk. The unit tests keep passing because they test the pure merge.

**D3. Nothing describes it.** The manual's section paragraphs go (`songs.md`, `reference/practice.md`).
The CHANGELOG entry moves under *Held back — built, not shipped*, as 0211 did for the Oracle. The
whole-song UI test is skipped, naming this ADR, and runs again unchanged once the doors reopen.

**D4. What it becomes is open.** It's listed under *After the freeze* in `docs/backlog.md`. This ADR
neither rules out nor endorses 0289's decisions: a rethink may keep them, change them or start again.

## Consequences

- Watching one loop (0254) is unchanged, from every one of its five doors.
- 0289's owed device check (a section with two loops, and the whole song) is withdrawn: there's nothing
  to open.
