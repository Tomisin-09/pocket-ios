# Feasibility — tab → fretboard animation (research, 2026-07-05)

V2 vision: "turn guitar tab into a fretboard animation showing the notes on the
fretboard — at first to help us provide guides for presets, then maybe for
users' own tab." The right build order inverts the flashy part: the *renderer*
is the durable asset; tab *parsing* is a bolt-on input into it, added input
format by input format.

## Phase R — the fretboard renderer (build first, no parsing at all)

An internal, typed notation model (e.g. `FretEvent {string, fret, beat,
duration, finger?, technique?}` over a `TimeSignature` + BPM) rendered as an
animated fretboard (SwiftUI `Canvas` + `TimelineView`), driven by the same
clock as the metronome so guides play in time with the click.

- **Feeds the preset library immediately:** spider drills, scale runs, chord
  changes from the exercise inventory get first-party animated guides — content
  we author, consistent with the content-strategy guardrail (methods, never
  scraped material).
- **Shares DNA with the strumming-pattern animation** (V2 vision's other ask):
  a strum pattern is the same "events on a musical clock" model with a
  different lane layout. Build one timing/animation substrate, two renderers.
- **Pure and testable:** event→beat math and fret geometry are exactly the
  kind of logic AGENTS.md requires unit tests for; SwiftUI stays a thin skin.
- **Verdict: feasible now**, and it is the prerequisite for everything below.

## Phase T1 — ASCII tab import (tractable, after R proves out)

Monospace ASCII tab is a constrained grammar (6 string lines, fret numbers by
column, `h/p/b/s/x` ornaments). A parser to the Phase-R model is a bounded,
pure-Swift problem with fuzzable tests. Two honest limits to design around:

- **Rhythm is not in ASCII tab.** Column spacing implies order, not duration.
  V1 of import assumes even spacing per column against a user-set BPM, with a
  simple nudge/edit UI. Anything smarter is a music-theory research project.
- **Input is messy** (mixed tunings, 7-string, lyrics interleaved). Scope V1
  to 6-string standard/drop tunings; reject clearly rather than guess.

## Phase T2 — structured formats (later, licensing-gated)

Guitar Pro (.gp/.gpx) and MusicXML carry real rhythm and would import cleanly —
but the mature parsers (e.g. AlphaTab, TuxGuitar-derived) are LGPL/GPL-family;
static-linking them into an App Store binary is a licensing decision, not a
technical one. Options at that point: dual-licensed libraries, a clean-room
subset reader, or MusicXML-only (XML, parseable with Foundation directly).
Decide only if T1 demonstrates demand.

## Phase T3 — photo/PDF tab OCR (explicitly not planned)

OCR for tab (or standard notation) is a computer-vision product of its own.
Recorded here only so nobody mistakes it for a phase of this feature.

## Sequencing note

R unblocks preset guides *and* the strumming feature; T1 is the first
user-facing "your own tab" payoff; T2/T3 are optional escalations. If V2 time
is short, shipping R alone is already the "guides for presets" goal met.
