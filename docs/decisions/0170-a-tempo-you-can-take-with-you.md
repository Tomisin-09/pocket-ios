# ADR 0170 — a tempo you can take with you

- **Status:** Accepted
- **Date:** 2026-08-19 (`pocket-274-bpm-callout-gateway`)
- **Relates to:** ADR 0024 (tap-tempo / the BPM sheet — the route this hold held until now),
  ADR 0124 (the transport redesign that moved tempo entry onto the metronome control),
  ADR 0163 (settings where you are using them — and its standing objection to the *next* hold),
  ADR 0111 (exercise ↔ song links), ADR 0046 / `ExerciseCreation` (one insert path),
  ADR 0116 (a drill opens on the instrument you play), ADR 0051 (a song carries a meter),
  ADR 0090 (present by stable identity), ADR 0103 / `MeterPickerSheet` (a sheet, not a menu),
  ADR 0045 (a command tempo is a measured achievement)

## Context

The song player knows a number the rest of the app would like to have: **the tempo you are
actually practising at.** It is on screen, in the speed bar's BPM callout, updated live as the
speed slider moves — and until now it was a label. You could read 50 BPM off a slowed-down solo
and then had to go to the metronome and dial 50 in by hand, or open Practice, create a drill, and
type it again. The two halves of the app that both think in BPM had no edge between them.

`docs/positioning.md` §6 says the thing we own is the *intersection* of the audio half and the
session half, and §7 says the shipped surfaces mostly **restate** that rather than making it true.
A bridge is the version that makes it true. This is one of six candidates in the inventory, and
the second-cheapest.

### The gesture was already there and doing something else

`WaveformSpeedBar.bpmReadout` has carried a single `.onLongPressGesture` since ADR 0024, opening
the tempo editor. It is a bare `VStack` + `contentShape`, never a `Button` — so it already
complies with the house rule about a `Button` plus a hold firing both (`docs/swiftdata-gotchas.md`)
and was mechanically safe to repoint.

But the tempo editor has **two** handles: the BPM readout and the metronome control beside it.
That redundancy is deliberate and documented — *"whichever one you happen to be looking at when the
number turns out to be wrong is the one that works"* (`docs/manual/gestures.md`). Spending it is
the real cost of this change, and it is what the ADR has to justify.

## Decision

**Holding the BPM callout carries that tempo out of the song.** A sheet offers two destinations:
the metronome, which opens already set to it, and a new exercise, which opens seeded with it. The
metronome control keeps the tempo editor, alone.

### D1 — the two handles specialise; they do not both grow

The metronome control is the one that keeps the editor, not the callout, and the direction matters.
The metronome control is **visible, and it badges itself**: on a song with no tempo it wears a
`plus` and takes a plain tap, because ADR 0124 insisted the fresh-import state must not depend on
discovering a hold. It is the affordance the tempo editor already had. The callout has no badge and
no tap — it is a number you read.

So the split falls out of what each control already is: the one that can *announce* itself keeps
the job you need when something is wrong, and the one that displays a value hands that value on.
"Correct this tempo" and "take this tempo" are different verbs, and after this each has one handle
instead of both having two.

### D2 — the answer to ADR 0163's standing objection

ADR 0163 closed with: *"Holding something on the waveform screen now does something in five places.
That is close to the ceiling for a gesture with no affordance; the next hold proposed here should
be argued against a visible control instead."*

This is that next proposal, and the answer is that **it spends no hold.** The app's long-press count
is unchanged at nine — `check-manual.py`'s `long-press-sites` tripwire counts `onLongPressGesture`
occurrences literally and does not move. Nothing on the waveform screen becomes hold-only that was
not hold-only yesterday.

The honest counter-argument, which 0163 would make, is that *repurposing* a hold can be worse than
adding one: a player who learned that this gesture opens the tempo editor now gets something else,
with no announcement. Three things answer it, and the first is the strongest:

1. **The thing they were reaching for is still one control away, and that control is the visible
   one.** A repurposed hold is only a trap when it strands you. Hold the callout expecting the
   editor and you get a sheet naming two destinations, from which the editor is a dismiss and a hold
   on the badge beside it. Compare a hold that *silently does nothing else*.
2. **The in-app cheatsheet gains a row.** The *Loop controls* popover is the screen's own
   discovery surface and it already carried "Set the tempo"; it now also carries "Carry the tempo".
   That row is behind the `loop-controls-rows` tripwire, so the manual could not drift from it.
3. **A visible affordance was available and was still not taken.** The callout's *tap* slot is
   free, and putting the gateway there instead was the alternative 0163's wording invites. It was
   rejected: see A1.

### D3 — it carries the number on screen, not the song's tempo

The callout shows the **effective** tempo, `song.bpm × speed` — a 200 BPM song at 0.25× reads 50.
Both numbers are defensible and this is a decision, not an accident of which property was nearest:

**It carries 50.** The gesture's whole premise is that you are holding a number you can see, and a
handle that hands over a *different* number than the one under your finger is a surprise the sheet
would have to spend a sentence apologising for. It is also the more useful number: 50 is the tempo
you are practising at, which is what you want the click set to and what you want a drill to start
from. The song's own tempo is a fact about a record; the effective tempo is a fact about you.

The sheet says so rather than leaving it implied — its footer reads *"The tempo you're hearing —
the song's tempo at the speed you've set."*

**The one place this needs care** is ADR 0045: a command tempo is a *measured achievement*, and 50
lifted off a slowed playback is a real measurement of a real thing you were really doing. It is a
starting point on the create form's stepper, shown before anything is created, and the player
confirms or changes it. It is never written to an existing drill — see A2.

### D4 — a sheet, not a menu

Stated repeatedly and not re-litigated here: `MeterPickerSheet`, `ExerciseRunView`, ADR 0103, and
ADR 0163's rejected alternatives. A menu picks between like-for-like **values**; these are
heterogeneous **destinations** with different consequences — one starts a click, the other creates a
model. Each row needs a line of explanation, and the explanation is the half a menu drops first.

### D5 — one presentation, not three

The waveform screen declared eight presentations before this; it now declares **nine**. The chooser
is the ninth, and the two destinations are *not* the tenth and eleventh: the destination replaces
the chooser sheet's content in place, and the sheet's detent grows with it.

Two reasons. Mechanically, both destination views bring their own `NavigationStack`, so pushing
either would nest one. Structurally, ADR 0163's constraint is that `WaveformPracticeView.body` must
not read the playhead, because every presentation declared on it re-evaluates when it does — the
cheapest way to respect a constraint about presentation count is not to add three.

The ending this gives is also the right one: each destination's own dismiss closes the whole sheet.
You chose where the tempo was going; you are not coming back to a chooser.

### D6 — the drill arrives linked to the song

`NewExerciseSheet` gains `initialSongs`, pre-ticking the configure step's link picker (ADR 0111).
The song is the one fact this route knows and the create form cannot infer, and a bridge that
carries the tempo but forgets where it came from is half a bridge. Both existing hosts pass nothing
and are unchanged.

The template picker **runs** — this route does not fix the template the way the automator's
"Save as exercise" seam fixes `.basic`. A metronome breakdown is always a plain tempo drill; a
song's tempo could seed a chord progression, a strumming pattern or a freeform block just as
readily.

Creation goes through `NewExercisePlan.finalise(in:)`, not `Exercise.commandAnchored` — this is the
third host of that plan and `ExerciseCreation` says *"put new creation behaviour here and nowhere
else"*, having already lost a song link once to a second insert path.

### D7 — the meter travels too

A drill made from a waltz opens on 3/4. `Song` stores `beatsPerBar`/`noteValue` (ADR 0051) and
`TimeSignature.forStored` recovers the named preset, so the picker reads "3/4 · Waltz" rather than a
bare custom signature. Accents are not stored on a song, so the preset's own pattern stands: what
travels is the meter, not an arrangement.

### D8 — the tempo is snapshotted at the hold

`carryingTempo` holds the number captured when the gesture fired, and the chooser is bound to it by
identity, not to a `Bool`. This is ADR 0160 §5's lesson applied one screen over: a sheet's content
closure re-runs on every body pass, so a tempo read *there* would be whatever the last re-render
saw. Nothing on the screen can move the speed while the chooser is up — which is exactly why the
wrong version of this would never be noticed.

The identity is minted per hold rather than being the BPM, so holding the same tempo twice
re-presents the chooser. (ADR 0090's rule about stable identities, reached from the other side: this
one is stable because it never touches SwiftData.)

### D9 — the metronome is seeded through `setBPM`, before the first body pass

`MetronomeView` gains `initialBPM`, seeded in its `init` rather than in `onAppear`: the readout, the
marking and the slider all read `engine.bpm` while the body runs, so a later write would show 90 for
a frame and then jump.

It goes through `setBPM` rather than a seeding initialiser on the engine, and that is load-bearing
rather than incidental. A carried tempo is the **first number to reach the metronome from outside
its own controls**, and the song player's range is not the metronome's: a 300 BPM song at 1.5×
carries 450, a 40 BPM one at 0.25× carries 10, and both are outside 30–300. `setBPM` clamps; a
hand-written seed would have had to remember to. Its two side effects are both `transport`-guarded
and a just-constructed engine is `.stopped`, so seeding starts nothing.

The song is paused first, through the existing `pauseForNestedAudio` seam — the same one ear
training and improvising use. The metronome brings its own engine, and two streams over each other
is the alternative.

## Alternatives considered

**A1 — put the gateway on the callout's free tap slot and leave the hold alone.** This is what
0163's wording most directly invites, and it is the strongest alternative. Rejected for two reasons.
It leaves the tempo editor reachable from a control with no affordance *and* from one with a badge,
which is the redundancy this ADR is spending on purpose — the point is that the handles specialise,
and a tap gateway would leave them un-specialised. And a tap on a live-updating readout is the
gesture most likely to be fired by accident while reaching for the slider beside it: the hold's
half-second is a filter, and a gateway that opens a sheet mid-practice wants that filter.

**A2 — offer "into an *existing* exercise" as a third destination.** There is no seam: a command
tempo is model state, not a launch argument, and writing one from here would silently revalue a
measured achievement (ADR 0045). ADR 0121 built the "keep the note speed or re-measure" prompt for
exactly that case, and it belongs to a decision about *editing a drill*, not about carrying a
number. `Song.linkedExercises` is the natural source list if this is ever wanted.

**A3 — carry the song's own BPM instead.** See D3. It contradicts the number under the finger.

**A4 — a `fullScreenCover` for the metronome.** Its own `NavigationStack` and dismiss mean it needs
no injected toolbar, unlike the loop-trainer precedent, so a cover would have worked. Rejected with
D5: it would have been a tenth presentation on the screen with the tightest presentation budget, and
a cover does not fire `.onDisappear`, so the pause seam would have been load-bearing rather than
belt-and-braces.

## Consequences

- **The tempo editor has one handle, not two.** Six pieces of prose said otherwise and are rewritten:
  `docs/manual/gestures.md` (the hold table and the "two handles" paragraph),
  `docs/manual/reference/song-player.md` (the speed bar list and the tempo-editor section),
  `docs/manual/looping.md` (twice), and the in-app cheatsheet row.
- **The cheatsheet grows to nine rows**, moving the `loop-controls-rows` tripwire from 8 to 9. The
  `long-press-sites` tripwire is unchanged at 9 — no hold was added.
- **`docs/manual/metronome.md` gains a fifth way its number can be set** which is not a control on
  that screen: arriving already on it.
- **A new shot, `gestures/carry-tempo`**, is declared and undriven — Phase 5 (ADR 0165) was already
  paused for this work, and `gestures/speed-bar` would have needed re-shooting anyway.
- **No UI test covers any of it.** `PocketUITests` cannot reach the waveform screen from a cold
  launch (no song ships on a fresh install, ADR 0112) — ADR 0163 recorded the same gap for the hold
  it added. What *is* covered by `CarryTempoTests` is the part that can be silently wrong: which
  number leaves the song, that the meter travels, that identity is minted per hold, and that a
  carried tempo outside 30–300 is clamped rather than stored raw. The gesture itself is a **device
  check**.
- **`ConfigureExerciseForm.pickedSongs` is now seeded rather than always empty.** Defaulted, so both
  existing hosts are unchanged, but it is a shared form and the parameter is now part of its contract.
- **The song player can now create an `Exercise`.** It could not before. `finalise` reports
  `exerciseCreated` (ADR 0120), so this route is counted like the other two — which is correct, and
  worth knowing before reading the numbers.
