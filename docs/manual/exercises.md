# Exercises

An exercise is a drill you run against a click rather than against a song. No audio file, no
waveform — a name, a tempo, and something to play. Where a loop is a piece of music you are trying
to own, an exercise is a piece of technique you are trying to own, and the app treats the two as
different things all the way down.

Exercises live in **Practice ▸ Exercises**, reached from **Practice** on Home.

A fresh install arrives with six of them — **Spider Walk**, **Chromatic Warm-up**, **Alternate
Picking**, **A Minor Pentatonic**, **Pop Changes** and **Legato** — so there is something to run
before you have built anything. They are ordinary drills: rename them, retune them, duplicate them,
delete them.

## The library

<!-- shot: exercises/library | role: screen
     | alt: The Exercises library with drills grouped into collapsible template sections, each row showing its name and command tempo
     | state: seeded library, Practice ▸ Exercises, several templates present -->

Drills are grouped by **template** — the kind of drill they are — and each section collapses with a
tap on its header. What you collapse stays collapsed next time; a template you first use tomorrow
arrives open.

Each row carries the drill's name, the climb it is set up for — **Command → Reach**, in BPM, with
its rhythm — and a star when you have favourited it. Tap one to open its run screen.

- **Search** narrows by name.
- The **⋯** control in the toolbar holds **Favourites only**, **Sort by** and **Order**.
- **+** starts a new drill.

If your library holds drills for more than one instrument, a row of chips appears across the top —
**All**, then one per instrument you have. It is not there until it has something to do, and it goes
away again if it stops having something to do.

Hold any row for **Details**, **Duplicate**, **Favourite** and **Delete**. Duplicate is the quickest
way to make a variant of something you have already tuned. Delete goes behind an undo toast — the
drill is only really gone once the toast has passed.

## Running a drill

A run has two states, and the screen is different in each.

### Setting up

Stopped, the screen is the run you are about to do. If the drill carries a shape — a strum lane, a
fretboard, a chord progression — it is drawn at the top. Under that sit the tempo settings, the
staircase, and a **Journal** and **Takes** bar for what you have already written and recorded
against this drill.

<!-- shot: exercises/run-setup | role: screen
     | alt: An exercise run screen before starting, showing the collapsed Practice Settings summary, the staircase, the Journal and Takes bar and Start training
     | state: seeded library, Exercises, "Alternate Picking" opened, stopped -->

**Practice Settings** is collapsed to a one-line summary of the climb, and opens onto the numbers:

- **Working** — the warm-up floor. Where the climb begins.
- **Command** — the fastest you own it. This is the anchor everything else derives from, and it is
  defined in [the app's own words](terms.md).
- **Reach** — where the climb is heading. Worked out from your command tempo unless you type your
  own, in which case a **Reset to auto** appears to hand it back.
- **Back off** — whether to ease the tempo down after the summit rather than finishing at the edge.
  On by default, with its own floor you can pin the same way.
- **Steps** — how many rungs the warm-up, the reach and the back-off each get, and how long the
  drill holds at command before pushing on.

<!-- shot: exercises/practice-settings | role: panel
     | alt: The Practice Settings panel expanded, showing Working, Command, Reach, the Back off toggle and the nested Steps controls
     | state: seeded library, an exercise run screen, Practice Settings expanded -->

The **staircase** draws what those numbers add up to — the **warm-up** climb, the wide **command**
plateau with its BPM over it, the **reach**, and the **back off** — so you can see the shape of the
run before you play a note of it.

<!-- shot: exercises/staircase | role: band
     | alt: The training staircase with its warm-up steps, the wide command plateau labelled 90 BPM, the reach step and the back-off step
     | state: seeded library, an exercise run screen, staircase visible -->

The toolbar shows the drill's meter — **4/4** unless you have changed it — and tapping it sets the
accents and the length of the count-in.

Edits here are held until you commit them. **Start training** commits and plays; a **Save changes**
button appears when the setup differs from what is stored, if you want to keep the tuning without
running it now. Leaving without either discards the edits.

### Running

**Start training** counts you in, then the screen becomes the live BPM, a caption saying where you
are in the staircase, and the drill's own surface animating along with the click.

<!-- shot: exercises/run-live | role: screen
     | alt: An exercise running, showing the live BPM, the phase caption and the animated fretboard beneath it
     | state: seeded library, an exercise run screen, running past the count-in -->

The transport gives you **Pause** / **Resume** and a **stop** that ends the run and clears the ramp.
The screen stays awake while you play, unless you have turned that off in Settings.

Two things are reachable at any point, including mid-run: the **quick note** button in the toolbar,
for a thought you want to keep before it goes, and the **ⓘ**, which opens the drill's reference
sheet — its template, description, linked songs, meter and rhythm.

You can also arm a **recording** before you start, which captures your playing through the mic as a
take. That is covered with the rest of the journal.

### Finishing

A run that reaches the end of its staircase on its own lands on a completion screen: **Nice work**,
then an optional mastery rating, an optional note, and the offer to move your command tempo up to
the reach you just played.

<!-- shot: exercises/run-complete | role: screen
     | alt: The completion screen after a finished run, with a mastery rating, a note field and the command tempo revision
     | state: seeded library, an exercise run finished naturally -->

A run you stop by hand does not land there and does not log. The practice log records runs that
finished, because a run cut short has no honest length to claim.

**See Help & FAQs: "Does Red Moon score my playing?"**

## Making your own

**+** in the Exercises toolbar opens the two-step create sheet.

### Step one — the kind of drill

<!-- shot: exercises/template-picker | role: screen
     | alt: The New exercise template picker with the Guitar / Bass control at the top and the list of templates beneath it
     | state: New exercise sheet, template picker, guitar selected -->

First **Guitar or bass**, which sets the neck for the scale, arpeggio and fretboard drills; the rest
ignore it. Then the template itself. This is the one choice you cannot change afterwards — it fixes
how the drill is built, how it runs, and which section it lives in — so the sheet says so plainly.

Templates carrying their own editor are badged **Editor**. Bass is offered a shorter list: a lane of
down and up strum arrows describes something bassists do not do, so Strumming and Chords & Strum are
not offered there. Chords stays — bass chords are real.

| Template | What it is for |
|---|---|
| **Basic** | A plain tempo drill on the click. |
| **Warm-up** | Loosen up before the real work. |
| **Strumming** | Down / up / rest arrow lane over the click. |
| **Picking** | Alternate-picking accuracy and speed. |
| **Scales** | Run scales in time — push the tempo clean. |
| **Chords** | Change chords cleanly on the beat. |
| **Chords & Strum** | Strum a groove while the chords change under it. |
| **Arpeggios** | Run chord tones across the neck, in position. |
| **Legato** | Hammer-ons and pull-offs, even and smooth. |
| **Your own practice** | Write your own — anything Red Moon doesn't cover. |

Those one-liners are the app's, taken from the picker itself.

### Step two — the details

The second step is titled for what you picked — **New warm-up**, **New scales**, and so on.

<!-- shot: exercises/configure | role: screen
     | alt: The New warm-up configure step showing the Name field and the fretboard run editor with its Generate and Draw your own control
     | state: New exercise sheet, Warm-up template chosen, top of the configure step -->

- **Name** — required, and **Create** stays unavailable until you give it one. The field suggests
  something appropriate to the template.
- **The shape** — if your template has an editor, it opens here, seeded so there is always something
  to run. Scales, Arpeggios and the warm-up family offer **Generate** or **Draw your own**: generate
  and you set a finger pattern, where on the neck it starts, how far across it travels and whether
  it moves; draw and you place the notes yourself. **Hear** plays it back to you either way.
- **Your command tempo** — the fastest you can play it cleanly right now. Everything else in the
  staircase derives from it, which is why it is the number the form asks for.
- **Time signature** — sets the run's accents and count-in length. Defaults to 4/4.
- **Songs** — link the songs this drill is for. The link shows on the song too.

**Create** saves it and drops you straight onto its run screen, so making a drill and playing it are
one move.

### Changing it later

The shape is editable after the fact: open the drill, and **Edit shape** sits in the header of its
preview card. The name, description and song links live on the **ⓘ** detail sheet. Only the template
is fixed.

Changing how many notes per beat a drill plays asks you what should happen to its command tempo,
because the two mean nothing apart.

## Your own practice

The last template is the one for practice the app does not model — sight-reading, transcribing,
singing while you play, something a teacher set. Instead of a shape and a tempo it takes your own
written instructions, and it runs as a timer with those instructions on screen.

<!-- shot: exercises/freeform-run | role: screen
     | alt: A "Your own practice" block running, showing the player's own written instructions and the elapsed time
     | state: seeded library, a freeform exercise, running -->

It has no tempo and no meter on purpose: most of what belongs in one has no BPM at all, and a
setting the run screen never reads is a question with no honest answer.

There is a tick box for **I can do this without my instrument**. That is what lets the block turn up
in an away-from-your-instrument session — see [Today's session](sessions.md). The app cannot tell
from what you wrote, so it asks.

Nothing reads your instructions but you.

## Next

- [Put exercises in an order and play them](routines.md)
- [Let the app plan a session around a goal](sessions.md)
- [The app's own words](terms.md)
