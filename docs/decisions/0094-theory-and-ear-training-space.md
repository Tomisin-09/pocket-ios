# 0094 — Theory & ear-training space: direction and the no-grading line

- **Status:** Proposed (2026-07-17)
- **Date:** 2026-07-17
- **Sets direction for:** a future "Theory / Ear" practice space. This ADR **does not schedule a build** —
  it fixes the boundaries so the first slice, when scheduled, doesn't re-litigate what's allowed.
- **Builds on:** ADR 0070 (Pocket never grades the player), ADR 0093 (the shared chord-naming theory core),
  ADR 0085/0091 (the 12-scale catalog + mode/box model), ADR 0092 (AI strategy — the coach lever).

## Context

Pocket has, so far, deliberately avoided anything that smells like a music-theory quiz, because the
product's spine is ADR 0070: **the player is the judge; the app never scores, grades, or pass/fails
playing.** That has left an obvious gap — the app knows a great deal of objective harmony (12 scales with
modes and bebop tones, CAGED boxes, movable chord grips, and now a chord-naming engine, ADR 0093) but
offers no place to *explore or internalise* it. Players ask for interval training, "name that chord,"
scale/mode exploration. The worry has been that these violate the no-grading rule.

They don't — and it's worth stating exactly why, once, so this doesn't get re-argued every slice:

**The no-grading rule (ADR 0070) is about the *subjective* act of playing.** It forbids the app judging
*how you played* — your timing, tone, feel, "accuracy." It says nothing about **objective facts of music**.
The interval between C and G *is* a perfect fifth; `{C, E, G}` *is* a C major triad; the second mode of C
major *is* D Dorian. These are true independent of any performance. A tool that tells you an interval's
name, or plays two notes and lets you name them, assesses **no performance** — there's nothing subjective
to grade. The [[chords-theory-direction]] direction note and the 2026-07-17 backlog entry already reached
this conclusion; this ADR ratifies it as policy.

The trap is not *theory* — it's the **quiz framing**. "You got 7/10, wrong!" turns objective recall into a
scored test, and a scored test of your *ear* slides right back toward judging you. So the line isn't
"theory yes / ear no"; it's **"identity and self-judged practice yes / app-scored right-wrong no."**

## Decision

- **T1 — There will be a dedicated Theory / Ear space, separate from the chord/scale *authoring* surfaces.**
  Reference and exploration don't belong inside the exercise editors (which build practice content); they're
  their own destination. This also means ADR 0086's "no key / no numerals on chord surfaces" does **not**
  bind here — that decision was scoped to the chord-*template* surface. A theory space may legitimately show
  keys, intervals, degrees, and numerals, because *that is its subject*.

- **T2 — Two permitted modes, one forbidden. The forbidden one is the design constraint.**
  - **(a) Reference / exploration — always allowed.** Sound and show objective structure with no
    right-answer loop at all: an **interval player** (pick two notes / a named interval, hear it, see it on
    the board), a **chord voicer** that sounds the shape you built (ADR 0093's engine names it; this plays
    it), a **scale/mode explorer** with audio over the existing 12-scale catalog. Pure exposure — you can't
    "fail" a reference tool.
  - **(b) Call-and-response, *self-judged* — allowed.** The app **plays** something (an interval, a chord
    quality, a lick) and asks you to **echo it on your guitar**; then *you* decide whether you matched, and
    tap to hear it again or reveal the name. **Nothing listens; nothing scores.** This is the ear-training
    analogue of the whole app's stance — like the practice engine, it presents and gets out of the way; the
    player is the judge (ADR 0070's exact words).
  - **(c) App-scored right/wrong quizzes — forbidden.** No "the app plays X, you tap an answer, it says
    correct/wrong and tallies a score." A multiple-choice **identify-the-interval** screen where the app
    grades the tap is the bright line we do **not** cross — it is a test of the player, dressed as theory.
    (Note the asymmetry that keeps this honest: the **chord identifier** (ADR 0093) names a shape *the
    player chose to build* — the app answering the player's question. A quiz inverts it: the app asks, the
    player answers, the app scores. Same engine, opposite direction; only the first is allowed.)

- **T3 — No streaks, scores, XP, accuracy %, or leaderboards anywhere in the space.** These are the
  gamification wrappers that smuggle grading back in even around allowed content. Progress, if shown at all,
  is **exposure-based and self-directed** ("you've explored 8 of 12 modes"), never performance-based.

- **T4 — Audio is a first-class requirement and it's *synthesised reference tone*, not the player's
  recording.** These tools must *sound* notes/chords. That audio is generated reference pitch (a simple
  synth/sampled tone over the existing engine), entirely distinct from ADR 0069 mic recordings and ADR
  0001/0064's "player audio never leaves the device" walls — nothing here captures, analyses, or transmits
  the player's playing. Call-and-response (T2b) plays *to* the player; it never listens.

- **T5 — Built on the shared theory core (ADR 0093), in-house, offline.** The space consumes
  `Core/Theory/` (the chord namer, and a sibling interval/scale reader added when scoped) plus the existing
  scale catalog — deterministic, local, no network. Content is generic common-practice theory authored
  in-house (ADR 0065 T8 / [[guitargearfinder-content-strategy]]), never anyone's protected curriculum.

- **T6 — A "coach that explains *why*" is an AI feature and stays deferred.** Anything that *teaches in
  prose*, explains a substitution, or adapts a path to you is ADR 0092 territory (additive, opt-in,
  key-in-proxy, deferred/paid). This space is the **deterministic, always-free reference-and-drill floor**
  underneath that; the AI layer, if/when it lands, sits on top and still never grades (ADR 0092 + 0070).

## Consequences

- **The "is theory even allowed?" question is closed.** Future slices cite T1/T2 instead of re-deriving the
  reconciliation. The rule crisply is: *objective identity and self-judged practice, yes; app-scored
  right/wrong, no.*
- **A concrete, safe first-slice menu exists** without committing to one: interval player, chord voicer
  (pairs naturally with the ADR 0093 identifier — build names it, this sounds it), scale/mode explorer,
  self-judged call-and-response. Each is independently shippable and clearly on the safe side of T2.
- **The engine investment compounds.** ADR 0093's `Core/Theory/` is the reason this space is cheap — naming,
  intervals, and scale degrees are one core with several consumers, not bespoke logic per screen.
- **The no-grading spine is *reinforced*, not bent.** By naming the forbidden mode (T2c) explicitly and
  banning gamification (T3), the space becomes a demonstration of the philosophy rather than an exception to
  it — the same "present, then get out of the way" posture as the practice engine.
- **Scope risk is the quiz gravity well.** Ear-training UIs conventionally *are* scored quizzes; the design
  pressure to add a score will be constant. T2c/T3 are the guardrails; any slice proposing a tally or a
  correct/wrong verdict is out of bounds by this ADR and needs a new one to change that.

## Alternatives considered

- **Don't build a theory space at all — it's too close to grading.** Rejected — that conflates *theory* with
  *quizzing*. The objective/subjective split (T2) lets us serve a real, requested need without touching the
  no-grading spine; refusing the whole area over the quiz risk throws out reference and self-judged practice
  that are unambiguously safe.
- **Build a conventional scored ear-trainer (it's the genre standard).** Rejected — T2c. A tallied
  right/wrong test of the player's ear is exactly the judgement ADR 0070 forbids, and "but it's theory"
  doesn't launder it. Self-judged call-and-response gives the practice value without the verdict.
- **Fold theory tools into the existing chord/scale editors.** Rejected (T1) — the editors *author practice
  content*; exploration/reference is a different job and a different mental mode, and stuffing keys/intervals
  back into the chord editor re-opens the ADR 0086 clutter we deliberately removed there.
- **Make the whole space an AI tutor.** Rejected as the *floor* — the deterministic reference/drill layer
  must exist offline, free, and trustworthy first (T5); AI is an additive lever on top (T6 / ADR 0092), not
  the substrate.
