# ADR 0271 — Done belongs to the block, not the top bar

- **Status:** Accepted. Built on `pocket-386-done-in-block-bar`.
- **Date:** 2026-10-22
- **Amends:** ADR 0104 — **S2.6** moved the routine ear block's Done from a full-width bottom pill to a
  quiet nav-bar button. It moves back to the bottom, still quiet: a bordered button at the end of a
  bar, not a pill. S2.6's finding, that a big call to action on landing reads like an error, stands
  and is why the button stays small.
- **Amends:** ADR 0141 — **L3**'s readout now sits in a bar with a background, on the leading edge,
  with Done on the trailing one, and is set larger and semibold (D7). Its register stands: `m:ss left`,
  secondary colour, no urgency, no colour change at zero.
- **Amends:** ADR 0266 — **D1**, *"a Done in the toolbar"*. A song block's Done sits under the
  play-along speed instead. D1's reason for keeping it out of the bottom (the transport owns it) and
  D2 (only once the play-along has started) both stand.
- **Relates to:** 0135 B3b (the improvise block's Done, which moves with the ear block's) · 0136 F4
  (the freeform block's Done, whose prominent pill is toned down here) · 0223 (the keyboard's
  checkmark, which Done steps aside for) · 0071 (the routine chrome: ✕, the progress strip).
- **Schema:** none.

## Context

Two problems, both seen on the device in a routine.

**Done read as "done with the routine".** On the song, ear training and improvise blocks, Done sat at
the top right. That is where iOS puts the button that closes a whole modal, and here it shared the top
band with ✕, which leaves the routine, and the progress strip, which moves around it. Everything else
in that band acts on the routine, so Done read as acting on the routine too. It meant "done with this
block".

**The time left drew over the screen.** The `m:ss left` readout on a ramp-less block (0141 L3) was a
bottom inset with no background. On the ear and improvise blocks, which are scrolling Forms, it was
drawn on top of whatever scrolled under it. On the device it sat over **Save to Journal**.

## Decision

- **D1 — The top band is the routine; the block ends below it.** A block's Done never goes in the top
  band. A screen's own tools can stay up there (the freeform block's **⋯** menu, an exercise's
  settings): a menu is not mistaken for an ending the way a top-right Done is.
- **D2 — Ear training, improvise and freeform blocks: one pinned bar along the bottom.** Time left on
  the leading edge, **Done** (or **Finish** on the last block) on the trailing edge, over a material
  background with a hairline on top, so what scrolls under it stays legible. The bar belongs to
  `RampLessBlockChrome`, which already owned the bottom inset and the `onFinish` that Done calls.
  - With no planned length, the bar holds Done alone, still in its corner. Done is in the same place
    on every ramp-less block whether or not there is a clock beside it.
  - Done latches the block's clock, so the planned length can't advance the session a second time
    behind it.
- **D3 — A quiet, bordered Done on all three.** 0104 S2.6 moved the ear block's Done off the bottom
  because a full-width pill read like an error on landing. That was about the pill, not the edge. A
  bordered button at the end of a bar is the smallest thing on the screen that can still be found. The
  freeform block's prominent pill goes too: it was the one ramp-less block with a loud Done, and its
  rating screen still follows the tap, so nothing about finishing it changes.
- **D4 — Song blocks: Done under the play-along speed.** Not the bottom bar: the transport owns it
  (0266 D1's reason, kept). Done still appears only once the play-along has started (0266 D2), and its
  space is held before then, so pressing **Play along** doesn't move the speed control.
- **D5 — Done steps aside while the keyboard is up; the time left does not.** The bar rides on top of
  the keyboard, which would put Done directly under the keyboard's dismiss checkmark (0223), one
  mistap from ending the block mid-note. The readout stays, because typing a note is when the player
  most needs to see that the block is about to move on.
- **D6 — One label rule.** Done or Finish is worked out in one place,
  `RoutineRunContext.finishTitle`, and unit-tested. It used to be four copies of the same comparison.
- **D7 — The time left is set larger and bolder.** Callout semibold, not caption regular: on the
  device, beside a bordered Done, the caption read as too light (Tomisin). Still the secondary colour,
  so it is easier to read without becoming urgent.

## Alternatives rejected

- **Time left and Done in the block's identity card.** Tomisin's first idea. On the ear and improvise
  blocks the card is the top of a scrolling Form, so both scroll away, and the time left must stay in
  view because it warns that the block will advance on its own.
- **Time left in the centre of the progress strip,** where *Rep 2 of 3* rides. It would read as time
  left in the *routine*: the same mix-up of scope this ADR exists to fix.
- **Hiding the whole bar while typing,** as first planned. It would hide the time left at the moment
  it matters most (D5).

## Consequences

- The ear, improvise and freeform screens' Done is now in the same place and the same style. The song
  block's Done is in a different place for a stated reason (D4).
- **Not decided here:** a block that reaches its planned length while a note is half typed still
  advances, and the draft in `JournalNoteComposer` is view state, so it is lost. That was already true.
  D5 keeps the warning on screen; whether the block should wait for the keyboard is a separate
  question.
- `docs/manual/routines.md` says where a block's Done is. The routine player figures are owed a
  reshoot, held until the next shoot.
