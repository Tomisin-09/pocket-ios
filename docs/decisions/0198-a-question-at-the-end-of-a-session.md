# ADR 0198 — A question at the end of a session

- **Status:** Proposed
- **Date:** 2026-09-07 (`pocket-303-oracle-pedagogy-amendments`)
- **Relates to:** ADR 0143 (the session journal this changes the copy of), ADR 0142 (journal reach —
  `QuickJournalSheet` mid-run, which this deliberately leaves alone), ADR 0186 (a reason to come
  back — whose no-interruption line this respects by adding no surface at all), ADR 0187 D22 (the
  mirror that needs process material to reflect) and D16 (the Journal gets no paid door),
  ADR 0144 D2 (the Journal is free forever), ADR 0070 (no performance feedback)
- **Schema:** none. This is placeholder copy through a seam that already exists.

---

## Context

ADR 0187 D15 settles the Oracle's reading at weekly, on the honest ground that it reads a period.
That is right for a reading. It is not where reflection happens.

Reflection does its work while the trace is still warm — at the end of the sitting, when the player
can still feel which bar fell apart and what they did about it. A week later, the same person is
writing a summary. A summary is a different, and much weaker, thing.

The obvious move is to put the Oracle there, and every route to it is closed, correctly:
ADR 0186 rejected the app speaking unbidden; ADR 0187 D16 keeps the paid door out of the Journal;
ADR 0144 D2 makes the Journal free forever on an explicit trust argument. Anything that lands at
the end of a session has to be free, local, silent and already-present.

It already is. The end-of-session note composer exists and it asks a question today. The question
is just the wrong one.

| Site | Today |
|---|---|
| `RoutineBlockDoneView.swift:241` | *"Jot how it went…"* |
| `JournalSheet.swift:126`, `:255` | *"What happened?"* |
| `QuickJournalSheet.swift:69` | *"What just happened?"* |

*"What happened?"* asks for an **inventory**, and it gets one: *"scales, 20 min, then the song."*
That is the volume mirror of ADR 0187 D22, written by the player instead of by the app — and it is
exactly the material that gives the Oracle nothing to reflect.

## Decision

**The end-of-session composer asks `What changed?`**

One question, in the placeholder, at the end of a session. Nothing else moves.

`JournalNoteComposer.swift:74` already takes an injected `placeholder`, so this is a copy change
through a seam that exists, not a new surface, not a new view, and not a new setting.

Four constraints, each of which is the decision as much as the wording is:

1. **It stays a placeholder.** Not a label, not a required field, not a validation, not a second
   field. An empty note is still a valid note. A prompt that must be answered is a chore, and ADR
   0070's whole posture is that the app does not ask the player to account for themselves.
2. **The mid-run sheet keeps its wording.** `QuickJournalSheet` is a **capture** moment, not a
   reflection one — the player is mid-practice with the instrument in their hands, and
   *"What just happened?"* is the right question there. Reflection asks for a look backwards, and
   there is nothing to look back at yet. This distinction is why the change is per-site rather
   than a global find-and-replace.
3. **The question asks about change or intention — never quantity, never quality.** *"What
   changed?"* passes. *"What would you try differently?"* passes. **"How did it go?" fails**: it
   asks for a rating in words, which is ADR 0070's prohibition arriving through the one door the
   app left open.
4. **One question, fixed.** Not a rotating set. A rotating prompt is a personality, and the
   composer is not a character — ADR 0187 D9's *"a tool, not a confidant"* applies here too, and
   applies harder because this surface is free, unmetered and on every session.

## Why this sits in an ADR at all

Because it is four words of placeholder copy with an outsized effect, and the next person to touch
this file will not know that.

It is also the cheapest thing in the entire AI plan. No tier, no quota, no network, no inference,
no App Review surface, no privacy artefact. And ADR 0187 D22 depends on it: a journal full of
*"practised scales, 20 min"* leaves the mirror with volume and nothing else to reflect. A journal
full of *"the shift to 5th position stopped buzzing once I stopped squeezing"* gives it everything
D22 asks for. **The free half of the plan is what makes the paid half worth paying for.**

## Alternatives considered

- **Two questions, or a short form.** Rejected. The end of a session is when the player most wants
  to put the guitar down; a form is what makes the composer get skipped, and a skipped composer
  produces no material at all.
- **A rotating prompt set.** Rejected — see constraint 4.
- **Prompting only after a long session, or only after a routine.** Rejected. A conditional prompt
  is a judgement about which sessions were worth reflecting on, which is the axis this product
  does not have.
- **Letting the Oracle write the question.** Rejected on every ground at once: ADR 0187 D16 (no
  paid door in the Journal), D2 (pull, not push), and cost. The value here is that it is free and
  always there.
- **Counting reflections, or surfacing how many sessions have a note.** Rejected. That is a streak
  wearing a different hat (ADR 0187 D6 rule 6, ADR 0117).

## Consequences

- Copy changes at `RoutineBlockDoneView.swift:241` and `JournalSheet.swift:126`/`:255`.
  `QuickJournalSheet.swift:69` is deliberately untouched.
- `docs/manual/` restates journal placeholder copy; `scripts/check-manual.py` holds it to what the
  app says, so the manual moves in the same change (ADR 0165).
- Any UI test asserting on the old placeholder string.
- ADR 0187 D22's fixtures should be recorded against journals written **after** this lands, or the
  eval set inherits the inventory-shaped notes the old question produced.
