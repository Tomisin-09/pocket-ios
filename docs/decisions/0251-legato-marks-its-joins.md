# ADR 0251 — A Legato drill marks its hammer-ons and pull-offs

- **Status:** Accepted — decided with Tomisin, 2026-10-04. Built on `pocket-361-legato-joins`.
- **Date:** 2026-10-04
- **Amends:** ADR 0065 — build 2's *"Warm-up/Picking/Legato/Fingerstyle declare a run and seed a real
  chromatic warm-up at creation"*: Legato now opens on a hammer-on / pull-off figure of its own, and
  plays every drill with its joins worked out. The shared run editor, the generate-or-draw split and
  the other three templates are unchanged.
- **Relates to:** 0227 D5 (the join rule, reused as it stands) · 0083 and the 2026-07-28 walk-trail
  rule (a technique is drawn on the step being played) · 0107 (the draw-your-own escape hatch, which
  gains the joins too) · 0121 (a payload states its own rate) · 0070 (nothing here grades)
- **Schema:** none. The joins are derived at render time and never stored.

## Context

The Legato template had no legato in it. A new Legato drill opened on the chromatic warm-up, in the
same run editor as Warm-up, Picking and Fingerstyle, so it looked identical to a new Warm-up.
`FretTechnique` has carried `.hammerOn` and `.pullOff` since 0065 build 2, but no code ever set them,
and the board drew only slides. The seeded *Legato* drill had no board at all and ran on the bare
click. Its technique lived only in its notes: *"Pick only the first note; hammer and pull the rest."*

Tomisin, 2026-10-04: *"comparing this template with the name the note feature (fret & string) made
me realise that we could adopt some of its features into the template."*

Name the notes already decides what a hammer-on is (0227 D5): the note before has to be on the same
string at a different fret, and the direction decides which join it is, up for *h* and down for *p*.
It also already draws one: a curve under the string with the letter in a ring.

## Decision

| # | Decision |
|---|---|
| **D1** | **The joins are worked out, not authored.** The first note on each string is picked. Every later note on that string is a hammer-on going up or a pull-off coming down. The check is `NeckJoin.direction(into:of:)`, the same rule Name the notes uses, so a drill and a named piece can't disagree about what a hammer-on is. A rest breaks the chain, a repeated fret is picked, and the first note of the cycle is picked: there is no join across the wrap, so every loop starts with a pick. A note that already has a technique keeps it, so a climbing run's slide seam (0083) is still a slide. Pure: `FretboardDrill.withLegatoJoins()`. |
| **D2** | **Keyed off the template and never stored.** `ExerciseTemplate.articulating(_:)` is the one place that decides which templates articulate, and today that is Legato alone. `Exercise.fretboardDrill`, the single read behind the run screen and both previews, applies it. A Legato drill made before this, generated or drawn, gains its joins with no migration, and the same content under Warm-up or Picking stays picked. |
| **D3** | **Drawn as the walk trail, as a slide is.** `LegatoCue` draws a curve under the string from the fret the finger leaves to the fret it lands on, with *h* or *p* in a ring. The letters come from `JoinDirection.symbol(for: .legato)`, so the board and the tab spell a join the same way. It appears only on the step being played, the 2026-07-28 rule that took slides off the static board. VoiceOver already read a note's technique and now reads *Hammer-on* and *Pull-off*. Both editor previews, generated and drawn, play the run with its joins. |
| **D4** | **A Legato drill opens on its own figure.** `FretboardRun.hammerOnPullOff` is fingers 1-2-4-2 from the 5th fret, low E to high e and back, in **quarters**. Each string reads 5h6h8p6: pick, hammer, hammer, pull. On the way back the pattern is restated rather than retraced, and there are four notes a string, so each string is one bar of 4/4 in both directions (44 notes, 11 bars). A retraced return drops the peak and the home note, which knocks the strings off the bar line. It was built in sixteenths; on the device that left the cues going by too fast to follow (see Consequences), so it starts a note a beat, and the **Rhythm** row is there once the shape is in the hands. `ExerciseTemplate.starterRun` gives the create form and *Edit shape* the same starter. |
| **D5** | **The seeded *Legato* drill ships that figure.** Its notes now say *"Pick only the first note on each string; hammer and pull the rest."* Its rate comes from the payload (0121), so it now runs in quarters at the same command of 85: a quarter of the note speed the old spec stated (`noteRate: 4`). New installs only, as 0247 D3 reasoned: no one has the app yet. An older seeded *Legato* with no board opens *Edit shape* on the figure, and gets it when saved. |

### Rejected

- **Name the notes' *Into it* control in the drill editor**, choosing Picked, Hammer-on, Pull-off or
  Slide note by note. That control is for saying what you heard. A drill you design should work its
  joins out from the frets, as the run editor works out everything else (*"the run builds itself"*).
  It would also need a stored join per note.
- **A stored legato flag on `FretboardRun`.** Drills made before it would stay picked, and the
  template already says it. Two sources of truth for one fact.
- **Every join drawn at rest.** A six-string figure would carry twenty-odd curves, which is the
  clutter 2026-07-28 took the slide arrows off the board to avoid.
- **A picking control on every run template** (*pick every note* or *the first on each string*).
  Nobody asked for it, and Picking and Warm-up are picked by definition.
- **A tab line under the run, and the heard-note glow (0234).** Considered and left out of this
  change. Not decided against.

## Consequences

- A Legato drill no longer looks like a Warm-up: the figure differs at rest, and the joins show as it
  walks.
- **Checked on the device, 2026-10-04.** In sixteenths at 85 BPM each step lasted about 176 ms, too fast
  for the curve to read. Tomisin: *"its best it started as quarters by default, so that animation
  doesn't seem too confusing"*. The figure now starts in quarters (D4), about 700 ms a step at 85. A
  quiet slur at rest, the other fallback, was not needed.
- **The template is owed a review** (Tomisin, the same day: *"I feel like this template will need a review at some point but for now,
  this is good enough"*). Parked in
  `docs/backlog.md`. This ADR is a floor, not the template's final shape.
- The curated runs moved to `FretboardRun+Curated.swift` (the 400-line cap), unchanged.
- No manual figure shows a Legato board, so nothing goes on the reshoot list.
