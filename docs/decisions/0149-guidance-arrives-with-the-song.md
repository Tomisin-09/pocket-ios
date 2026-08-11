# ADR 0149 — guidance arrives with the song

- **Status:** Proposed — **substantially amended by ADR 0158 before any of it was built.** §2's
  first-import trigger is reversed (guidance now fires at first launch, on a bundled demo song),
  §1's three-step method narrows to three beats on the waveform screen and moves the long-form
  method to the website, §3's checklist goes with it, and §10's "prerequisite" turns out to
  already exist. **§4, §5, §6, §7, §8 and §9 stand unchanged.** Read this ADR alongside 0158.
- **Date:** 2026-08-08 (`pocket-245-guided-creation-onboarding`), amended 2026-08-11
- **Extends:** ADR 0113 (the local artist profile and its intake), ADR 0145 (the compiled help
  catalog), ADR 0148 §7 (a library that starts empty)
- **Constrained by:** ADR 0070 (Pocket never grades playing), ADR 0120 / 0147 (analytics are opt-in)
- **Deliberately does not invoke:** ADR 0092 (the AI charter, still Proposed)

## Context

Onboarding today ends before the app's actual subject begins. A new player meets the intake from ADR
0113 — four skippable questions, no account, no email — lands on a library seeded with six exercises
and one routine, and finds a practice screen built around loops, markers and a waveform, with
nothing to practise on and no indication of how any of it is meant to be used. The FAQ catalog from
ADR 0145 answers questions, but only for someone who already knows what to ask. Empty-state hints
carry the rest.

The creation experience is the part of Pocket that is genuinely unlike anything else the player has
used, and it is the part we currently explain least.

A vision for fixing it has sat in `docs/backlog.md` since V1 under *"the art of creating loops"*: an
opinionated, skippable, three-step path layered over the practice screen, encoding a practice
author's method for turning a song you like into material you can work on. It was captured as intent
with the mechanism explicitly left open. This ADR closes the mechanism and adds what a review of
current onboarding practice (2026-08-08) argued for.

That review's thesis was restraint: guidance should behave like a competent person noticing you are
stuck, not a tour that fires because you are new. Its strongest empirical points were that
walkthroughs requiring a real action beat linear "Next" tours, that short checklists with an honest
pre-checked first item complete far more often, and that guidance triggered by behaviour outperforms
guidance triggered by a schedule. The flow as captured already satisfies the first of those, because
each of its steps *is* a product action. The rest of this ADR is mostly about when the flow appears
and when it shuts up.

**The structural problem it has to solve:** the flow's first step is "listen to the song whole", and
since ADR 0148 §7 the library ships with no song at all. The demo song was dropped for good reasons
and is not coming back. So the guidance cannot run at first launch — at first launch there is
nothing to guide.

## Decision

### 1. Three steps, each a real action

The flow is the one captured in the backlog, unchanged in substance:

1. **Listen whole.** Original tempo, no speed changes. Notice the parts you want to be able to play.
   Write a **first journal entry** — what you want from this song. This uses the owner-scoped
   composer from ADR 0142; the note belongs to the song.
2. **Mark sections.** Replay slower — around 0.85× is suggested — and drop **markers** on the parts
   worth returning to. Markers are auto-named on drop and renameable at any time.
3. **Create loops.** With the song signposted, build loops from those marked positions. Suggested
   starting point: 50% tempo, zoomed in.

No step advances on a button alone. A step is complete when the player has done the thing — a note
exists, a marker exists, a loop exists. This is the difference between a walkthrough and a tour, and
it is the whole reason to build this rather than a coach-mark overlay.

The tempo figures are **suggestions with the musician's discretion attached**, phrased that way in
the copy. They sit on the slow side of 1×, so the speed ceiling from ADR 0124 is not engaged.

### 2. It fires when the first song lands — not at first launch

The trigger is the completion of the first successful import, not app install, not the end of the
intake, and not a timer.

This is the article's behavioural-trigger principle, but the reason to adopt it here is stronger than
the general argument: it is the only trigger under which the flow can actually run. Arming it at
install would put a walkthrough on screen whose first step is impossible, and whose only honest
instruction would be "go and import something" — which is an empty-state hint's job, and is already
handled as one.

The consequence is a clean division of labour. **Getting the first song in is the empty state's
problem. Knowing what to do with it is the flow's problem.** Neither surface has to do both.

### 3. A checklist of four, with the first item honestly pre-checked

The flow is presented as a four-item checklist with a progress indicator: the import, then the three
steps. The import arrives already complete, because by §2 it *is* already complete.

The endowed-progress effect is real and we are using it deliberately, but only in the form where the
tick is true. Pre-checking something the player has not done in order to manufacture momentum is a
small lie told at the first moment of the relationship, and we are not doing it.

### 4. Offered once, gated on experience, skippable at every step

The intake from ADR 0113 already asks how long the player has been playing. A player who reports
substantial experience gets the flow **offered** — a single dismissible entry point — rather than
started. Everyone else gets it started, and can leave at any step.

Dismissal is permanent and silent. If it is declined, or abandoned partway, it does not return on the
next import, the next launch, or the next song. Guidance that re-offers itself after refusal stops
reading as help.

Re-entry is available on demand from the help catalog (§6), which is where someone who changes their
mind will look.

### 5. Ceremony exactly once, at the first loop

The musician-voice principle in the backlog frames completing the first loop as the moment the player
becomes a musician, and asks that the app mark it. That pulls against the restraint thesis, and the
resolution is a split rather than a compromise:

**Silent during, ceremonial once.** Steps 1 and 2 complete without celebration — a tick, nothing
more. The first completed loop is marked, in the app's own voice, and then never again. Not on the
second loop, not on the second song, not on completion of the checklist as a whole.

One marked moment reads as meaning. Three read as a theme park ride.

### 6. Each step points at the catalog rather than explaining itself

"Why 50%?" and "what is a marker for?" are questions with real answers, and ADR 0145 already built
the place those answers live. Each step carries a single link into the catalog instead of an
expandable explanation, a tooltip stack, or a video.

This keeps the flow to instructions and keeps the reasoning somewhere it can be found later by
someone who is no longer in onboarding.

### 7. The copy is ours

The method comes from a practice author; the words do not. Every string in this flow is written by us,
per the standing content-strategy guardrail. Nothing in the flow quotes, paraphrases closely, or
attributes.

### 8. Activation is one loop, and we will only ever see part of it

The measure of this flow is **a first loop created**, and the time from install to that event. Not
sessions, not launches, not checklist completion — checklist completion is tracked only to be checked
*against* activation, since high completion with flat activation would mean the checklist is teaching
the wrong thing.

Two honest limits, recorded so they are not rediscovered as surprises:

- **The denominator is the consenting subset.** Analytics are opt-in by ADRs 0120 and 0147, and the
  prompt appears after a first practice. Some players will activate before we are permitted to
  observe that they did. Retention cohorts are directional here, never a census.
- **The value moment is partly off-screen.** Every comparable product measures an action completed
  inside itself. Ours completes with an instrument in the player's hands. "First loop created" is a
  proxy for practising, chosen because it is the last thing we can honestly see.

### 9. No AI chooses the path

ADR 0092 remains Proposed. Nothing in this flow branches on a model, and the personalisation here is
one branch on one intake answer (§4). Segmenting the path by genre or stated goal is available and is
rejected: it would produce different tempo suggestions and different copy for no evidence that either
helps, which is the over-engineering this ADR is written against.

### 10. Marker auto-naming is a prerequisite, not part of this

Step 2 requires markers to name themselves on drop. That does not exist today — `Marker` has no
default-name derivation, unlike sessions, collections and song-routines. It is small, self-contained,
and useful independently of this flow, and it lands first.

> **Correction (2026-08-11): this section is simply wrong, and there is no prerequisite.**
> Markers have named themselves on drop since the action was written:
> `WaveformPracticeModel+Actions.dropMarkerAtPlayhead()` calls
> `AutoName.next(prefix: "Marker", existing: markers.map(\.label))`, yielding "Marker 1", "Marker
> 2", …, and the doc comment directly above it says so. Confirmed in the running app.
>
> Nothing was ever blocked on this. The claim appears to have been written from the absence of a
> `Marker`-side `defaultName` helper — sessions, collections and song-routines each have one —
> without checking the call site, where the shared `AutoName` utility does the job instead.

## Consequences

- **A player who never imports a song never sees any of this.** Accepted, and correct: there is
  nothing to teach them yet. It does mean the import empty state carries more weight than before, and
  should be reviewed on its own terms.
- **The flow can only be built after marker auto-naming.** One small dependency, ordered ahead.
- **Experienced players get a weaker onboarding by design.** They are trusted to explore, and can
  re-enter from the catalog. If activation data later shows they activate worse than beginners, §4 is
  the clause to revisit.
- **We are choosing not to teach exercises, routines, or the planner this way.** Those seed with
  content and are closer to conventions the player has met before. If they need guidance, it is a
  separate decision and probably a different mechanism.
- **Dismissal is permanent, so a mis-tap costs the player the flow.** Mitigated by catalog re-entry,
  and preferred to any design that keeps asking.
- **Activation cannot be measured completely.** §8 is the record of that, and of why we are proceeding
  with a proxy rather than pretending to a census.
