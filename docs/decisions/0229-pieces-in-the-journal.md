# ADR 0229 — Pieces in the Journal, not a line per save

- **Status:** Accepted. Built on `pocket-338-name-the-notes-on-the-neck`.
- **Date:** 2026-09-28
- **Amends:** ADR 0225 — **D7**: *Save* no longer writes a 🧩 *Transcribed* line to the loop's Journal.
  The Journal lists the loop's piece itself, one row per loop, under a new **Pieces** scope. The
  `.transcribed` kind stays, in the tag picker, for a lick worked out by hand, which D7 also provided
  for. D8 stands: the piece on the loop is still what the song map reads.
- **Relates to:** 0100 (the Journal space) · 0190 D7 (the scope control, the medium axis) · 0228 (a
  transcribed note opens ear training, which the piece row follows) · `docs/plans/song-map.md` (the
  map's "which loops are solved").

## Context

On the device: Transcribed entries pile up faster than any other kind, and editing one feels unlike
editing any other entry. Both come from what the line is.

- **It is a copy, not a record.** Every *Save* wrote a snapshot of the piece, and the piece on the loop
  is replaced by the next save. Only the newest line was ever true; the rest were stale copies.
- **Editing it edits the wrong thing.** The line was free text like any note, so an edit changed the
  copy and left the piece as it was. 0225 dropped a `.txt` tab attachment for exactly this drift
  (*edit pieces, never the picture*); the editable line was the same drift in the Journal.

## Decision

- **D1 — A piece is shown, not logged.** The Journal gains a third medium beside notes and takes: the
  loop's saved piece, **one row per loop**, drawn from `Loop.transcription` each time (`JournalPiece`,
  `JournalPieceRow`). The row shows 🧩 *Piece*, the count and names line, the tab and its tuning, and the
  loop as its caption.
- **D2 — Dated by when it last changed.** `PieceTranscription.changedAt`, an optional key inside the
  piece's JSON (no schema change), is set by *Save* and by an *Edit names* that changed something. The
  row sits on that day, so saving again moves it rather than adding one.
- **D3 — Its own scope.** The scope control becomes **All · Notes · Takes · Pieces**. *All* shows each
  piece once. The owner facet files a piece under *Loop*; the tag facet brings pieces in under 🧩
  *Transcribed*, beside notes tagged that way by hand; a piece is never pinned, so *Pinned only* leaves
  it out.
- **D4 — It opens where it's edited.** Tapping the row or its caption opens the loop in *Train your
  ear*, where the piece was made and where *Edit names* is. There is no hold menu: a piece isn't pinned
  or deleted from the feed, and it has no text of its own.
- **D5 — Save stops writing the line.** Lines already written stay, as ordinary notes the player can
  keep or delete. A piece saved before this is dated by its loop's newest 🧩 line, or, with none left,
  by the first launch that sees it (`PieceDateBackfill`, run every launch because a piece restored from
  an older archive arrives undated too).

## Alternatives rejected

- **A separate sheet for pieces.** Takes already live beside notes as a scope; a sheet would hide pieces
  from *All* and add a door to find them.
- **Keeping the line, collapsed to one per loop.** Still a copy that can be edited apart from its piece.
- **Stopping the line and showing nothing.** The Journal is where a player looks back over what they've
  done, and a worked-out piece belongs in that picture.

## Consequences

- **The dated trail of saves goes.** A piece is replaced on save, so earlier counts are no longer kept
  anywhere; the practice log still records the time spent in ear training.
- **The song map reads the pieces**, plus notes tagged 🧩 by hand, for which loops are solved, not the
  save lines (`docs/plans/song-map.md`, updated).
- **The Pieces scope is a cross-song list of everything transcribed**, which is what the map's Toolkit
  door was going to be; when the map lands, this is the index to group by song, not a second one.
- Pure and unit-tested (`JournalPieceTests`): which pieces show and when, the scope and both facets, the
  route, the backfill, and the new key's coding.
- **Owed to the reshoot:** the Journal figure (four segments now) and a piece row.
