# Metronome, Journal, Practice log and the Toolkit

Everything on this page is free, permanently. Nothing here is behind Red Moon Pro.

## Metronome

Reached from the `Metronome` card on Home, and it takes the whole screen. Procedure is in
[the metronome](../metronome.md).

<!-- shot: reference/metronome | role: screen
     | alt: The metronome screen with the beat dots, the BPM readout, the tempo slider between two TAP buttons, the automator panel and Start
     | state: Metronome open, stopped -->

**Top bar.** A back chevron on the left. The title in the middle. On the right, the ✏️ that writes a
journal note, then the meter control, which shows the time signature and a note glyph when a
subdivision is on.

**The beat dots** run across the top, one per beat in the bar. Accented beats are larger, and the
dots dim in step with a withdrawn bar rather than carrying on.

**The tempo readout** is the BPM number with its Italian marking under it. The caption changes to
`Downbeats only` or `Click withdrawn` while the click is thinning out.

**The controls** — `Decrease tempo` and `Increase tempo` flank the readout; below them the `Tempo`
slider sits between two `Tap to set tempo` buttons, one under each thumb.

**`AUTOMATOR`** — `Off`, `By Bars` or `By Time`. Armed, it shows `Increase by`, `Every`, `Up to`, a
`No limit` switch, the ramp staircase, and `Start ramp`. Its header carries the bookmark that saves
the current tempo into Practice as a drill.

**The transport** is pinned at the bottom: `Start`, becoming `Pause` and then `Resume`, with
`Stop and reset` appearing beside it once anything is running.

### The metronome settings sheet

Opened from the meter control, and titled `Metronome`.

<!-- shot: reference/metronome-settings | role: screen
     | alt: The top of the metronome settings sheet, showing the seven Time signature presets and the first Subdivision options; Click withdrawal follows below the fold
     | state: Metronome open, meter control tapped, scrolled to the top -->

- **`Time signature`** — seven presets, each captioned with the music it belongs to.
- **`Subdivision`** — `None`, `Eighths`, `Triplets`, `Sixteenths`, footnoted *Extra clicks between
  the beats, quieter than the beat itself.*
- **`Click withdrawal`** — `Off`, `Gentle`, `Standard`, `Deep`, each with a line saying what it does
  across the eight-bar cycle.

Edits apply live. There is no commit step.

## Journal

Reached from `Journal` on Home.

<!-- shot: reference/journal | role: screen
     | alt: The Journal timeline with the All / Notes / Takes filter and day sections mixing notes and takes
     | state: seeded library, Journal, notes and a take across two days -->

**Top bar.** `Journal options` — the ⋯ — then the ✏️, `Write a quick journal note`. Underneath, a
search field prompting `Search by song, exercise, template or date`.

**`Journal options`** holds a `Sort` picker of `Newest first` / `Oldest first`.

**`Practice log`** sits above the feed, between the scope control and the first day
heading. It is hidden while a search is running.

**The scope control** — `All`, `Notes`, `Takes`.

**The feed** groups by day under `Today`, `Yesterday` and then dated headers.

- **A note** shows its kind chip, the time, the text, an owner caption, and the snapshot it kept.
- **A take** shows a play control, its name, its length and the time, plus its owner caption.
- **The owner caption** is a link where the thing still exists and has a screen to open; plain text
  otherwise.

**Deleting is hold-only**, on every row. A take's hold menu leads with `Name this take`, or
`Rename` once it has one; renaming is also a right swipe.

Empty, the wording follows the scope you are in — `Nothing here yet`, `No notes yet` or
`No takes yet` — and a search with no hits says `No matches`.

### `Quick note`

<!-- shot: reference/quick-note | role: screen
     | alt: The Quick note sheet with the What just happened? field, the kind chips and the line stating where the note saves
     | state: an exercise run screen, quick note tapped -->

One field prompting `What just happened?`, the kind chips, and a line naming where the note lands.
`Cancel` discards; `Save` is unavailable until you have typed something. The sheet touches no
transport.

Which chips appear depends on where you opened it — a note with no unit behind it is offered four
rather than seven. The full table is in [the journal](../journal-and-practice-log.md#the-kinds).

## `Practice log`

Reached from the `Practice log` row on the `Journal`.

<!-- shot: reference/progress | role: screen
     | alt: The Practice log screen with This week's bar chart and This month's shaded grid in full, and All-time beginning at the foot
     | state: seeded library, Practice log, several weeks of history -->

- **`This week`** — minutes and days, over a bar per day.
- **The month section** — its header names the month it is showing (*This month · August*), because
  a calendar grid with no month on it is ambiguous once you have scrolled past the top. Minutes,
  days, new tempos when there are any, the longest day, and a grid shaded relative to that month's
  busiest day, with a `Less` → `More` key.
- **`All-time`** — time played and sessions with the date you started, the hours wall, and
  **`What you've built`**: counts of `Exercises`, `Loops`, `Mastered` and `Notes`.

With no finished runs it says `Nothing here yet` and describes what will fill it.

Nothing on this screen is a grade, and there is no target anywhere on it.

## Toolkit

Reached from `Toolkit` on Home. Four sections, each carrying a count or a state.

<!-- shot: reference/toolkit | role: screen
     | alt: The Toolkit hub listing My chords, Tuner, Glossary and Help & FAQs
     | state: Toolkit open -->

| Section | Subtitle | Trailing |
|---|---|---|
| `My chords` | `Your saved voicings` | How many, or `None yet` |
| `Tuner` | `Tune by ear or mic` | `Free` |
| `Glossary` | `Chord, scale & theory terms` | The term count |
| `Help & FAQs` | `How Red Moon works` | The answer count |

### `Tuner`

<!-- shot: reference/tuner | role: screen
     | alt: The tuner listening, with the note disc, the cents gauge, the string circles and the reference pitch caption
     | state: Toolkit ▸ Tuner, microphone allowed -->

It needs the microphone; refused, it says `Microphone access is off` and offers `Open Settings`.

The note disc names what it heard and colours itself in or out of tune, over a needle gauge flanked
by `♭ Flat` and `Sharp ♯`. The status line above reads `Listening…`, then `Too flat, tune up` or
`Too sharp, tune down`, then `You're in tune!`.

In guided mode a row of string circles sits underneath, captioned `Tap a string to hear it`; the one
nearest what you are playing is the target. Chromatic mode replaces the row with a single **Hear**
button. The bottom caption names the reference pitch and the tuning.

`Tune settings` in the toolbar opens `Instrument`, `Mode`, `Tuning`, `Reference pitch` and
`Success chime`.

### `My chords`

A grid of saved voicings, newest first, with **+** (`Build a chord`) in the toolbar. Tap one for its
detail — a large diagram, **Hear**, `Rename` and `Delete`. Empty, it reads `No saved chords yet`.

### `Glossary`

Terms grouped into `Chords`, `Scales & modes`, `Intervals & pitch`, `Technique` and `General`,
filtered live by a field prompting `Search terms`. This is where every musical word is defined.

### `Help & FAQs`

Questions grouped by area, each expanding its answer in place. `Search help` matches inside the
answers as well as the questions, and force-opens every match while you are searching.

The same screen is reachable from [Settings ▸ Help & About](settings.md#help--about), which also
carries `Contact Support`.
