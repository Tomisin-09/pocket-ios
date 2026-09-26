# ADR 0224 — a take that belongs to no unit

- **Status:** Accepted. Built on `pocket-334-standalone-take`.
- **Date:** 2026-09-26
- **Amends:** ADR 0155 §3 — *"The Journal space writes standalone notes, and only standalone notes"*
  becomes standalone notes **and standalone takes**. §3a's owner-picker prohibition is unchanged and
  now covers takes too; everything else in 0155 stands.
- **Relates to:** ADR 0058 (one owner, set by one choke point) · ADR 0069 and its 2026-08-05
  amendment (the start-less take toggle) · ADR 0100 §1 (the Journal space's read-only stance, first
  narrowed by 0155) · ADR 0126 (`ellipsis.circle` then `+`) · ADR 0143 (`ownerKind` is the
  discriminator; the relationships win) · ADR 0151 (a take whose owner is deleted keeps its caption
  and becomes ownerless) · ADR 0190 D5 (the *Just me* owner filter).
- **Schema:** one additive optional column, `Recording.isStandalone: Bool?`, no declaration default.
  Safe under ADR 0189's criteria; `nil` on every existing take is correct.

## Context

The review before the manual reshoot asked where a take goes that isn't about a drill. A riff you
want to keep before you forget it. How the new strings sound. A first go at a song you haven't
imported. Every recorder in the app sits on a run screen, a freeform block or an ear or improvise
loop, so today that take gets recorded against whatever happens to be open, and it corrupts that
unit in the same way ADR 0155 described for notes. The take is filed under a drill it has nothing to
do with, and the drill's Takes list now holds audio that isn't practice of it.

ADR 0155 solved this for notes: an entry may belong to nothing, it says so with a stored flag, and
the Journal space is where it is written. Takes had the same gap. They also had the same trap,
because ADR 0151 had already given *no owner set* a meaning: a take whose loop or exercise was
deleted.

## Decision

### D1 — A take may belong to nothing, and it declares that rather than implying it

`Recording` gains `isStandalone: Bool?`, and `Recording.OwnerKind` gains `.standalone`. They follow
`JournalEntry.isStandalone` exactly:

```swift
var ownerKind: OwnerKind {
    if loop != nil { return .loop }
    if exercise != nil { return .exercise }
    if song != nil { return .song }
    if isStandalone == true { return .standalone }
    return .none
}
```

**Absence is already taken.** A take with no owner is ADR 0151's orphan, whose caption
(`ownerLabelAtTake`) still names the loop it was recorded on. If a take recorded on purpose against
nothing reused that absence, the two could never be told apart again. There is no backfill for a
distinction that was never recorded. The relationships still win (ADR 0143), so a stray flag on an
owned take cannot move it.

`RecordingOwner.standalone` is the one way to set the flag, through the same `attach(to:)` choke
point as every other owner (ADR 0058). It writes **no caption**, so a standalone take can never carry
a unit's name.

### D2 — The Journal's ＋ becomes a menu with two doors

The pencil that opened *Quick note* becomes a `+` `Menu` labelled **Add to Journal**, with **Write a
note** and **Record a take**. It is still the second trailing item after the ⋯, so ADR 0126's grammar
holds. The alternative, a separate record button, would have put a third bare item on the bar, which
0155's toolbar question was settled to avoid. The glyph changes to `plus` because the menu now holds
more than a pencil. *Write a note* keeps the pencil inside the menu, so it still looks like the
note button on every run screen.

### D3 — Recording is one control, and the take is saved by stopping it

*Record a take* opens a medium-height sheet with one large control: tap to start, tap again to stop
and save. This is `RecordingController.toggleTake`, the start-less grammar freeform blocks already
use. There is no run to arm against. Nothing is playing either, so the category flip that ADR 0069's
arm grammar protects against has no stream to glitch.

- **The Journal's audition player stops first.** Otherwise a take auditioned in the feed would play
  through the speaker into the mic.
- **While a take is rolling, neither a swipe nor Done closes the sheet.** The only way out is the
  control that saves it, so a take is never ended by a gesture that meant something else. Teardown
  the player didn't ask for still saves the take, through the disappear hook, which also cancels a
  start still waiting on the microphone prompt.
- It then says *Take saved · m:ss* and settles back, ready for another take. The take shows in the
  feed behind the sheet.

### D4 — It files under *Just me*, beside the standalone notes

In the owner filter (ADR 0190 D5) a standalone take falls under **Just me**, with the notes written
against nothing. The filter sorts by what an item belongs to, not by whether it is writing or audio.
An orphaned take stays out of every offered kind, as before. It has no caption and no route, so its
row shows a play control, its name, its length and the time, and nothing to follow.

### D5 — The archive carries the flag

`RecordingRecord.isStandalone` is **Optional**, like `JournalEntryRecord.isStandalone`. An archive
written before this decodes it as `nil`, and every take in such an archive had an owner, so an
ownerless one there is an orphan and stays one. Without the field, a restored standalone take would
come back looking like a damaged take.

### D6 — What it does not do

- **No owner picker, and no attaching later.** 0155 §3a applies to takes unchanged: filing audio
  against a unit you are not playing would put the take in that unit's Takes list and make it look
  like practice of the unit.
- **No tag.** Takes carry no `EntryKind`, and this adds none.
- **Free**, like the rest of the Journal (ADR 0144).

## Consequences

- `docs/manual/journal-and-practice-log.md` and `reference/tools-and-journal.md` describe the ＋ menu
  and the record sheet, and *Just me* now covers takes.
- **Stale figures, folded into the single reshoot:** `journal/timeline` and `reference/journal` both
  show the Journal's bar, where the pencil is now a `+`. The glyph `journal/quick-note-button` is
  shot on an exercise run screen, whose pencil is unchanged. `journal/record-take` is a new, unshot
  screen.
- `JournalNewMenuUITests` drives both doors. It does not tap the record control: the first tap
  raises the system microphone prompt. What the take is filed against is covered by
  `RecordingTests`, `JournalOwnerFilterTests` and the two archive suites.
