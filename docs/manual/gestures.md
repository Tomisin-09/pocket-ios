# Every hold, swipe and pinch

Red Moon puts a lot behind a **hold** — press and keep your finger down for about half a second.
That keeps the screens uncluttered while you are playing, at the cost of being invisible until
somebody tells you. This page is that somebody.

Nothing on this page is required to use the app. Every hold either opens something you can also
reach another way, or changes a setting that has a sensible default.

## The cheatsheet the app carries

The song player has its own summary built in. Tap **Loop controls** on the line under the speed bar
and a popover lists the nine things you can do to a loop:

<!-- shot: gestures/loop-controls-popover | role: panel
     | alt: The Loop controls popover open over the waveform, listing nine rows from "Make a loop" to "Follow"
     | state: seeded library, Slow Bend, player idle, Loop controls tapped -->

<!-- loop-controls-rows: 9 -->

| | |
|---|---|
| **Make a loop** | Tap Loop to set the start, play on, tap to set the end |
| **…or draw it** | Hold and drag across the waveform |
| **Fine-tune** | Drag the A / B handles to move the ends |
| **Re-edit later** | Drag a saved loop's edge on the waveform |
| **Move around** | Tap or drag to seek · pinch to zoom · skip with − / + |
| **Change the skip** | Hold either skip button to pick 5s · 10s · 15s · 30s · 1 min |
| **Set the tempo** | Hold the metronome to open tap-tempo or type a BPM |
| **Carry the tempo** | Hold the BPM to take it to the metronome or a new exercise |
| **Follow** | Off: zoom holds the spot under your fingers · On: it tracks the playhead |

That popover covers the waveform. The rest of this page covers everything else.

## Holds that open something

Nine places in the app wire up a hold of their own <!-- long-press-sites: 9 -->, and all but one of
them are in the song player.

| Hold this | And you get |
|---|---|
| The song's title and artist, at the top of the player | The song's details |
| The compact title bar, in landscape | The song's details |
| The **BPM** readout on the speed bar | Somewhere to take that tempo |
| The metronome button on the speed bar | The tempo editor |
| The **Loop controls** line | The song player's settings |
| A row in the **Loops** panel | That loop's edit sheet |
| A row in the **Markers** panel | That marker's edit sheet |
| A panel header — **Loops** or **Markers** | Selection mode, for acting on several at once |
| **Insert rest**, while editing a routine | Rest-placing mode, to drop rests between blocks |

Two of those are worth calling out because they are doors to somewhere you would otherwise go
hunting for.

**The two numbers on the speed bar do different jobs.** The metronome button opens the tempo
editor, which is where you go when the song's tempo is wrong or missing. The **BPM** readout beside
it does the opposite — it hands the tempo *out*. Hold it and you can take that number to the
metronome, which opens already set to it, or into a new exercise, which starts at it and arrives
linked to the song you took it from.

<!-- shot: gestures/carry-tempo | role: panel
     | alt: The Carry this tempo sheet listing "To the metronome" and "Into a new exercise", headed with the tempo being carried
     | state: seeded library, Slow Bend, player idle at full speed, BPM readout held -->

The number it carries is the one on screen. That is the song's tempo **at the speed you have set**,
so a 200 BPM song at 0.25× carries 50 — the tempo you are actually playing at, which is usually the
one you wanted.

<!-- shot: gestures/speed-bar | role: band
     | alt: The speed bar with the speed control, the metronome button and the BPM readout
     | state: seeded library, Slow Bend, player idle -->

**Tapping and holding the Loop controls line do different things.** A tap gives you the cheatsheet
above; a hold opens the player's settings — the same four switches as **Settings ▸ Song player**,
put where you are actually using them.

## Holds that open a menu

Lists behave the way lists do on iOS: hold a row and a menu appears with that row's own actions
first, then **Favourite** and **Delete** where the list offers them. The song library, your
routines, your saved loops and your exercises all work this way.

Not every list offers all of it, because not every item has all of it:

| Hold a row in | And the menu offers |
|---|---|
| The song library | **Details**, **Edit**, **Delete** — songs have no favourite |
| Your exercises | Its own actions, **Favourite**, **Delete** |
| Your routines | Its own actions, **Favourite**, **Delete** |
| Your saved loops | Its own actions and **Favourite** — no delete, because a loop belongs to its song and is removed on the waveform |
| **Where you learned it** links | **Edit link** and **Delete** — a link has no favourite, and this delete is immediate rather than undoable |

<!-- shot: gestures/row-hold-menu | role: panel
     | alt: A song row held down in the library, showing its menu of Details, Edit and Delete
     | state: seeded library, Library screen, row "Binta" held -->

The transport's skip buttons use the same kind of menu for a different job: hold either one and pick
how far it jumps — **5s**, **10s**, **15s**, **30s** or **1 min**. Journal entries and recorded
takes have their own hold menus too.

## Swipes

On any row that offers them:

- **Swipe right** to favourite it — on exercises, routines and saved loops. Songs have no
  favourite, so a song row has nothing on its right swipe.
- **Swipe left** to delete it.

Right is always the affirmative one, so it does the local job wherever a row has a different one. On
a **block inside a routine** it is **Record** — marking that block to capture a take when you play it
— and on a **take** it is naming. See [Recording a block](routines.md#recording-a-block).

Deleting is not final straight away. A toast appears with an **Undo**, and the row only really goes
when the toast does.

<!-- shot: gestures/undo-toast | role: band
     | alt: The undo toast after deleting a row, offering Undo
     | state: seeded library, Library screen, a row swiped left and deleted -->

## On the waveform

The waveform is the one place where dragging means several things depending on where you start.

- **Tap or drag anywhere** on it to move the playhead.
- **Pinch** to zoom in and out. Whether the view stays put or follows the playhead is the **Zoom
  follows playhead** switch in the player's settings.
- **Hold, then drag** across it to draw a loop in one gesture, instead of tapping **Loop** twice.
- **Drag the A or B handle** of the live loop to move either end.
- **Drag the edge of a saved loop** to re-edit it later.

Because a hold-and-drag draws a loop, a plain hold on the waveform does nothing on its own — the
gesture only commits once you move.

## If a hold does not seem to work

Hold for about half a second, and keep still — a hold that drifts turns into a drag, which on the
waveform means you have started drawing a loop instead. On a row, let go as soon as the menu
appears.

**See Help & FAQs: "How do I get help or report a bug?"**
