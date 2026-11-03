# ADR 0286 — The Journal thread: one unit's rows, together

- **Status:** Accepted. Agreed with Tomisin on 2026-11-03 from the mockup
  https://claude.ai/artifact/XHW8kNppGcJ8GbSiVHJvYC, with the first-to-latest line and without a Write
  button. Item 7b of the last feature push before 1.4.
- **Date:** 2026-11-03 (`pocket-406-journal-thread`)
- **Amends:** ADR 0190, on how the feed is narrowed: D5's facets narrow it by *kind* of owner, and this
  adds a way to see **one** owner's rows, as a pushed screen rather than a facet, so D8's rule for
  persisting a filter is not engaged. D1–D10 otherwise stand.
- **Relates to:** 0142 (J5 stands: the caption still opens the unit, and the thread's **Open** goes to the
  same place), 0100 (one feed of notes and takes, which the thread keeps), 0151 (a row whose unit was
  deleted keeps its caption and gets no count), 0229 (a piece counts toward its loop), 0070 (the
  first-to-latest line sets two snapshots side by side and says nothing about them), 0285 (a thread's
  rows keep the swipe to delete)
- **Schema:** none.

## Context

Every row in the Journal is one moment, which is right: each note snapshots where its exercise or loop
stood when it was written. But nothing on a row says the same exercise or loop has five more, and the
only way to read them together was to leave the Journal. The caption opens the unit (ADR 0142 J5), and
its run screen's **Journal** pill opens its notes, with its takes behind a separate pill. Searching the
unit's name came close, but it also matched any note that mentioned the words.

The snapshots are what is lost. A note's tempo means something read in order (80, 84, 88, 92, 96 BPM over
three weeks) and little as one number in a feed of everything.

Raised by Tomisin on 2026-11-02: *"there's nothing in there that indicates whether it's one of many for
the same exercise or loop."*

## Decisions

**D1. A count ends the caption line when a unit has more than one row.** *6 entries*, in a neutral pill
after the caption, on note, take and piece rows. One row has nothing to gather, so it gets no count. The
caption is unchanged and still opens the unit; the pill is its own button and opens the thread. Grey, not
the caption's gold, so the line reads as two things and not as one long link.

**D2. The count is the rows the thread opens on.** It counts the unit's rows under the feed's scope picker
(All, Notes, Takes), and nothing else: search, *Pinned only* and Show don't change it, because the thread
is the whole unit. A unit with five notes and one take shows no count under Takes. Rows waiting on Undo
are not counted.

**D3. The thread is a pushed screen, not a filter on the feed.** A filter applied in place needs a way to
clear it, rebuilds the feed when cleared, and loses the place. It would also raise whether it is saved with
the feed's other filters (ADR 0190 D8). A pushed screen has neither problem: Back puts the feed back where
it was, and there is nothing to save. The thread's scope starts on the feed's and is not saved.

**D4. The thread is the Journal screen in a second mode.** So its rows keep every verb: play, pin, rename,
Delete by swipe or hold with its Undo, a take's own screen. Above the rows it has a header (the kind and
count, the unit's full name, and D6's line), a scope picker of All, Notes and Takes, and **Open** in the
toolbar, which goes where the caption does. No search, no ⋯, no ＋, and **no Write button**: writing on a
unit stays on its run screen, where the snapshot is honest. Rows drop their caption, since the header
names the unit once, as the Pieces list's song heading does.

**D5. Holding a row offers *Show all 6 for …*,** above Delete, when the count would show. It is the same
thread, and VoiceOver's way to it. The count's own label reads *Show all 6 entries for …*.

**D6. The header shows the first and latest snapshot.** *80 → 96 BPM · 8ths since 12 Oct* for an
exercise, mastery dots and percent at each end for a loop. Only notes keep a snapshot, and only those that
kept one count. If the rhythm changed, both ends are written in full, because 80 BPM in sixteenths is not
80 in eighths. Nothing shows with fewer than two readings, or when the two ends are equal: *96 → 96* says
one fact twice. The line never comments on the change (ADR 0070).

**D7. Rows that belong to no single unit get no count.** A session note, a Just me note or take, a
metronome note and a song's take are not about one exercise or loop. A row whose unit was deleted keeps
its caption (ADR 0151) but has no link to gather by. Metronome notes are already gathered by Show →
Metronome. A session note could be threaded by its routine later; that is not decided here. A piece and a
note on a snag count toward their loop.

## Consequences

- `JournalTimeline+Unit.swift` holds the pure half: `UnitRef`, `unit(for:)`, `unitName(for:)`,
  `unitCounts` (one pass, asked once per render), `filter(_:unit:)` and `readingSpan`. Tested in
  `JournalTimelineUnitTests`.
- `JournalOwnerCaption` takes a `JournalThreadLink`, drawn as `JournalThreadCount`. The three rows pass it
  through; the per-owner `JournalSheet` passes nothing.
- `JournalTabView` gains `thread` and `threadScope`, and pushes itself by `UnitRef` (a stable `uid`, ADR
  0090). Its body splits into the feed's chrome and the thread's (`JournalTabView+Thread.swift`).
- The manual's Journal pages describe the count and the thread; a figure is owed at the one reshoot.
