# ADR 0246 — The dream comes to something: long-term goals at the first run

- **Status:** Accepted — decided with Tomisin, 2026-10-03. Built on `pocket-358-goals-at-the-first-run`.
- **Date:** 2026-10-03
- **Amends:** ADR 0113 — the first-launch intake gains a card, *What are you working toward?*, between
  the dream and the minutes. It is skipped after *Just unwind*, so that answer still sees four cards.
  The "3–4 question" limit becomes "four, or five when the dream points toward a goal". The rest of
  the intake stands: every card and the whole flow can be skipped, there is no reveal and no paywall,
  and everything can be changed later.
- **Amends:** ADR 0171 — D6's *"ranking, adding, editing and deleting all happen here and only here"*
  gains one exception. The first run can **add** long-term goals. Ranking, editing and deleting still
  happen only in Practice ▸ Long-term goals, and the Practice log echo stays read-only.
- **Amended by:** ADR 0247 (2026-10-03) — D4's list only: *Tighten your timing* is now offered,
  because the first-run set gained a strumming drill. D4's rule stands.
- **Relates to:** 0070 (never grading, and no pressure, which is why *Just unwind* is not asked — D3)
  · 0015 S1 and 0171 D5 (the shared goal templates the card draws from) · 0113 S3 (`dreamLift`, which
  stays — D6) · 0171 D10 (the `Build from` control, which now appears on day one)
- **Schema:** none. The card writes ordinary `LongTermGoal` rows.

## Context

The intake's third question, *What's the dream?*, had one consumer. `PracticeEmphasis` multiplies one
practice mode by `dreamLift` (×1.3) when Today's session ranks candidates. Nothing on screen ever shows
that, so the player answers a question about why they play and the app never mentions it again.

Long-term goals (ADR 0171) are what Today's session actually builds from. A new player only meets them
by finding Practice ▸ Long-term goals. The dream and the goals never touched.

Tomisin, 2026-10-03: *"actually link the dream to the goals i.e. get users to define their long term
goals during onboarding."*

## Decision

| # | Decision |
|---|---|
| **D1** | **A new card, *What are you working toward?*, right after the dream.** It lists long-term goal templates. Picking up to three creates that many `LongTermGoal`s, ranked in the order tapped, each with its template's title and all of its skills. The card can be skipped like any other. **Skip** at the top keeps the picks made so far, as it keeps every other answer. |
| **D2** | **The dream orders the card and never shortens it.** The dream's closest templates come first, and the rest follow in library order. A skipped dream gives library order. |
| **D3** | **Not asked after *Just unwind*.** Giving homework to someone who came to unwind is the pressure 0070 rules out. A player who picks goals, goes back and then chooses *Just unwind* gets none. |
| **D4** | **A template is offered only if it gives Today's session something on a new install.** `IntakeGoalOfferTests` derives each offered template against the first-run library and fails if one comes to nothing. On 2026-10-03 that leaves off *Play a specific song* (a new install has no song), *Tighten your timing* and *Train your ear* (no first-run drill works on their skills). They stay in the goal editor. |
| **D5** | **Three, not ten.** The tier allows ten (0171 D4), but on a first run three ranked goals give a direction, and ten would be homework. Past three, the other rows dim and stop responding. |
| **D6** | **The dream keeps its tilt.** The card follows on from the dream and does not replace it: the dream says why the player plays, and the goals say what they are working on. `dreamLift` is unchanged. |
| **D7** | **No offer to existing players.** No one has the app yet (Tomisin, 2026-10-03), so nobody has finished an intake that lacked this card. |

> **Amended by ADR 0247 (2026-10-03).** D4's list is shorter: a new install now seeds a strumming
> drill, so *Tighten your timing* gives Today's session something and is offered. *Play a specific
> song* and *Train your ear* are still left off.

### Rejected

- **Replacing the dream with the goals card.** *Just unwind* is a real answer with no goal behind it,
  and the dream's tilt would go with it.
- **Putting the goals on the dream's card.** It would mix a single choice with a ranked multiple
  choice on one long card.
- **Offering every template.** The unoffered ones would give Today's session nothing, so the player's
  first answer would do nothing on the first day.
- **Asking for a target song on the card.** A new install has no songs, and importing one is a
  different job from answering a question.
- **Working out the offer from the live library at runtime.** Home seeds the first-run drills in a
  `.task` while the intake's cover is appearing, so a live check would race the seed. A fixed list
  guarded by a test gives the same answer every time.

## Consequences

- A player who answers the card meets Today's session with `Build from` and their ranked goals on the
  first day. Generate follows the goals before they have added anything for that session.
- *Tighten your timing* is not on the card only because the first-run drills include no strumming or
  timing drill. Adding one to the first-run set would qualify it, and the test would confirm that.
- The manual's *The first run* section describes the card. The `getting-started/first-run` figure is
  stale (five dots, not four) and goes on the reshoot list.
- Any later change to the first-run drills or a template's skills is held to D4 by the test.
