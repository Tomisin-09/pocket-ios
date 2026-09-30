# ADR 0233 — Versions of a piece: saving again keeps the one before

- **Status:** Accepted. Built on `pocket-339-map-the-song`, beside ADR 0232.
- **Date:** 2026-09-30
- **Amends:** ADR 0225 — **D6**: *Save* over a saved piece no longer replaces it after a prompt. The new
  pass becomes the piece in use, and the one it takes over from is kept as an earlier version, with no
  prompt. The rest of D6 stands: how a piece is stored, *Edit names* editing it in place, and the archive
  carrying it as structure. ADR 0229 — its Consequences' "earlier counts are no longer kept anywhere":
  they're kept on the loop, as versions. D1's one row per loop stands, and the row is the version in use.
- **Relates to:** 0232 (the map, its tab and *Copy to…* read the version in use and nothing else) · 0189
  (additive schema criteria) · 0188 (the archive).
- **Schema:** one additive field, `Loop.keptTranscriptionsData` (D2), and an optional
  `LoopRecord.keptTranscriptions` in the archive (D6).

## Context

Tomisin, 2026-09-29, while the map was being built: "allow multiple pieces for the same loop, though only
one can be active." Asked what that meant, they chose **versions of one piece** over *different parts of
one stretch* (a chords piece and a riff piece on the same loop).

Today a loop holds one piece (0225 D6). Saving another pass over it asks *Replace the saved piece?*, and
the old one is gone. That costs two things. A transcription you thought was right can't be got back once
you've tried again. And a second reading of a passage, the same lick in another position or a chord heard
another way, can only be tried by losing the first.

## Decisions

### D1 — One piece in use, earlier versions kept

- A loop has **the piece in use**, `Loop.transcription` exactly as today, and any number of **earlier
  versions**. Each is a whole piece: its taps, its names, its tuning and its date.
- **Everything that reads a piece reads the one in use, and only that**: the map and its tab, the loop's
  tab sheet, *Copy to…*, the Journal's Pieces, and whether Practice or Improvise can open the loop. None of
  them changes.
- The app calls them **versions**. In code they're the loop's *kept* pieces, because
  `PieceTranscription.version` already names the piece's format.

### D2 — Storage: a second field, and the first keeps its meaning

- **`Loop.keptTranscriptionsData: Data?`** holds an encoded `[PieceTranscription]`, newest first. It's
  Optional and additive under 0189's criteria, so a store from before this opens with none kept.
- **`transcriptionData` still means the piece in use.** A build from before this, an archive from before
  this and every reader today all see the right piece. Putting every version in one list with a pointer to
  the one in use would change what the existing field means, for no gain.
- **Not a model of its own.** Nothing looks a version up except through its loop, and a relationship is a
  heavier migration than a field.
- Kept versions decode as the piece does (0225 D6): a label this build doesn't know reads as an unnamed
  tap. A list that won't decode reads as none kept, and the piece in use is untouched by it.

### D3 — Save keeps the one it takes over from

- Saving a pass on a loop that already has a piece makes the pass the piece in use, and puts the old one
  first among the earlier versions. **There's no prompt**: *Replace the saved piece?* goes, because
  nothing is lost any more.
- **Edit names still edits the piece in use, in place** (0225 D6). Naming a count isn't a new reading of
  it, and a version per edit would bury the real ones. An earlier version is never edited: use it first.
- **No limit** on how many are kept. A piece is a few kilobytes, and the player deletes what they don't
  want (D4).

### D4 — Seeing and choosing a version

- **Saved on this loop**, under Count the notes, gains a **Versions** row when there's an earlier one:
  *Versions · 3*. It opens a **Versions** sheet: the piece in use first, marked *In use*, then the earlier
  ones, newest first. Each row has its date and its line of names, and its tab when it has frets, drawn as
  Saved on this loop draws them.
- **Use this version**, on an earlier one, makes it the piece in use. The one in use goes first among the
  earlier versions, so going back is the same action on it. Switching loses nothing.
- **Delete**, on an earlier version, asks first and removes that one only. The piece in use can't be
  deleted: use another one first. Nothing deleted a saved piece before this, and this doesn't start to.
- **The map's tab sheet** (0232 D2) has the same Versions row and sheet, because the map is where you see
  what each reading does to the song.

### D5 — Each version keeps its date

- A version keeps its own `changedAt` (0229 D2), whether it's in use or not. The Journal's Pieces row is
  dated by the piece in use, so using an older version moves the loop's row to that version's date.
  That's when that piece last changed: choosing it isn't a change to it.

### D6 — Copies and the archive

- *Copy to…* (0232 D16) copies the piece in use. A copy starts with no earlier versions.
- The archive carries them as **`LoopRecord.keptTranscriptions: [PieceTranscription]?`**, as structure
  like `transcription` (0225 D6) so the file reads. It's Optional, so a file from before this decodes, and
  Restore lands them.

## Build order

One slice: the field and its archive record; Save keeping the one before; the Versions sheet, from Saved
on this loop and from the map's tab sheet; the manual.

## What stays out

- **Naming a version** (*Live*, *Studio*). Its date and its line of names tell versions apart for now. A
  name would be one more optional key inside the piece, so it's cheap to add if it's missed.
- **Two versions side by side**, or an earlier version drawn on the map.
- **Editing an earlier version** without using it, and merging two.

## Consequences

- 0225's replace prompt goes, and Saved on this loop's footer says a new save keeps this one.
- A loop's first earlier version appears the first time a piece is saved over after this ships. Pieces
  replaced before it are gone, and nothing brings them back.
- **Manual:** the map's tab sheet gains Versions (`docs/manual/songs.md`), and the Journal's line on
  Pieces says it's the version in use (`journal-and-practice-log.md`). Count the notes has no page of its
  own in the manual yet; that's owed separately, not by this ADR.
