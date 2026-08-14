# Practice

Reached from the `Practice` card on Home. Everything in this region is part of Red Moon Pro.

## The hub

<!-- shot: reference/practice-hub | role: screen
     | alt: The Practice hub with the Today section, the Routines row and the Your units section holding Exercises and Loops
     | state: seeded library, Practice hub -->

Four rows in two sections, each carrying a count.

| Row | Subtitle | Opens |
|---|---|---|
| `Today` | `A session shaped by your goals` | The planner |
| `Routines` | `Hand-built practice sessions` | The routines library |
| `Exercises` | `Click-only command drills` | The exercises library |
| `Loops` | `Measured song loops` | The loops library |

`Today` sits on its own; the other three group under `Your units`. Routines are sessions; exercises
and loops are the units a session is built from.

## `Today` — the planner

<!-- shot: reference/planner | role: screen
     | alt: The Today's session screen with the length presets, the away-from-your-instrument toggle, the Goals section and Generate today's session
     | state: seeded library, Practice ▸ Today, no goals yet -->

- **`How long do you have?`** — `Quick`, `Focused` and `Full`, each captioned with roughly how long
  the whole sitting runs.
- **`Away from your instrument`** — the app's own words: *Listening work built from your own loops,
  for a commute or a quiet room. Nothing to hold, nothing to plug in.* It resets each time.
- **`Goals`** — what steers the session, with `Add a goal`. With none it says *No goals yet —
  Generate builds a quick, due-based session from your exercises. Add a goal to steer what you
  practise.*
- **`Generate today's session`** at the bottom.

The goal editor, the review screen and what happens when nothing resolves are all in
[Today's session](../sessions.md).

## `Routines`

<!-- shot: reference/routines-library | role: screen
     | alt: The Routines library with one routine row showing its unit and rest counts and a play button
     | state: seeded library, Practice ▸ Routines -->

A list of routines, each row carrying its name and what it is made of — `4 units · 2 rests` — with a
**play** control on the row itself. The toolbar carries `List options` then `New routine`, in that
order.

<!-- not-in-source: "4 units · 2 rests" — counted per routine at render time, so the row's summary
     is never one literal. The words either side of the counts are. -->

`List options` holds sorting, and `Generate a quick session`, which skips the goals entirely.

Tapping a row opens the routine, where its blocks are listed and can be reordered, added to and
removed. Procedure is in [routines](../routines.md).

## `Exercises`

<!-- shot: reference/exercises-library | role: screen
     | alt: The Exercises library with drills grouped into collapsible template sections, each row showing its name and command tempos
     | state: seeded library, Practice ▸ Exercises, the seeded six present -->

Drills grouped into collapsible sections by **template** — the kind of drill they are — with a count
on each header. A row shows the drill's name and its tempo line: `Command 90 → 95 BPM · 16ths`, which
is the command tempo, the reach above it, and the rhythm.

<!-- not-in-source: "Command 90 → 95 BPM · 16ths" — assembled from the drill's own numbers, and the
     rhythm clause drops out entirely on a drill that states no note rate. -->

The toolbar carries `List options` then `New exercise`. The search field prompts by name.

**More sections can exist than the create sheet offers.** Grouping covers every template the app has
ever had, so a drill made under one that has since been withdrawn still lists under its own heading,
still opens and still runs. Withdrawing a template from the picker never reaches backwards into a
library. The ten you can create today are listed in [exercises](../exercises.md).

### The run screen

Opened by tapping a drill.

- **The shape** — a fretboard, a chord progression, a strum lane — is drawn at the top, if the drill
  carries one. Many do not.
- **`Practice Settings`** is a disclosure, collapsed by default, summarising itself when closed.
  Inside sit the three tempos — `Working`, `Command` and `Reach` — and, under them, `Back off`, whose
  caption reads *finish below command, on control not the edge*. A `Reset to auto` button appears
  once you have overridden the reach.
- **The staircase** shows the tempo plan as steps.
- **A `Journal` and `Takes` bar** holds what you have already written and recorded against this
  drill.
- **`Start training`** commits and runs. Beside it, the **record** control arms a take.
- **`Exercise details`** — the ⓘ — opens the drill's reference sheet.
- **The ✏️** writes a [journal note](tools-and-journal.md#journal) without touching the run.

While running, the screen shows the live BPM, a count-in if you have one turned on (`Counting in`),
and pause / resume. `Stop and reset` ends it. A run that finishes on its own lands on a completion
screen; one you stop by hand does not log.

## `Loops`

<!-- shot: reference/loops-library | role: screen
     | alt: The Loops library, empty, explaining that measured loops appear here once set on a song
     | state: fresh library with no measured loops, Practice ▸ Loops -->

Every loop you have marked, across all your songs, in one list — the practice-side view of what the
[song player](song-player.md) creates. The search field prompts `Loops and songs`.

There is **no delete here**: a loop belongs to its song, and is removed from the song player.

Empty, it explains that loops appear once you have set one on a song.

## The other run modes

A loop can be run three ways, all launched from its edit sheet in the song player:

- **The ordinary loop run** — play it, slow it, ramp it.
- **`Train your ear`** — hear it and answer, rather than play along.
- **`Improvise`** — the loop as a bed to solo over.

Each has its own run screen, and each writes into the journal with its own tag.
