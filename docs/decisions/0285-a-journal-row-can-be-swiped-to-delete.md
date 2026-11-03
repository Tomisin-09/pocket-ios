# ADR 0285 — A Journal row can be swiped to delete

- **Status:** Accepted. Agreed with Tomisin on 2026-11-02 as item 7 of the last feature push before
  1.4: a trailing swipe, no full swipe, the Undo toast kept, no multi-select.
- **Date:** 2026-11-03 (`pocket-404-journal-swipe-delete`)
- **Amends:** ADR 0100, its read-only bullet as amended on 2026-08-05: on the Journal feed, Delete is
  no longer press-and-hold only. A trailing swipe offers it too, without a full swipe. The hold menu,
  the deferred delete with its Undo toast, and a take's Rename on the leading swipe all stand. A unit's
  own Takes list stays hold-only; that is not decided here.
- **Relates to:** 0190 (Pin stays in the hold menu; its D3 was about a take's leading edge, and this is
  the trailing one), 0167 (a verb offered only on a swipe goes unfound, so Delete stays in the hold menu
  as well), 0229 (a piece row has no Delete, by swipe or by hold)
- **Schema:** none.

## Context

ADR 0100 made the Journal read-only, and its 2026-08-05 amendment let every row be deleted, but only
from the hold menu. The reason was what a row is. An exercise deleted by mistake can be built again
from the same idea, but a note about how a session went, or a take of someone playing, cannot. A swipe
is the cheapest gesture in a list and the easiest to fire while scrolling, so Delete went behind the
deliberate gesture, with the Undo toast as a second line of defence.

Every other list in the app deletes on a trailing swipe, so the Journal was the one list where the
gesture people reach for first did nothing. Tomisin asked for it while planning the last feature push
before 1.4 (2026-11-02), with the shape set then: trailing, no full swipe, the Undo toast kept, and no
multi-select.

## Decisions

**D1. A trailing swipe on a note or a take offers Delete.** It calls the same `requestDelete` as the
hold menu, so a swipe's delete is deferred and undoable in exactly the same way, and a take's audio
file is removed only when the Undo window closes. A piece row gets no swipe. It belongs to its loop,
and has no Delete in the feed at all (ADR 0229).

**D2. No full swipe.** `allowsFullSwipe: false`, so the swipe only shows the button, and deleting
takes a second tap on it. This is what answers ADR 0100's worry: a swipe fired by accident while
scrolling deletes nothing. It takes two actions, the second aimed at a red button that says Delete.

**D3. A plain button tinted danger, not `role: .destructive`.** On a swipe, the destructive role plays
SwiftUI's own row-removal animation the moment it is tapped. Under a deferred delete that takes the row
away on a lie, and Undo cannot bring it back. This is the second cause recorded in `RowUndoUITests`.
The row leaves because the feed filters out anything pending, and returns on Undo for the same reason.
In the hold menu the role only colours the label, so it stays there.

**D4. The hold menu keeps Delete.** A verb offered only on a swipe is one most players never find (ADR
0167), and the hold menu is also VoiceOver's way in. The two doors lead to one action.

## Consequences

- `JournalTabView+List.swift` adds the swipe to note and take rows. `JournalTabView+Deletion.swift`
  owns the button (`deleteSwipe(for:)`) beside the hold menu, and its comment no longer calls the hold
  the only way.
- `RowUndoUITests` gains `testJournalSwipeShowsDeleteAndUndoRestoresTheNote`. It checks that a swipe
  alone starts no delete, then that Delete and Undo bring the note back.
- The manual's Journal pages stop calling deleting hold-only.
- The per-owner `JournalSheet` already deleted on a swipe (`onDelete`). That was ADR 0058's authoring
  sheet, not this feed, and it is unchanged.
