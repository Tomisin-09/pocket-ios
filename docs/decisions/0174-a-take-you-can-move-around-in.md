# ADR 0174 — a take you can move around in

- **Status:** Accepted
- **Date:** 2026-08-20 (`pocket-279-take-scrub-trim-note`)
- **Relates to:** ADR 0069 (practice-take recording — mic-only, and the retention story),
  ADR 0151 (a take outlives its loop, and the caption that survives it), ADR 0150 (take
  sharing, parked), ADR 0090 (present model screens by a stable `uid`), ADR 0153 (only a
  view that draws a moving playhead may read one), ADR 0041/0049 (the A/B span and the
  waveform's bar treatment, both reused here), ADR 0165 (the manual quotes the app)
- **Schema:** one additive optional attribute (`Recording.note`), no declaration default.
  Nothing destructive; safe under the post-1.1 freeze.

## Context

A take was a black box. `Recording` carried `uid`, `createdAt`, `duration`, `fileName`,
`title` and its polymorphic owner, and the only verb the app offered was *play from zero to
the end*. `RecordingPlayer` was a sixty-line `AVAudioPlayer` wrapper publishing which file
was playing and nothing else — no position, no seek. A take row was a play glyph, a name, a
duration and a date.

That leaves the feature short of the thing it exists for. You cannot get back to the bit at
1:20. A four-minute take holding forty seconds of playing stays four minutes and goes on
costing that on disk — and ADR 0069 already listed *storage grows with use* as the
consequence to watch. And the only thing a take could say about itself was its name, which
is why naming was bolted on in the first place (0069's amendment): a list of rows reading
"Take · 0:42 · 22:47" is unreadable.

Three verbs close that: **scrub**, **trim**, **note**.

## Decision

### 1. A take gets a screen of its own

None of the three verbs fit on a row, so `TakeDetailView` is pushed from the two surfaces a
take appears on — `TakesSheet` and the Journal feed.

The row becomes **two tap targets**: the glyph plays, and the title line opens. Not a
`NavigationLink` wrapping the cell, which would swallow the play control — and playing a
take from the list without leaving it is what the list was built for.

The screen is handed the **caller's** `RecordingPlayer` rather than owning one. One take
plays at a time across a surface and the screen it pushes, so a take auditioned from a row
and then opened is still the take that is playing.

Delete is **not** reimplemented: it is the `onDelete` closure the takes list already threads
to its owning screen, so the deferred, undoable delete keeps working from the detail screen
too. `deleteTake` is already duplicated across five run screens; a sixth copy was the wrong
direction.

### 2. Trim is destructive

The file is rewritten and the disk is reclaimed. The alternative — storing `trimStart` /
`trimEnd` and honouring them on playback — was cheaper, fully reversible, and was rejected
because it does not do the thing: a take you have trimmed to twenty seconds should stop
costing four minutes, and 0069 named storage as the pressure.

The price is real and is accepted: **a trim cannot be undone**, and a take has no source to
regenerate from. Deleting a take is a hold with an undo window for exactly that reason.
Trim cannot offer an undo once the bytes are re-encoded, so the guard moves forward instead:

- Trim mode is entered from the menu, never by touching the strip — the same reasoning
  `WaveformCanvas` gives for not making a saved loop's edges directly draggable.
- The commit is confirmed, and the confirmation **names what goes** ("This removes 3:12 from
  the take and can't be undone"). "Cannot be undone" means little without the number.
- A span covering the whole take is a no-op and the commit is disabled on it, rather than
  rewriting every byte through an encoder to arrive back where it started.

`TakeTrimmer` never opens the original for writing. It encodes the span to a sibling temp
file, reads the result back off disk, checks it holds real audio of about the right length,
and only then replaces the original in one `replaceItemAt`. Every failure path — unreadable
source, refused encoder, short write, length mismatch — leaves the take byte-for-byte as it
was, and that property is what `TakeTrimmerTests` spends most of its assertions on.

### 3. The note is a field on the take, not a journal entry

`Recording.note` — one additive optional `String`, mirroring `title`.

A `JournalEntry` owned by the recording was the other option, and a timestamped one (notes
pinned to points in the audio) was the ambitious version of it. Both were declined for this
pass. A note here belongs to the audio the way a title does: it is read on the take's own
screen, beside the thing it describes.

**The consequence, stated plainly:** a take's note does **not** appear in the Journal feed,
and Journal search does not match its words. `RecordingTests` pins that, so the absence
reads as a decision rather than a bug when someone searches for a note's words and finds
nothing.

Clearing a note is allowed, which is where it parts from `rename(to:)`. A blank name is a
mistake — a name is how you tell two takes apart — but a note you no longer want is a note
you should be able to delete.

### 4. `AVAudioFile`, not `AVAssetExportSession`

The deployment target is iOS 17. `AVAssetExportSession.export(to:as:)` is 18-only and
`exportAsynchronously` is deprecated in 18, so the export route costs an availability fork
and a deprecation warning in a build that must stay warning-free — for no benefit.

`AVAudioFile` is synchronous, is already the idiom in `TakeRecorder` and `WaveformExtractor`
(whose chunked read the trimmer mirrors, so a long take never pulls the whole file into
memory), and reading the encode settings off the **source** keeps the writer's
`processingFormat` identical to the reader's — no converter, and a take recorded under
different settings still trims correctly instead of being resampled into something the rest
of the app doesn't expect.

Passthrough export's one advantage — avoiding a second AAC generation — is negligible on a
mono practice take.

### 5. The scrubber is new; everything under it is reused

`WaveformView` and `Minimap` are built around a `Song` and take its loops, markers, beat
grid and zoom viewport, none of which a take has. So `TakeScrubber` is new — but the layer
underneath is not: `WaveformGesture` for point→fraction and the handle maths, `ABSpan` for
the ordered, width-clamped two-handle span, `WaveformAmplitude`/`WaveformBars` for the bar
treatment, `WaveformExtractor` for the envelope. A take's strip reads as the same instrument
as the song waveform without inheriting its screen.

The envelope is **extracted on open, not stored**. A take is short and the reduction is
cheap; storing it would mean a persisted array with a format version to keep in step, for a
screen nobody stands on for long.

**ADR 0153 is load-bearing here.** The position is a per-tick value, so only
`PlayheadTakeScrubber` — a leaf that draws the playhead and its timecodes — reads it.
Everything expensive arrives as a parameter from the screen's body, which runs only on real
change. Getting this wrong would reintroduce a 120 Hz body invalidation on a screen that
also draws a `Canvas` and carries a menu, two sheets and a confirmation.

## Consequences

- **Storage is answerable at last.** 0069's *storage grows with use* now has a user-facing
  reply, and the size hint on the detail screen makes the cost legible before the trim.
- **A take can be shortened past recovery.** The temp-then-verify-then-replace path and the
  confirmation are the whole defence, and both shipped with the trim rather than after it.
- **`StableRef` is now `Hashable`** — `navigationDestination(item:)` requires it where
  `.sheet(item:)` needed only `Identifiable`. Identity still goes through the `uid`, which
  is the whole point of the type.
- **`TakeRecorder.settings` is `nonisolated` and computed**, so the off-main-actor trimmer
  can read it. A stored `static let` on a `@MainActor` class would inherit that isolation
  and, being a non-`Sendable` dictionary, would not survive strict concurrency as a
  `nonisolated` stored property either.
- **The seeded take now carries real audio.** It never did — `JournalTakeRow` renders
  entirely from the model, so the seed wrote no bytes. A take that opens its own screen
  reads the envelope off disk, and a fileless take renders there as a flat track over a
  zero-length timeline: a state worth handling, and the wrong one to photograph.
- **The manual gains two figures** (`journal/take-detail`, `journal/take-trim`) and the
  shoot gains the tests that drive them.

## Alternatives considered

**Non-destructive in/out points.** Cheaper, reversible, and about a third of the code. It
loses on the one axis that motivated trimming at all: the file keeps costing what it cost.
Recorded here because it remains the obvious fallback if the destructive path ever proves
too sharp in practice — the UI would not have to change, only what commit does.

**A timestamped note pinned to a point in the take.** The interesting version, and the one
that would have paid the scrubber back twice. Declined for this pass as materially more
work — multiple notes per take, marks on the strip, a note list, a new `JournalEntry` owner
kind — and left as the natural next step if whole-take notes prove too coarse.

**Whole-take note as a `JournalEntry`.** Would have put take notes on the Journal feed and
its search rail for free. Declined because it makes a take's note a sibling of the take
rather than a property of it, and because the owner kind, the caption snapshot and the
delete rule are all real work for a field.

**Committing the trim asynchronously in the background.** Rejected: the file is being
replaced under a player and a waveform, and a trim that lands after you have navigated away
is a trim you cannot be told failed.

## Related

- `docs/manual/journal-and-progress.md` § Takes — the user-facing account.
- `PocketUITests/ManualShotsUITests.swift` — `testTakeDetail`, `testTakeTrim`.
