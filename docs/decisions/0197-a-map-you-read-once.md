# ADR 0197 — a map you read once

- **Status:** Accepted
- **Date:** 2026-09-07 (`pocket-303-home-tile-grid`)
- **Relates to:** **reverses ADR 0102**'s rejection of a tile grid, on the stated grounds that it
  was decided at four cards. Keeps everything else 0102 established — the three titled sections, and
  §1's rule that a destination's accessibility label is the UI-test contract. Spends the height on
  **ADR 0196**'s `This week` strip and **ADR 0193**'s resume card. Bound by **ADR 0144 D2/D4**
  (which tiles lock, and which never do) and **ADR 0165** (the manual quotes the app). Pays the
  figure debt ADR 0196 deferred. Picked up from `docs/directions-2026-09.md` §2 / §6 Tier 3.
- **Schema:** none. No model is read that was not already read.

## Context

Home was six full-width strips, each with a glyph, a title, a one-line subtitle and a chevron. That
shape was right at three of them and defensible at four — ADR 0102 weighed a tile grid against it
**when there were four cards** and chose the strips, because a subtitle earns its height on a screen
that still fits.

Six do not fit. The bottom half of Home became a menu that has not changed since the app shipped and
will not change again this year: the six destinations are fixed, their order is fixed, and a player
learns their positions in about a week. Everything genuinely new — what you last practised, how much
you have done this week, which routines you have been running — was below or competing with it.

ADR 0196 built the content half of `docs/directions-2026-09.md` §2 and deliberately left the layout
half alone, on the argument that proving the content first de-risks the layout. This is the layout
half.

## Decisions

### D1 — The six become tiles, two to a row, inside the sections they already had

A `HomeTile` is a glyph in a washed circle over a centred name, on a washed card. Two fill a row;
the row sits inside the `HomeSection` it already belonged to. **Practice · Metronome**, then
**Song library · Journal**, then **Red Moon Oracle · Toolkit** — the grouping, the order and the
hues are ADR 0102's and ADR 0187 D16's, untouched.

What makes the grid legible is the thing the app already built for another reason: six destinations,
six accent families, no two alike (`docs/design-brief.md` §3.1 — and the Oracle took crimson rather
than Blood Moon precisely so no two home spaces would share a colour in light mode). **A hue plus a
glyph is a map.** You read it once and afterwards you aim at a colour. A sentence is prose, and prose
is re-read every time it is on screen.

It is an `HStack` of two rather than a `LazyVGrid`: six destinations in three named pairs is a
layout, not a collection.

### D2 — The subtitles leave the screen. The accessibility labels do not move.

*"Your exercises & training runs"* and its five siblings are gone from the display. The
**accessibility labels are byte-identical**, subtitle wording and all.

Two reasons, and the second is the real one:

- ADR 0102 §1 made those labels the contract. `RowUndoUITests`, `PracticeRunUITests`,
  `ExerciseInstrumentUITests`, `RoutineLibraryUITests`, `OracleUITests`, `ToolkitUITests` and six
  `PocketShootUITests` classes all reach a destination by its label. A layout change is not a reason
  for a smoke test to go red.
- **A control that has stopped showing its description has not stopped having one.** The subtitle was
  never wrong; it was redundant to a sighted player who had already learned the map, and it is not
  redundant to VoiceOver, which cannot see the hue doing the work. So the sentence moves from the eye
  to the ear rather than being deleted.

That "kept on purpose" is now asserted directly rather than incidentally:
`PocketLaunchUITests.testHomeMapCarriesEverySpokenLabel` checks all six in one test. Before it, a
moved label would have failed in whichever unrelated suite ran first, reporting a missing Practice
run rather than a renamed control.

### D3 — One tile carries a caption, and only while the library is empty

The `Song library` strip's subtitle was count-aware, and on a fresh install — six drills, one
routine, **no song** (ADR 0112) — it read `Add a song to get started`. That was Home's only word
about adding a first song; the green **+** is a glyph in a toolbar and says nothing on its own.

Dropping the subtitles would have taken that sentence with them and silently regressed the one state
that needs it. So `HomeTile` takes an optional caption, exactly one tile passes one, and it goes as
soon as it is followed. **The exception is an instruction, not a description** — that is the line,
and it is what stops the caption becoming a subtitle by another route.

It is `HomeView.librarySubtitle`, the same property the accessibility label interpolates, so the
visible nudge and the spoken one are one string and cannot drift.

### D4 — `Red Moon Oracle`, not `Oracle`

The mockup shortened the sixth tile to *Oracle* to fit the width. It is `Red Moon Oracle` on its own
navigation bar, in `docs/manual/`, and in `OracleUITests` — a map whose tile calls a place something
the place does not call itself is a map with a mistake on it.

It wraps to two lines. Every tile declares `maxHeight: .infinity`, so an `HStack` row takes the
height of its tallest member and the Toolkit rises to meet it rather than leaving a step in the grid.

### D5 — The lock moves to the corner

A strip swapped its **chevron** for a padlock (ADR 0144 D4). A tile has no chevron, so the padlock
rides in the top-trailing corner — where `RecentRoutineCard` already puts one, so this is a borrowed
convention rather than a new one. The tile stays fully visible and reads as *inviting-but-locked*,
never hidden and never broken. Journal and Toolkit never lock (ADR 0144 D2).

### D6 — One file owns the map

`HomeView+Map.swift` holds all six tiles and the three sections. Before this they were in three
files — four in `HomeView.swift`, two in `HomeView+Learn.swift` — for no reason but SwiftLint's
400-line cap, with the consequence that **nothing could see the map whole**. `HomeView+Learn.swift`
is deleted and the two arguments it carried are carried here instead: why the Oracle's only door is
this section (not the Journal, whose promise is that a lapsed subscription takes nothing back; not
the Toolkit, whose proposition is being gate-free), and why `toolkitTile` alone does not route
through `proGated`.

`HomeView.swift` drops from 362 to 278 lines as a side effect, which is the cap doing what it is for
rather than what it had been doing.

### D7 — The manual stopped quoting the subtitles in the same commit

`scripts/check-manual.py` C9 holds every backticked token in `docs/manual/reference/**` to a real
Swift string literal. Deleting six subtitles broke five backticks on `home-and-library.md`
immediately, by name, before the build finished — which is C9 working exactly as ADR 0165 intended.
The page now describes the grid, names the six, and says in prose that the tiles carry no
description and that VoiceOver still reads one.

### D8 — The two owed figures are shot here, and the deferred edit is run

ADR 0196 changed `reference/home` (the strip) and ADR 0195 changed `reference/settings-routines` (a
fifth row) and neither was reshot, on the recorded argument that this work changes the Home figure
again and one ~6-minute run beats two. That debt is paid here.

`ManualRoutineShots.testPlayThrough` also carried an **unrun edit**: ADR 0195 put a `Tune up first?`
question between *Play* and block 1, and the walk was taught to answer `Not now` without ever being
executed. It runs in this shoot, which is the first thing that could have executed it.

### D9 — The Journal's light-mode wash was darkened, because a tile is a smaller field of colour

Found on device, in light mode, and only after the tiles were real: the Journal tile did not read as
a tile at all — it read as background with a glyph on it.

The wash was not newly wrong. Measured against the `#F0E3D8` light background, the six card washes
sit at:

| | ratio vs background |
|---|---|
| plum (Metronome) | 1.72 |
| teal (Practice) | 1.36 |
| terracotta (Song library) | 1.26 |
| indigo (Toolkit) | 1.21 |
| crimson (Red Moon Oracle) | 1.14 |
| **gold (Journal)** | **1.02** |

Gold was last by a distance — a twentieth of the separation the next-weakest hue has. On a
full-width strip that was survivable: the card was 350 pt wide with a chevron on one end and two
lines of text across it, so its *edges* were legible even when its fill was not. **A tile has half
the width, no chevron and one word**, so almost all of what tells you it is a card is the fill. The
same colour that was a faint tint became invisible.

`#F0E7CE` → **`#E2D1A1`**: identical hue (44°) and identical saturation (0.53), lightness 0.875 →
0.76. That puts it at **1.20**, between crimson and indigo — mid-pack, not the loudest. The circle
wash moves by the same 0.042 of lightness (`#EBDFBE` → `#DDC991`) so the glyph disc keeps exactly
the 1.08 separation from its card that it had before.

Three things this deliberately did **not** do:

- **Dark mode is untouched.** `#2A2211` on `#040404` was never the weak one, and changing a token
  that works because its twin does not is how a fix becomes two bugs.
- **The `journal` accent `#9A7521` is untouched.** It is the hue's identity and it also tints the
  Journal's owner-attribution captions elsewhere in the app; the washes are used on this tile and
  nowhere else, so the blast radius of the change is exactly the thing that was wrong.
- **It did not become a border.** Adding a stroke to make a low-contrast fill readable would have
  been a new component convention introduced to avoid fixing a colour.

**The generalisable part:** every one of these washes was chosen against a full-width card, and this
ADR shrank the field of colour by more than half without re-measuring any of them. Gold was the one
that fell off the bottom. Crimson at 1.14 is the next candidate and looked acceptable on device;
that is a judgement made by eye, and it is written down here so the next person knows it was made
rather than not considered.

### D10 — What the height actually bought, measured rather than asserted

`docs/directions-2026-09.md` §2 and the mockup both say the gain is that *"the whole app fits above
the rail."* **It does not, and this ADR should not be read as claiming it does.** Shot on an
iPhone 17 at 402×874 pt, the fold before and after:

| | above the fold |
|---|---|
| before | greeting · CTA · Jump back in · Practice · Metronome · Song library · half of Journal |
| after | greeting · CTA · Jump back in · **This week** · Practice · Metronome · tops of Song library + Journal |

**Learn and the recent-routines rail are still below the fold, exactly as they were.** What changed
is that a whole `This week` strip now fits in front of them. Per destination the map went from one
full-width strip to half a tile row — roughly a quarter less height each — and that saving is very
close to what ADR 0196's strip costs. So the honest statement is: **the tile grid paid for the stat
strip.** It did not make Home fit on one screen, and nothing here should be planned as though it had.

That is still the trade worth making — the height went from a menu that never changes to a readout
that changes daily — but it is a smaller claim than the one the sketch makes, and the difference
matters to whatever is proposed for this screen next. Anything that needs Home to be one screen is
still unbuilt work.


## Consequences

- The map is an index at the bottom of the screen instead of the bulk of it, and what changed since
  yesterday is what a launch shows first. **Home still scrolls** — see D10 for what the height
  actually bought, which is the stat strip and not a one-screen Home.
- **`HomeNavCard` is deleted.** It had no call site outside Home and no reason to survive as a
  component nothing draws.
- Six subtitles are no longer on screen. That is the cost, it is paid once, and the sentences are
  still spoken. The one that was an instruction rather than a description survives visibly (D3).
- **The light-mode gold wash changed** (D9), and it is used on this tile and nowhere else, so
  nothing outside Home moves with it. Dark mode and the `journal` accent are untouched.
- **A tile is a smaller tap target than a strip** — roughly half the width, though taller. Both are
  far above the 44-pt minimum, and centring the content means the whole card is the target.
- ADR 0102 is now reversed in one respect and standing in three: its grouping, its section order and
  its label contract are all still load-bearing here. Reversing the tile-grid call did not reopen
  any of them.
- The iPad question is untouched and gets easier, not harder. `docs/directions-2026-09.md` §2 argues
  Home's option A and the iPad's option B are the same decision from two sides; six named tiles in
  three sections is closer to a sidebar than six strips were.
- **Not covered:** whether the Practice log should be closer than two taps (ADR 0176's placement,
  the last part of §2 still open), the bar ruler (§3 step 1, the next Tier 3 item), and any change to
  what the six destinations *are*.
