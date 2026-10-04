# ADR 0247 — A strumming drill from the first run

- **Status:** Accepted — decided with Tomisin, 2026-10-03. Built on `pocket-359-a-strumming-drill`.
- **Date:** 2026-10-03
- **Amends:** ADR 0144 — D8's *"six exercises"* becomes seven: the first-run seed gains *Strumming —
  Down-Up Eighths*. One routine and one song still seed, `presetSlug` is still provenance, and the
  rest of D8 stands.
- **Amends:** ADR 0246 — D4's list of templates left off the goals card loses *Tighten your timing*,
  which is now offered. D4's rule is unchanged, and it is what admits the template: a goal is offered
  only if it gives Today's session something on a new install.
- **Relates to:** 0112 (the union that chose the six) · 0237 (the set kept as onboarding once the app
  was free) · 0065 (the strumming template and its pattern lane) · 0070 (the drill grades nothing)
- **Schema:** none. The drill is an ordinary `Exercise`, built from a spec already in the catalog.
- **Amended by:** ADR 0248 (2026-10-03) — the seventh drill seeds with the other six only for a
  guitar, bass or skipped answer to the intake's new first card.

## Context

ADR 0246 put a goals card in the first run and held it to one rule: a goal it offers must give
Today's session something on a new install. *Tighten your timing* failed that rule. Its skills are
timing, syncopation and strumming, and none of the six first-run drills is a strumming or rhythm
drill, so the goal would have built nothing on day one.

Tomisin, 2026-10-03: *"let's add a strumming exercise"*.

The catalog already holds five strumming drills and one strum-and-chords drill
(`PracticePresets.allSpecs`). They were seeded on early installs and retired from seeding by 0112,
which cut a new install to six.

## Decision

| # | Decision |
|---|---|
| **D1** | **A new install seeds seven drills.** The seventh is *Strumming — Down-Up Eighths* (`strumming-down-up-eighths`), taken from the catalog as it is: 84 BPM, a stroke on every eighth. Morning Routine is unchanged and still uses four of them. |
| **D2** | **Down-up eighths, not another pattern.** Most strumming patterns are this one with some strokes left silent, so it comes first. The drill is about keeping the strumming hand steady against the click, which is what *Tighten your timing* promises, and a beginner can play it on the first day. |
| **D3** | **New installs only.** The drill seeds under the existing first-run key, like the other six, so an install that has already seeded does not gain it. No one has the app yet (Tomisin, 2026-10-03, as in 0246 D7). A key of its own would re-seed nothing else, but it is a seeding path that serves no one today. |
| **D4** | ***Tighten your timing* goes on the goals card.** It now derives the strumming drill through `rhythm.strumming`. *Play a specific song* and *Train your ear* stay off: a new install still has no song and no ear-training drill. |

### Rejected

- **The folk pattern, *D DU UDU*.** It is the classic first pattern, but its silent strokes are a
  second lesson on top of the first.
- **_Groove — Pop Changes_.** As a strum-and-chords drill it would also reach `rhythm.timing`
  directly. On the first day it asks a beginner to change chords and hold a pattern at once, and it
  repeats the *Pop Changes* drill the set already has.
- **The syncopated, reggae and boom-chick patterns.** All of them are later lessons.
- **A new pattern written for this.** The catalog's drill is in-house already and has shipped.
- **Seeding it onto existing installs.** See D3.

## Consequences

- On a new install the exercise library gains a **Strumming** section. Sections sort by name, so it
  falls between *Scales* and *Warm-up*, and nothing above it moves.
- The goals card offers eight templates. *Tighten your timing* comes second for *Play songs I love*
  and third for *Get properly good*, the two dreams that already preferred it. It is third when the
  dream is skipped and sixth for *Write my own music*.
- The drill reaches the goal through its strumming skill. `rhythm.timing` itself is reached only by
  strum-and-chords and rhythm drills, which a new install does not have. The goal still builds from
  the drill, because the planner derives a goal from any of its skills.
- `IntakeGoalOfferTests` now holds the strumming drill in place. Taking it out of the first-run set
  fails the test with *"timing derives nothing from the first-run library"*.
- Figures that show a new install's exercise library (`exercises/library`) or the goals card are
  stale, and go on the reshoot list.
