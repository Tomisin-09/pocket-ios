# Practice

Reached from the `Practice` card on Home. Everything in this region is part of Red Moon Pro.

## The hub

<!-- shot: reference/practice-hub | role: screen
     | alt: The Practice hub with the Today section, the Routines row and the Your units section holding Exercises and Loops
     | state: seeded library, Practice hub -->

Five rows in two sections, each carrying a count.

| Row | Subtitle | Opens |
|---|---|---|
| `Today` | `A session shaped by your goals` | The planner |
| `Routines` | `Hand-built practice sessions` | The routines library |
| `Long-term goals` | `Standing outcomes, ranked` | The long-term goals list |
| `Exercises` | `Click-only command drills` | The exercises library |
| `Loops` | `Measured song loops` | The loops library |

`Today`, `Routines` and `Long-term goals` sit together; `Exercises` and `Loops` group under
`Your units`. Routines are sessions; exercises and loops are the units a session is built from.

## `Today` — the planner

<!-- shot: reference/planner | role: screen
     | alt: The Today's session screen with the length presets, the away-from-your-instrument toggle, the Goals section and Generate today's session
     | state: seeded library, Practice ▸ Today, no goals yet -->

- **`How long do you have?`** — `Quick`, `Focused` and `Full`, each captioned with roughly how long
  the whole sitting runs.
- **`Away from your instrument`** — a toggle. Its **ⓘ** explains it in the app's own words:
  *Listening work built from your own loops, for a commute or a quiet room. Nothing to hold,
  nothing to plug in.* It resets each time.
- **`Build from`** — `Both`, `This session`, `Long-term`. **Only present once you have a long-term
  goal**; before that there is nothing to choose between. Its **ⓘ** carries the rule: *Goals for
  this session are dealt first; long-term goals follow in your ranking.* A footer appears **only**
  when the selection has nothing to contribute — *Nothing selected has anything to contribute yet,
  so Generate will build a quick, due-based session from your exercises.*
- **`This session`** — what steers this sitting in particular, with
  `Add a goal for this session`, and, once there is at least one,
  `Clear this session's goals`. **Hidden entirely when `Build from` is `Long-term`.** With none, and no long-term goals either, it says *No goals yet —
  Generate builds a quick, due-based session from your exercises. Add a goal to steer what you
  practise.* With a long-term goal standing it says *Nothing extra for today — Generate will follow
  your long-term goals. Add one here to steer this session in particular.*
- **`Long-term goals`** — a read-only copy of the ranked list, present only when you have one and
  **hidden entirely when `Build from` is `This session`**. It carries no controls except
  `Edit long-term goals`, which opens the list in Practice, and no footer — the `Build from` ⓘ
  already states the order.
- **`Generate today's session`** at the bottom.

The goal editor, the review screen and what happens when nothing resolves are all in
[Today's session](../sessions.md).

## `Long-term goals`

<!-- shot: reference/long-term-goals | role: screen
     | alt: The Long-term goals screen with a numbered list of goals, each showing its skill count, and Add a long-term goal below
     | state: seeded library, Practice ▸ Long-term goals, two goals ranked -->

A numbered list under `Ranked`, each row carrying the goal's name and its skill count — plus its
target song when it has one. Below them, `Add a long-term goal`.

The toolbar carries one control, `Reorder goals`, which is off until there are two to reorder.

With none, the section reads *Nothing here yet. A long-term goal is something you're working toward
with no deadline attached — the higher it sits, the harder it pulls when you build a session.* The
footer below the list says *Order them however you like. The top of the list pulls hardest when a
session is built.*

There is a ceiling of ten. On reaching it the `Add a long-term goal` row goes away and the footer
says *That's 10 — the most a ranking stays meaningful at. Mark one met or delete one to add
another.*

Goals you have marked met collect under `Met`, footed *Kept here, and no longer shaping new
sessions.* Procedure is in [Today's session](../sessions.md).

## `Routines`

<!-- shot: reference/routines-library | role: screen
     | alt: The Routines library with one routine row showing its block and rest counts and a play button
     | state: seeded library, Practice ▸ Routines -->

A list of routines, each row carrying its name and what it is made of — `4 blocks · 2 rests` — with a
**play** control on the row itself. The toolbar carries `List options` then `New routine`, in that
order.

Once a routine has been run, a second line underneath carries how many times it has been practised
and when it last was.

<!-- not-in-source: "4 blocks · 2 rests" — counted per routine at render time, so the row's summary
     is never one literal. The words either side of the counts are. -->

`List options` holds sorting, and `Generate a quick session`, which skips the goals entirely.

Tapping a row opens the routine, where its blocks are listed and can be reordered, added to and
removed. Below the blocks, a saved routine states its `Estimated length`, its `Last practised` date
and how many times it has been practised. Below that it carries a `Where you learned it` section — read-only until you
tap `Edit`, which is what puts `Add a link` on it, the same gate the blocks are behind. See
[where you learned it](../references.md). A generated session that has not been saved yet does not
show the section at all. Procedure is in [routines](../routines.md).

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
- **`Exercise details`** — the ⓘ — opens the drill's reference sheet, which carries its description,
  progress, linked songs, a `Where you learned it` section with an `Add a link` button, the feel and
  the template chip.
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
