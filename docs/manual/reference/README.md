# Reference — what each screen is

The [spine](../README.md) answers *how do I do a thing*. This wing answers *what is this control*.
Five pages, one per region of the app, each walking its screens top to bottom and naming every
control on them.

| Page | Covers |
|---|---|
| [home-and-library](home-and-library.md) | Home, the first run, the Song library and its sheets |
| [song-player](song-player.md) | The waveform screen band by band, its sheets, landscape |
| [practice](practice.md) | The Practice hub, Today's session, Routines, Exercises, Loops |
| [tools-and-journal](tools-and-journal.md) | Metronome, Journal, Practice log, Toolkit |
| [settings](settings.md) | Reaching Settings, and each of its nine destinations |

## How to read a page here

**Every heading is a screen, or a band of one**, in the order you meet it going down the screen.
Where a control opens something, the thing it opens is a heading underneath it.

**Backticks mean the exact words are on screen.** `Set the 1`, `Away from your instrument`,
`Loop control on left` — those are the app's strings, not a description of them, and
`scripts/check-manual.py` proves each one still exists in the build (check C9). If a name here is
not in backticks, it is our word for something the app labels only with a glyph.

A name is quoted as the app *writes* it, not as a particular screen *sets* it. Several headers are
styled in capitals — the automator's `Start` and `Steps`, Home's `Your stuff` — and the capitals are
typography, not part of the name.

**Bold is a control you act on**; italics are a state it can be in. A control that is only reachable
by a hold says so, because nine of them carry no visible hint — the full list is in
[gestures](../gestures.md).

## What this wing does not do

It does not teach procedure — that is the spine's job, and each page links back into it rather than
repeating it. It defines no musical term (**Toolkit ▸ Glossary** owns all of those) and no practice
term (see [the app's own words](../terms.md)). It names no price and states no commitment about your
data; those have owners too.
