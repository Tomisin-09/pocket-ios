# guitargearfinder.com — reference-material catalog & IP-provenance ledger

Working record of the practice/technique resources by **Aaron Matthies
(guitargearfinder.com)** we are reviewing, what each one maps to in Pocket,
and how we may use it.

> The raw source files live, git-ignored, in `research/guitargearfinder/`
> (reference only — see that folder's README). **This file contains no copied
> text from those sources** — only our own summaries, mappings, and decisions.
> It is the durable provenance trail and the basis for any future licensing
> conversation with the author.

## Why this ledger exists
If we commercialise Pocket, we need to know precisely what (if anything) of
Aaron's we depend on. This file makes that boundary explicit instead of
accidental: pure-method rows need no licence; `verbatim-needed` rows are
quarantined until a deal exists.

## Key triage finding (read this first)

Every file splits into **method** (the pedagogy — how to develop a skill, how
to sequence/time practice) and **content** (his specific exercises, TAB images,
curated example routines, theory charts, and prose).

- **Pocket is an _engine_** — looping, the speed-trainer ramp, the planner. An
  engine needs the **method**, and the user brings their own **content** (their
  songs, their exercises). So **the core product can be built entirely from the
  `inspiration` (method) column — no licence required.**
- A licence from Aaron is only needed **if we choose to bundle his _content_**
  (a built-in exercise library, his example routines, his charts) as shipped
  material. That is an optional, additive product decision — not a dependency.

This is the single most important output of the triage: our roadmap does not
depend on licence-gated material; it would only *opt in* to it.

## Legends

**Relevance** — `high` build on it soon · `med` useful later · `low` marginal ·
`out` out of scope for Pocket.

**Pocket surface** — `planner` (routine/session generation, ADR 0014) ·
`automator` / `speed-trainer` (ADR 0013) · `song-library` (ADR 0011/0012) ·
`engine` (waveform / looping) · `onboarding-edu` (in-app guidance/education) ·
`technique-taxonomy` (a catalog of skills the planner can offer as candidates) ·
`none`.

**IP treatment** — how we intend to use it:
- `inspiration` — method/idea/fact only; we write our own expression. No licence
  needed.
- `adapted` — we restructure/reword substantially; still our expression. No
  licence needed, but log the lineage here.
- `verbatim-needed` — the value *is* his actual expression (his text, his
  original exercises/TAB, his curated routines, his charts/diagrams).
  **Licence-gated — do not build into shipping code until a deal exists.**

Most rows are *mixed*: the method is `inspiration`, the bundled content is
`verbatim-needed`. Only the `inspiration` half is on our build path.

## Catalog

### Planner cluster (ADR 0014 territory) — highest value, in flight

| File | Topic (our summary) | Relevance | Pocket surface | IP treatment | Maps to / notes |
|------|---------------------|-----------|----------------|--------------|-----------------|
| How Long to Practice Guitar | Practice-time science: forgetting curve, serial-position, diminishing returns, micro-rests; practice-vs-play | high | planner | inspiration (method) | **DONE → ADR 0014.** Already encoded. |
| How To Plan a Guitar Practice Routine | 4-step planning (define goals → identify needed skills → find exercises → time-box & split); argues routines should be *prioritised, not balanced*; 3 worked example routines | high | planner | inspiration (method) · verbatim-needed (the 3 example routines = curated compilations) | **Extends ADR 0014's selection side** — where candidates *come from* (goals→skills), which 0014's R6 assumes but doesn't derive. Candidate new ADR. |
| 5 Things To Do Every Time You Practice | Per-session checklist: tune, warm-up, challenge yourself (leave comfort zone), record & listen back, wipe strings | high | planner · onboarding-edu | inspiration (method) | Maps to planner block types (warm-up block; the "comfort-zone push" → difficulty progression) in ADR 0014. |
| 16 Ways to Get Better at Guitar | Meta improvement tactics: solid routine, daily practice, metronome, master one song, record progress, ear training, looper, jamming | med-high | planner · onboarding-edu | inspiration (method) | Several map to existing/planned features; good source of in-app nudges/onboarding tips. |
| How to Practice Guitar Without a Guitar | 6 off-instrument practice ideas: ear training, fretboard memorisation, theory, active listening, songwriting | med | planner · onboarding-edu | inspiration (method) | Off-guitar candidate items; reinforces ADR 0014's "practice ≠ playing" framing. |

### Speed / technique cluster (ADR 0013 speed-trainer)

| File | Topic (our summary) | Relevance | Pocket surface | IP treatment | Maps to / notes |
|------|---------------------|-----------|----------------|--------------|-----------------|
| How to Play Fast on Guitar | Speed pedagogy: picking control → hand sync → build speed; raise tempo only after clean reps; plateau & slow-down tips; 10 speed exercises | high | speed-trainer/automator | inspiration (method/progression) · verbatim-needed (10 exercises as TAB images) | **Validates & extends ADR 0013** — the "clean before fast / only step up after error-free reps" gate. Candidate ADR on speed-trainer staging. |
| Ultimate List of Guitar Finger Exercises | Finger dexterity/independence: 1234 + variations, wide-stretch, chord-flipping; metronome method | med | speed-trainer · technique-taxonomy | inspiration (method) · verbatim-needed (exercises/TAB) | Warm-up/dexterity drills; taxonomy seed. |
| 17 Best Alternate Picking Exercises | Method (accuracy→coordination→speed) + 17 graded exercises | med | speed-trainer · technique-taxonomy | inspiration (method) · verbatim-needed (exercises/TAB) | Technique taxonomy: alternate picking. |
| 8 Best Economy Picking Exercises | Same method + 8 graded exercises | med | speed-trainer · technique-taxonomy | inspiration (method) · verbatim-needed (exercises/TAB) | Technique taxonomy: economy picking. |
| 14 Best Sweep Picking Exercises | Same method + 14 graded exercises (advanced) | med | speed-trainer · technique-taxonomy | inspiration (method) · verbatim-needed (exercises/TAB) | Technique taxonomy: sweep picking (advanced). |
| 6 Hammer-On Exercises | Why-daily + tips (metronome, start slow) + 6 exercises + finger-combination drills | med | speed-trainer · technique-taxonomy | inspiration (method) · verbatim-needed (exercises/TAB) | Legato/hammer-on. Pairs with pull-offs. |
| 6 Pull-Off Exercises | Same pattern, pull-offs | med | speed-trainer · technique-taxonomy | inspiration (method) · verbatim-needed (exercises/TAB) | Legato/pull-off. Pairs with hammer-ons. |

### Theory & reference cluster (onboarding-edu) — lower priority

| File | Topic (our summary) | Relevance | Pocket surface | IP treatment | Maps to / notes |
|------|---------------------|-----------|----------------|--------------|-----------------|
| How to Practice Guitar Scales | Scale-practice *methods* (up/down, random directions, find-a-note, sequences, jam levels) + charts/PDFs | med | planner · onboarding-edu | inspiration (methods) · verbatim-needed (charts/PDFs) | The drill *methods* are reusable as scale-practice candidate items. |
| How to Memorize the Notes on the Fretboard | Two memorisation methods + a 3-week practice plan | med-low | onboarding-edu | inspiration (methods) · verbatim-needed (the 3-week plan = curated routine) | Fretboard-knowledge candidate item. |
| What is Ear Training | Concept; relative vs perfect pitch; how/how-long to practice; app suggestions | low-med | onboarding-edu | inspiration (concepts) | Concept only; recommends third-party apps. |
| Guitar Intervals Explained Simple | Interval theory reference + shapes chart + exercises | low | onboarding-edu/reference | inspiration (theory facts) · verbatim-needed (his charts/exercises) | General music-theory reference. |
| Ultimate Guide to the Pentatonic Scale | Theory + 5 positions + charts + exercises | low | onboarding-edu | inspiration (theory) · verbatim-needed (position charts/diagrams) | Theory reference. |
| Ultimate Guide to the Blues Scale | Theory + charts + example songs + licks | low | onboarding-edu | inspiration (theory) · verbatim-needed (licks/charts) | Theory reference. |
| How to Improvise on Guitar (Lesson 1) | Beginner improv approach + exercises + practice plan | low | onboarding-edu | inspiration (approach) · verbatim-needed (exercises/plan) | Beginner improv lesson. |
| Ultimate Guitar Glossary of Terms | A–Z term definitions with pictures | low | onboarding-edu/reference | inspiration (facts/definitions) · verbatim-needed (his wording & images) | Could seed in-app glossary/tooltips later; large file. |
| Parts of the Guitar | Acoustic/electric hardware anatomy diagrams | out | none / onboarding-edu | inspiration (facts) · verbatim-needed (diagrams) | Out of scope for a practice-looping app. |

## Licence-gated quarantine
Material whose value *is* Aaron's verbatim expression. **None may ship until
licensed.** (The methods these sit alongside are clean to encode — see each row.)

- All graded **exercise sets + TAB images**: alternate / economy / sweep picking,
  hammer-on, pull-off, finger exercises, the 10 speed exercises, improv exercises.
- The **worked example routines** in "How To Plan a Guitar Practice Routine"
  (beginner / intermediate / advanced) — curated compilations.
- The **3-week fretboard plan** in "How to Memorize the Notes on the Fretboard".
- **Theory charts/diagrams**: pentatonic positions, blues scale shapes, interval
  shapes, scale charts/PDFs.
- **Glossary wording & images**, and the **parts-of-the-guitar diagrams**.

## Recommended next steps (clean-to-encode, no licence)

_Status (2026-06-18): items 1–3 are now recorded — see "ADRs spawned" below. Build
deferred to the Phase-3 planner._

1. **Extend ADR 0014's selection side** — a `goal → required-skills → candidate
   items` model, plus the "prioritised, not balanced" principle, from "How To
   Plan a Guitar Practice Routine". This is the piece 0014's R6 assumes but
   doesn't yet derive. *(Candidate ADR.)*
2. **Speed-trainer staging gate for ADR 0013** — encode "clean before fast:
   only step the tempo up after N error-free reps", from "How to Play Fast" and
   the exercise-file method sections. *(Candidate ADR / refinement of 0013.)*
3. **A technique taxonomy** — a structured list of skills the planner offers as
   candidate practice items (picking variants, legato, finger dexterity, scale
   work, ear training, fretboard knowledge), derived as `inspiration` from the
   exercise/theory files **without any of his exercises/TAB**. Users attach their
   own material to each.

## ADRs spawned from this review
- [0014 — Practice-routine generation](../decisions/0014-practice-routine-generation.md) — from "How Long to Practice Guitar".
- [0015 — Goal-driven candidate selection](../decisions/0015-goal-driven-candidate-selection.md) — from "How To Plan a Guitar Practice Routine" (the planner's front-half + "prioritised, not balanced").
- [0016 — Speed-trainer staging gate](../decisions/0016-speed-trainer-staging-gate.md) — from "How to Play Fast on Guitar" + the exercise files ("clean before fast").
- [Technique taxonomy](../practice-techniques.md) — the clean-room skills vocabulary the planner selects from (ADR 0015 S2/S3).

## Future: first-party (in-house) content strategy

**Direction (recorded 2026-06-18):** rather than licensing Aaron's `verbatim-needed`
material, the intended path is to **build our own first-party practice content** —
exercises, drills, example routines, and theory/reference — so Pocket can ship skill
slots *pre-filled* without any third-party dependency.

Why this is the preferred route:
- The engine already needs **no licence** (it runs on the user's own material; see the
  key triage finding). In-house content is therefore **additive**, not a dependency — we
  can ship and grow it on our own timeline.
- It avoids an ongoing licensing/royalty entanglement and keeps the IP clean for
  commercialisation.
- The **technique taxonomy** (`docs/practice-techniques.md`) is the natural backbone:
  author first-party drills/TAB per `SkillID`, at known `difficulty` bands.

A licensing deal with Aaron / guitargearfinder.com remains a **fallback / accelerator**
(e.g. to seed a content library faster, or for co-branding) — not the default plan. When
we're ready to scope the in-house effort, give it its own brief/ADR; this note just fixes
the intent so we don't drift into baking his content in by default.
