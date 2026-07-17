# 0096 — A dedicated chords / theory / resources hub (direction)

- **Status:** Proposed (2026-07-17) — **IA/design pass complete (2026-07-17); awaiting ratification of
  D1–D5 to promote to Accepted.** No build scheduled until then.
- **Date:** 2026-07-17
- **IA / design pass:** [`docs/plans/chords-theory-hub-ia.md`](../plans/chords-theory-hub-ia.md) — resolves
  the deferred questions below (attach point, screen inventory, the build/hear/explore/keep flows, empty
  states, phasing) and lists the decisions (D1–D5) the player ratifies to move this ADR to Accepted.
- **Sets direction for:** pulling the objective-reference features out of the exercise editors into a
  destination of their own.
- **Builds on / gathers:** ADR 0093 (chord-naming engine — the shared theory core), ADR 0094 (theory &
  ear-training space + the no-grading reconciliation), ADR 0095 (`SavedChord` — the "My chords" library
  this hub would host), ADR 0085/0091 (the scale/mode catalog + CAGED boxes), ADR 0092 (AI coach — the
  paid/deferred layer that would sit on top).

## Context

Three strands are converging on the same idea from different ADRs:

1. **Saved custom chords (ADR 0095)** are surfaced *in-context* (inside the chord editor's Add menu) as
   the pragmatic first step — but a growing personal chord library really wants a screen of its own.
2. **The theory & ear-training space (ADR 0094)** was ratified as a direction (objective identity +
   self-judged practice; never an app-scored quiz) but given no home.
3. **The chord identifier (ADR 0093)** and the scale/mode catalog are objective *reference* tools that
   currently only exist bolted onto authoring surfaces.

The player, reviewing ADR 0095, named the unifying insight directly: a **dedicated destination** that
carries "My Chords" *and* music theory / ear training *and* other guitar resources — e.g. a
terms/vocabulary glossary — could be worth far more than any one of those bolted onto an exercise editor.
That's a genuine product direction, not just a place to move a list. This ADR captures it so the pieces
(ADRs 0093–0095) are built pointing at it, and parks it for its own design pass.

## Decision (direction, not a build)

- **H1 — There should be a top-level "reference" destination, separate from authoring.** A hub whose job
  is *explore / reference / keep* — distinct from the exercise editors, whose job is *author practice
  content*. This is the home ADR 0094's space was missing and the screen ADR 0095's library graduates to.

- **H2 — Candidate contents, each already has a substrate:**
  - **My Chords** — the `SavedChord` library (ADR 0095), promoted from the in-context menu to a full
    manage/build/organise screen; "build a chord" opens the existing placer + identifier.
  - **Chord identifier / voicer** — name a shape, and (per ADR 0094 T2a) *hear* it.
  - **Theory & ear-training** — the reference/exploration + self-judged call-and-response tools of ADR
    0094 (interval player, scale/mode explorer over the ADR 0085 catalog), on the safe side of the
    no-grading line (**no app-scored quiz** — ADR 0094 T2c).
  - **Glossary / vocabulary** — a plain reference sheet of terms (a "what does *sus4* / *tritone* /
    *CAGED* mean" list). Static in-house content (ADR 0065 T8), the clearest-safe possible feature.

- **H3 — Everything objective and additive; the no-grading spine holds (ADR 0070 / 0094).** The hub
  informs and lets the player self-direct; it never scores playing, never quizzes right/wrong, no
  streaks/XP. An AI "explain / suggest" layer over any of it is ADR 0092 (opt-in, paid, deferred) sitting
  on top of this deterministic, free floor.

- **H4 — Built on the shared cores, not new bespoke logic.** `Core/Theory` (ADR 0093) + the scale catalog
  + `SavedChord` are the substrate; the hub is mostly presentation over types that already exist or are
  planned. That's the point of building ADRs 0093–0095 first.

## Consequences

- **The in-context steps aren't throwaway.** Saving chords in the editor (ADR 0095) and naming shapes
  (ADR 0093) are the same features this hub would present — the hub reorganises and extends, it doesn't
  replace.
- **A clear parking spot for ADR 0094's space.** The theory/ear-training tools now have a plausible home,
  so scoping the first one later starts from "which hub tab," not "where does this even go."
- **Deferred deliberately.** A hub spanning chords + theory + ear training + glossary is a real
  information-architecture and design job (navigation, empty states, how "build/hear/explore" interrelate)
  — worth its own design pass and ADR revision to *Accepted*, not a rushed bolt-on. Nothing here is
  scheduled; ADRs 0093–0095 ship independently and stand on their own without it.

## Alternatives considered

- **Keep everything in-context forever (no hub).** Rejected as the *end state* — a personal chord library,
  interval trainer, and glossary don't belong inside an exercise editor; they're reference, not authoring.
  In-context is the right *first* step (ADR 0095), not the destination.
- **Build the hub now.** Rejected — premature. Only one of its tenants (`SavedChord`) exists; theory/ear
  tools are still direction (ADR 0094). Design the destination once its contents are real.
- **A settings-buried list instead of a top-level destination.** Rejected as the ambition — reference the
  player reaches for during practice shouldn't hide in Settings; H1 calls for a real destination. (Where
  exactly it attaches — a Practice tab vs. its own — is a design-pass question, not decided here.)
