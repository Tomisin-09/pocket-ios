# ADR 0300 — Hear up to the note

- **Status:** Accepted, built on `pocket-430-hear-up-to-the-note` for 1.4.1, and checked on device on
  2026-11-15 (Consequences).
- **Date:** 2026-11-15
- **Amends:** ADR 0227 — **D2**: *Hear a phrase* gets a seventh choice, *Up to the note*. It plays every
  note from the pass's first tap and ends on the one being named, with no cap on length. The rest of D2
  stands: the phrase ends on the note, the default is three, the setting is remembered, and the play
  button stops it.
- **Relates to:** 0225 (Count the notes, the taps a phrase is cut from) · 0234 D3 (moving on is
  silent; a chip tap is what plays) · 0070 (never grades).
- **Schema:** none. One saved setting, `namingPhraseNotes`, gains a meaning for 0 (D4).

## Context

*Hear a phrase* (0227 D2) was added after the second device check. The whole loop didn't help place one
note in a long pass, and one note alone gave no context. So a tap plays a chosen number of notes,
from *Just the note* to eight, ending on the note being named.

That leaves a gap between eight notes and the whole loop. The loop gives all the context but doesn't
stop on the note, so the note being named isn't the last thing heard. A phrase does stop on the note,
but it reaches back at most eight. On note 30 of a long run, the line that led to it starts well before
that.

Tomisin proposed the fix while reviewing a mockup of a direction step for Name the notes, on
2026-11-15: *"in the note options, we should provide an 'up to the note' option which plays all the
previous notes before it."*

Players already practise this way. Playing from the top and adding one note each time is called
forward chaining, and this is the listening version of it. The menu's heading already says *Ending on
the note you're naming*, so the option fits under it unchanged.

## Decision

**D1 — A seventh choice, last in the menu: *Up to the note*.** On a chord loop it reads *Up to the
chord*. A tap plays from the pass's first tap through the one tapped. It goes through the same slice as
any phrase, so it starts just before that first tap (`AudioSlice.preroll`). That means a loop that opens
on silence doesn't make the player wait. On note 1 it is the note alone, the same as *Just the note*.

**D2 — No cap on length.** On note 60 of 65, a tap replays nearly the whole pass, and for longer at a
slower tempo. A cap would quietly turn the option into "up to twenty notes", which isn't what it says.
It also matches 0227 D2's rule that a phrase plays whatever lies between its notes. There are already
two ways out: the play button stops a phrase, and tapping another chip cuts it off. The strip's ring
follows the phrase across the strip, which also shows how far it has to go. When the phrase ends, the
strip scrolls back to the note.

**D3 — The words follow the counts' pattern.**
- The header reads *Hear up to the note*.
- The subtitle reads "Tap a note to hear **it with every note before it**, or play the whole loop.",
  beside the existing "it with the 2 notes before it".
- VoiceOver reads the value as "Every note up to the one you're naming".

`NamingStrip.hearTitle`, `choiceTitle` and `tapPlays` produce all three strings and are unit-tested.

**D4 — Stored as 0, under `NamingStrip.upToTheNote`.** No choice used 0 before.
- An earlier build clamps 0 to one (`max(1, notes)`), so going back a version plays *Just the note*.
  Its header then reads *Hear 0 notes*, with nothing ticked.
- Settings stay on the device and are never synced between devices. Only installing an older build
  over a newer one reaches this case, and only TestFlight allows that.
- The alternative was a second setting, a switch beside the count. It would have read cleanly in an
  older build, but it was rejected: two settings for one choice can disagree.
- A test pins the value at 0, so the backward reading can't change by accident.

## Alternatives not taken

- **A cap (twenty notes, or a bar count).** See D2.
- **Starting from the loop's start rather than the first tap.** That plays the silence before a late
  first note, every time.
- **Wording that names the start: *From note 1*, *From the start*.** The menu's heading already says
  where the phrase ends. Saying where it starts would make this item the only one worded from the other
  end.

## Consequences

- `docs/manual/reference/practice.md` names *Up to the note* where it lists the choices.
- `ByEarNamingTests` covers the phrase range, the menu's position, the stored value and the three
  strings. The existing test that read 0 as the note alone now uses −1, which still clamps to one.
- **Device check, 2026-11-15.** Tomisin picked *Up to the note* on a phone build of this branch and
  was happy with it. The check covered how long a replay feels late in a long pass and at a slower
  tempo, whether the play button and a chip tap stop it, and whether note 1 matches *Just the note*.
  Before that, a driven run on the simulator showed the header fitting beside the tempo control at
  402 pt and at 375 pt, the narrowest width.
