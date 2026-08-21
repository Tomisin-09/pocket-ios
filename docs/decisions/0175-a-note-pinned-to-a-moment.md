# ADR 0175 — a note pinned to a moment

- **Status:** Accepted
- **Date:** 2026-08-20 (`pocket-280-timestamped-take-notes`)
- **Relates to:** ADR 0174 (a take you can move around in — this builds the thing its
  *Alternatives* section parked), ADR 0069 (practice-take recording), ADR 0151 (a take
  outlives its loop — the delete rule this deliberately inverts), ADR 0090 (present model
  screens by a stable `uid`), ADR 0153 (only a view that draws a moving playhead may read
  one), ADR 0165 (the manual quotes the app)
- **Schema:** one additive entity (`TakeNote`) and one additive cascade relationship
  (`Recording.moments`). No pre-existing rows to migrate, nothing destructive; safe under
  the post-1.1 freeze.

## Context

ADR 0174 gave a take a screen, a scrubber and a note, and closed with the version it did not
build:

> **A timestamped note pinned to a point in the take.** The interesting version, and the one
> that would have paid the scrubber back twice. Declined for this pass as materially more
> work […] and left as the natural next step if whole-take notes prove too coarse.

They are too coarse, and the shape of the coarseness was predictable. A whole-take note is one
box for a four-minute artefact, so it collects the summary judgement — *rushing throughout*,
*better than yesterday* — and loses everything that has a location. "The turnaround at 1:20 is
where it falls apart" is the more useful sentence and the one the box cannot hold, because
without the number you have to hunt for the bar again every time you come back.

The scrubber built in 0174 is what makes the number worth writing down. Before it, a timestamp
was a fact you could not act on; now it is a destination.

## Decision

### 1. A moment is a new entity, alongside the take's note — not instead of it

`TakeNote`: `uid`, `time`, `text`, `createdAt`, and `recording` as the inverse of a new
`Recording.moments`. `Recording.note` is **untouched**.

The tempting move was to collapse the two — one notes list where `time` is optional, the old
whole-take note migrated in as the un-pinned entry. It was declined. It buys a tidier screen
at the cost of a lazy migration over a field that shipped a day ago, and it makes the model
say something false: *rushing throughout* is not a note whose timestamp happens to be missing,
it is a different kind of remark about a different subject. Two fields that answer two
questions is the honest shape, and it costs nothing to migrate.

So the screen carries **Note** (about the take) and **Moments** (about points in it), in that
order, and the row glyph now means *something is written here* — `hasWriting`, not `hasNote`.

**The word is "moment"**, and the vocabulary was forced. *Marker* is taken twice over: a song
has markers on its timeline, and the manual already uses the word for the glyph on a take row
that says a note exists. *Note* alone collides with the take's own note sitting directly above
it, and with the Journal's Notes filter. Moment is unclaimed, and it names the thing.

### 2. A moment is cascade-owned — the opposite of the take's own rule

`Recording.moments` is `.cascade`, where `Loop`/`Exercise`/`Song`.`recordings` are `.nullify`.

That inversion is deliberate and is the clearest statement of what a moment is. ADR 0151 keeps
a take alive past its loop because the audio is the one artifact in the app that cannot be
remade; a caption can be snapshotted, a loop can be rebuilt, a recording of you playing on a
Tuesday cannot. A moment is the other kind of object entirely: a pointer *into* that audio,
unreadable once the audio is gone. There is no `ownerLabelAtTake` equivalent to save it with,
because there is nothing to save — the words only mean anything over the seconds they point at.

### 3. A trim drops the moments whose audio it removes, and says how many before it does

This is the decision the feature turns on, because trimming is destructive (0174 §2) and
moments are pinned to a timeline the trim moves.

- A moment inside the keep-span is **rebased** by `keepStart`. A note at 1:20 in a take trimmed
  to keep from 0:40 is a note at 0:40, still over the same audio.
- A moment outside it is **deleted with the audio it described**.
- The confirmation names both losses: *"This removes 3:12 from the take, and 2 notes with it.
  It can't be undone — 0:47 is kept."*
- While the handles are being dragged, the pins that would go are drawn **faint**, by the same
  rule the discarded bars follow. The dialog says how many; the strip says which.

**Clamping to the nearest edge was rejected.** It loses nothing, which is its whole appeal, and
it lies: a note survives pointing at audio it was never about, several of them stack on one
instant, and the player has no way to tell a real 0:00 note from three refugees. The note is a
pointer, and when the passage goes there is nothing honest left for it to point at. Dropping is
the truthful outcome; naming the count in the confirmation is what turns it into a choice.

The rebase runs **only after `TakeTrimmer` returns**. Every failure path in the trimmer leaves
the file byte-identical (0174 §2), and the notes have to be left untouched with it — a trim
that failed must not have quietly deleted three of them on the way. The drop decision uses the
span the player was shown and agreed to, so what happens is exactly what the confirmation
counted; surviving positions are then clamped into the length the **encoder** produced rather
than the one that was asked for, because that is the audio a mark can now point into.

`TakeMoments` holds all of this and imports neither SwiftUI nor SwiftData, for the reason
`TakeTrim` does: a moment left on its old seconds after a trim renders perfectly — a plausible
timecode, a pin on the strip, and the wrong audio underneath it. There is no crash and no empty
state to notice, so it is unit-tested rather than eyeballed.

### 4. **Add note here** carries no live timecode

The obvious label is *"Add note at 1:47"*. It is forbidden here.

That label reads `player.position` from the screen's body, which would re-execute it twenty
times a second — the exact invalidation class ADR 0153 exists to prevent, on the one screen in
the app that already draws a `Canvas` and carries a menu, three sheets and a confirmation. 0174
called 0153 "load-bearing here" and confined the position to the `PlayheadTakeScrubber` leaf;
the first feature built on top of it is the first chance to give that away.

So the position is read **once, on the tap**, and the sheet shows the time it caught. Playback
**pauses** on the way in: the note is about this instant, and a take running on behind the sheet
moves the thing you are describing away from the timestamp you just took.

### 5. The editor is presented by a draft, not by a model

`TakeMomentDraft` — a plain `Identifiable` value carrying an optional `noteUID`, the time and
the text.

A moment being written for the first time has no row to present by, and the alternative is
inserting an empty `TakeNote` just to have something to bind to and then reaping it if the sheet
is cancelled. Carrying a draft means nothing is written until Save, and it sidesteps ADR 0090
for free: there is no `persistentModelID` in the item to flip temp→permanent underneath an open
editor.

### 6. Empty is refused here, where the take's note allows it

`Recording.setNote("")` clears the note — 0174 made that the delete gesture, because there is
only ever the one and no row to swipe. A moment is a row in a list with a real delete of its
own, so emptying the text would be a second, quieter way to do the same thing. `setText` and
`addMoment` both refuse a blank result, and Save is disabled on one.

### 7. Moments stay off the Journal feed, like the note before them

0174 §3 kept a take's note on the take's own screen and out of the feed and its search rail, and
pinned the absence with a test so it would read as a decision. Nothing about a timestamp changes
that argument — it strengthens it. A moment is *less* readable away from its strip than a whole-take
note is: "this is the one" on the Journal timeline, detached from the audio and the 0:31 it points
at, is noise. `TakeNoteTests` pins it the same way.

## Consequences

- **The scrubber pays for itself twice**, as 0174 predicted. Writing a moment needs a playhead
  to read; using one needs a seek to jump to. Both already existed.
- **A trim can now destroy writing, not just audio.** It is named in the confirmation and shown
  on the strip, and that is the whole defence — the same posture 0174 took, extended to cover
  the new thing at risk.
- **The row glyph changed meaning** from *has a note* to *has writing*. Both surfaces that draw
  it moved together (`JournalTakeRow`, `TakesSheet`), and its accessibility label with them.
- **`Recording.note` gains a neighbour rather than a successor.** If moments turn out to be the
  only note anyone writes, the collapse in §1 is still available and is *cheaper then* than it
  is now — the migration would have a year of real data to tell it what the un-pinned notes
  actually say.
- **The seeded take carries two moments**, so the Moments list and the strip's pins have
  something to show — the same reason 0174 gave the seed a note and real audio.
- **The manual gains a figure** (`journal/take-moments`) and the shoot gains the test that
  drives it.

## Alternatives considered

**One unified list with an optional time.** The tidier screen, and genuinely better if a
whole-take note turns out to be a thing nobody writes. Declined because it needs a migration
over a field one day old, and because it flattens two different kinds of remark into one row
shape. Recorded because it stays available, and gets cheaper with data rather than more
expensive.

**Clamping trimmed-out moments to the span edges.** Covered in §3. Loses nothing and means
nothing.

**A moment as a `JournalEntry` with a new owner kind.** Would put moments on the feed and its
search rail for free — and 0174 already refused this for the whole-take note, on grounds that
apply harder here (§7). It also drags in the caption snapshot, the delete rule and the
composer's chip row for what is a timecode and a sentence.

**Naming them "markers".** Consistent with a song's timeline, and unusable: the manual already
spends the word on the take row's glyph, and a take screen that says *marker* twice for two
different things is worse than a new word.

## Related

- `docs/manual/journal-and-practice-log.md` § Takes — the user-facing account.
- `PocketUITests/ManualShotsUITests.swift` — `testTakeMoments`.
