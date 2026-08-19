# ADR 0171 — a goal that outlives the session

- **Status:** Accepted
- **Date:** 2026-08-19 (`pocket-276-long-term-goals`)
- **Relates to:** ADR 0015 (the planner's goal model — S1 "the goals are *not equal*", S5 weight,
  S6 met, S7 "one near-term goal"), ADR 0014 (the session layout the goals feed),
  ADR 0129 (the block model that cut Quick to three items and forced round-robin),
  ADR 0117 (Progress is read-back only), ADR 0100 (Journal is where you read back what you did),
  ADR 0046 (Practice is where you do the work), ADR 0070 (reflect, never grade),
  ADR 0162 (Settings is organised by "what am I changing?" — and why a goal is not a setting),
  ADR 0167 / `ReferenceLink` (the reorder mechanics and the additive-model precedent),
  ADR 0111 / ADR 0120 (the "second read path" failures a tier flag would have repeated)

## Context

The planner's `Goal` has always described **one session**. You open *Today's session*, keep or add
a goal, set it Low/Normal/High, and generate. The goal persists between generations, but
everything about where it lives says *today*: it sits on a screen titled "Today's session", its
weight is documented as how hard it pulls *today*, and it is only ever seen on the way to pressing
Generate.

That is not how the four shipped `GoalTemplate`s read. *"Learn a song from your library
end-to-end"*, *"Push picking and legato technique faster, cleanly"*, *"Grow soloing vocabulary over
scales you know"* — these are month-scale ambitions. Only their **location** and their **effect**
make them short-term. A player who wants to say "over the next while I am working toward playing
*Wish You Were Here*" has to re-say it, as a today-goal, every time they plan.

### ADR 0015 S1 was always half-built

Verbatim, from S1: *"the goals are **not equal** — the user weights/orders them."* `weight` shipped
in S5. **Ordering never did.** A ranked tier is not a departure from 0015; it is the missing half
of a decision already taken.

### What the planner actually needs from a goal

`PlannerGoal` (`PlannerLibrary.swift`) is the whole contract with the deriver. A new object needs
exactly two things to produce candidates:

1. **`skillIDs: [String]`** — at least one id in `TechniqueTaxonomy`. The only mandatory field.
2. **a unique `uid`** — not for derivation, but for fairness: `SessionBuilder.roundRobin` keys on
   `goalUID`, and goals sharing a uid collapse into one.

`weight`, `targetSong` and `isMet` all default. **Nothing in the derivation reads a date, a horizon
or a deadline.** That is the fact that makes the central decision below cost nothing.

## Decision

**Goals become two tiers, split by scope of intent rather than by duration.**

- **Short-term (`Goal`, unchanged)** — what I want out of *this* session. Lives on Today's session.
  **Weighted**; the weight expresses how hard it pulls today.
- **Long-term (`LongTermGoal`, new)** — a standing outcome I am working toward. Lives in Practice.
  **Ranked**; position is the only ordering, and it persists between sessions.

### D1 — A long-term goal is open-ended. No horizon, no deadline, no date field of any kind.

Not "no deadline by default" — **no date column on the model**. With nothing stored, there is
nothing for the app to be late against, so the no-verdict property is *structural* rather than a
promise kept by copy. This is the strongest available reading of ADR 0070, and it is cheap because
the deriver never wanted a date in the first place.

A dated horizon would also have collided with tooling: `check-manual.py` C7 is
`re.compile(r"streak|this year", re.IGNORECASE)` and fails any published manual page containing
that phrase. A "This year" horizon option would have broken every push. Dropping the horizon
**retires** that collision rather than working around it — recorded here so it is not reintroduced
later as an obvious enhancement.

### D2 — A separate `@Model`, not a tier flag on `Goal`.

Both options are schema-freeze-safe (a new entity is additive; only retypes, renames and removals
are now-or-never). So the choice is about failure modes.

A `tierRaw` discriminator on `Goal` would reuse the editor and the picker, but it makes **every
existing read site responsible for filtering** — `PlannerView.activeGoals`, `metGoals`,
`PracticePlanner.planGoalSession` — and any one that forgets leaks a long-term goal into the
Today's-session list. That is exactly the "second read path" failure this repo has already been
bitten by twice (ADR 0120 analytics, ADR 0111 song links). **A separate model makes the leak
impossible to write.** The tiers also genuinely diverge: one is ranked, the other weighted.

Fields: `uid`, `title`, `skillIDs`, `order`, `isMet`, optional `targetSong` (nullify), `dateAdded`.
Declaration defaults on every non-optional attribute, per the model discipline (ADR 0011/0012/0036).

### D3 — Rank drives **both** the derived weight and the round-robin visit order.

This is the decision that stops rank being decorative. `SessionBuilder.roundRobin` deals one item
per goal per pass, visiting goals in the order their **best candidate** ranks. With ten long-term
goals and a Quick session's three items, only the first three goals visited ever appear — so if
visit order stayed dueness-derived, ranks 4–10 would change nothing a player could observe.

Two mechanisms, together:

- **Weight.** `LongTermRank.weight(forOrder:)` maps rank 0 → `1.5`, decaying `0.1` per position to
  a floor of `0.5`. The scale is deliberately commensurable with `GoalPriority` (0.5 / 1.0 / 2.0):
  a top-ranked long-term goal outpulls a Normal today-goal but **never outpulls an explicit High
  one**. Today wins when today is asked for.
- **Visit order.** `roundRobin` gains a `ranking: [UUID]` parameter. Goals named in it are visited
  **after** all unranked goals, in rank order. So short-term goals lead — they are about this
  session — and long-term goals fill the remaining passes by rank, deterministically.

The floor exists for data over the cap (D4) and is reached exactly at rank 10, which is the
property the test pins.

### D4 — Ten long-term goals, and that cap is argued, not assumed.

ADR 0015 S7 says the default is *"one near-term goal"* — about modesty and count. Ten is
justified against it by **ranking**: an unranked list of ten is a pile, where a ranked one is a
priority order the player authored and the planner obeys. The cap is enforced at the add button,
not by refusing a save.

### D5 — Templates are shared by both tiers, and there are now ten of them plus a way past them.

`GoalTemplateLibrary` seeds either tier unchanged. Moving the four templates to the long-term tier
was considered — they genuinely read long-term — but it would leave the shipped tier with no
authoring affordance and invalidate `docs/manual/sessions.md` and its five shot markers. The tiers
differ by **scope of intent**, not by vocabulary, so sharing the vocabulary is the coherent call.

**Amended after device testing.** Four starting points turned out to be too few to describe what a
player is actually working on, and the gap was most obvious on the long-term tier, where a goal is
meant to last months. Six were added — *Tighten your timing*, *Clean up your chord changes*, *Train
your ear*, *Learn the fretboard*, *Strengthen your fretting hand*, *Write your own music* — chosen
to cover every skill family the planner can actually resolve.

Every seeded id is pinned by `SessionGoalSourceTests`, and the check is stricter than "does this
string exist in the taxonomy": it also asserts each skill is either **served by an
`ExerciseTemplate`** (Path A) or **repertoire** (Path B). The failure it guards is silent — a
template naming a real-but-unservable skill such as `fret.vibrato` renders as an ordinary row and
simply deals nothing.

**And a *Something else* row now skips the templates entirely**, opening the full skill catalogue.
This reads like a reversal of ADR 0015 Decision 7's "no blank-goal option", and it is worth being
precise that it is not. That ban was on a goal with **no skills** — *"an empty one schedules
nothing"* — and the thing that actually enforces it is the editor's **Save gate**, disabled until
at least one skill is kept; the ban on *free text* is likewise untouched, because the catalogue is
the same fixed taxonomy a template seeds from. What the row removes is only the obligation to begin
from someone else's phrasing of the goal.

### D6 — Two surfaces, split by role: an editable list in Practice, a read-only echo on Progress.

1. **The list** — a row in `PracticeView`'s first section, beside the planner card and Routines.
   Same altitude, one tap from the screen that consumes it, and outside any session. Ranking,
   adding, editing and deleting all happen here and only here.
2. **The echo** — a read-only section on `PracticeProgressView`. This is what pairs goals with the
   practice that accumulates against them.

**The split is what makes the echo legal.** ADR 0117 rejected reaching Progress from Practice with
*"Practice is where you do the work; Journal is where you read back what you did"*, and
`JournalTabView` says Progress and the timeline share a door because *"both are read-only practice
history"*. **The echo carries no controls** — no add, no reorder, no edit, no swipe, no tap-through.
A reflection honours that rule; an editable list on that screen would break it.

Home was never an option (ADR 0102's "no sixth peer"). Settings was rejected: ADR 0162 organises it
by *"what am I changing?"* **about the app**, and a goal is practice material, not configuration.

### D7 — The echo shows facts, and re-uses the deriver rather than a lookalike.

`PracticeRun` records `unitUID` and **has no goal reference** — a run never records which goal it
served, and candidates are derived at plan time. So "when did I last practise something serving
this goal" can only be answered by re-deriving skill → unit. That is approximate, which is fine for
a reflection and unacceptable for a score.

Rather than hand-roll a second skill→unit walk that could drift from the planner's, the echo calls
**`CandidateDeriver.deriveCandidates` itself**, one goal at a time, and takes the newest
`lastPracticed` among the candidates it returns. The screen therefore attributes exactly what the
planner would schedule, by construction.

Shown: the ranked title, the skill count, and when something serving it was last practised — or
*"not yet"*. Met goals list after, with a checkmark and no facts.

**Not shown, ever:** *"3 of 5 skills covered"*, a percentage, a progress bar, or an ETA.
`PracticeLog` is blunt about why — *"a denominator states a target, and a target is habit-pressure
under another name."* The register is `hourMilestones`': *"a wall you pass rather than a ladder
you're being timed on."*

### D8 — The planner's section header becomes "This session".

With both tiers using the word "goal", the shipped `Goals` header on `PlannerView` is no longer
unambiguous. It becomes **"This session"**, and its add button becomes *"Add a goal for this
session"*. This is a real edit to a screen already photographed for the manual, and it is the
price of D9 — paid deliberately.

### D9 — The tier is called **"Long-term goals"**.

Three things in the app are now called "Goal": the short-term `Goal`, this tier, and the journal's
🎯 `EntryKind.goal` ("an intention set"). Two alternatives that would have removed the collision
outright were considered and rejected in *Alternatives*. "Long-term goals" keeps the collision and
pays for it with D8, because it is the only candidate that **teaches the relationship for free** —
it is the same word plus a qualifier, so a player who understands one tier understands the other on
sight, with no glossary sentence and no new noun.

The journal tag is untouched. A written note tagged 🎯 and a ranked list are different enough in
form that the shared word does not mislead in practice.

### D10 — The planner names which tier it is building from, and lets you choose.

**Added after device testing, and it corrects a dishonesty in D3 rather than reversing it.** As
first built, the planner listed the short-term goals under a heading and Generate then *also*
consulted the ranked long-term list — a list the player could not see from that screen. The session
you were handed had an input you had no way to account for.

Two changes, and they are halves of one fix:

- **A `Build from` segmented control** — `Both` (default) · `This session` · `Long-term`. Segmented
  rather than a toggle because the three states are exclusive and equally ordinary, and because the
  segment labels are what *name* the distinction. **Unpersisted**, by the same reasoning as
  `SessionConstraint`: which tier this afternoon follows is a fact about this afternoon, not a
  preference. It is hidden entirely until a long-term goal exists, since before that it would offer
  three options with identical behaviour.
- **The long-term list is shown on the planner**, read-only, under its own heading — and **the tier
  the source excludes is hidden outright.** The first cut dimmed it instead, on the reasoning that a
  section which simply vanishes teaches nothing about what was switched off. Device testing showed
  that reasoning assumes the disappearance is unexplained, and it isn't: the labelled `Build from`
  segment sits directly above and names the state. The control is the explanation, so the greyed
  copy was only something to scroll past.

  The visibility test is `drawsOn…`, **not** `plan.uses…`. The plan reports whether a tier has
  anything to *contribute*; a selected-but-empty tier still needs its section, because that is where
  its empty state and its "add one" affordance live.

  `PlannerView.effectiveSource` falls back to `.both` whenever the standing list is empty — which is
  exactly when the control is off screen. Without it there is a reachable dead end: pick
  `Long-term`, mark the last standing goal met, and the stored selection keeps hiding the
  short-term section on a planner that now has no visible way to get goals back. Pinned by
  `testWithNoStandingGoalsEverySourceBehavesAsBoth`.

### D11 — Clearing a session's goals is one action, and it spares the history.

Short-term goals are meant to be about today, so a list of them accumulates. `Clear this session's
goals` sits under the add button, **appears only when there is something to clear** (a permanent
destructive row on a screen whose ordinary state is one or two goals would be its loudest element),
and confirms before acting.

It removes the **active** goals only. A met goal is already shaping nothing, and ADR 0015 S6 exists
precisely so that marking something met *keeps* it — a clear-for-today that quietly binned the
history would invert that. The dialog states what it spares as well as what it removes, because
long-term goals are what a player would most fear losing to a button with "clear" on it and they
live on an entirely different screen.

Note for the next destructive row: `Button(role: .destructive)` reddens the **title only**. A
`Label`'s glyph keeps the list's tint, so the row ships as red text beside a blue icon unless the
whole label is given `PocketColor.danger` explicitly. Caught by looking, not by any test.

The pure `SessionGoalSource.plan(activeShortTermCount:activeLongTermCount:)` owns the rule, so
"which list feeds Generate" is unit-tested rather than living in a view's `if`. Selecting a tier the
player has left empty **falls back to the due-ranked Quick path rather than refusing** — the button
always produces something to practise (ADR 0073).

D3's ordering is unchanged and is now what `Both` means: today's goals lead the round-robin, the
long-term ranking fills the rest.

**Rejected:** an include toggle per section (both can be off at once, needing its own empty state
and explanation); two separate Generate actions (the screen has one CTA by design); and leaving the
union implicit but merely showing both lists — which fixes the honesty problem but gives the player
no say, and a say is what was asked for.

## Alternatives considered

- **A tier flag on `Goal`.** Rejected — D2. Reuses more code, but makes a leak into Today's session
  a one-forgotten-filter mistake, twice-precedented in this repo.
- **A deadline, or an optional one.** Rejected — D1. An optional date is still a date the app can
  be late against; the no-verdict property must be structural, not conventional.
- **Reflective only — no planner injection.** Rejected. `skillIDs` would earn nothing, and the tier
  would be a notepad. The player's stated priority ought to move what they are handed.
- **Long-term goals lead the round-robin.** Rejected — D3. The player opened *Today's session* and
  named what they want today; that intent wins the first passes.
- **Rank as visit order only, weight left neutral.** Rejected. Rank would then be invisible in any
  session long enough to reach every goal — exactly the sessions where priority matters most.
- **"What you're working toward" as the name.** Rejected — D9. Best reading on Progress, and it
  removes the collision, but it has **no singular noun** (every add button and row action needs a
  workaround), it is 26 characters in a nav bar that already carries a back chevron, and as a
  Practice-hub row title it leaves the subtitle with nothing left to say.
- **"Ambitions".** Rejected — D9, and it was close. Short, singular, collision-free, and it would
  have saved D8's edit to a shot manual page. It loses on two counts: it needs a teaching sentence
  to relate it to goals at all, and it is the only candidate with a temperature — *"Ambitions ·
  not yet"* reads loaded on a screen whose whole job is to not judge (ADR 0070).
- **Moving the four templates to the long-term tier.** Rejected — D5.
- **An editable list on Progress.** Rejected — D6. Breaks ADR 0117's read-back-only rule.
- **Goals in Settings.** Rejected — D6. ADR 0162's organising question is about the app.

## Consequences

- The planner grows a third control and a second goal section; `PlannerView` is at 372 lines
  against the 400-line lint cap, so the read-only section lives in its own file
  (`PlannerLongTermSection`) and the next addition to that screen should extract rather than append.
- A second `@Model` in the container. Additive, so lightweight migration covers it; the schema
  freeze permits new entities.
- `SessionBuilder.roundRobin` and `select` and `buildSession` gain a defaulted `ranking` parameter.
  Every existing call site and test is unchanged by construction.
- `PracticePlanner.planGoalSession` gains a defaulted `longTermGoals` parameter. With both tiers
  empty the Quick path is unchanged; with either non-empty the goal path runs.
- `PlannerView`'s `Goals` section becomes `This session` — `docs/manual/sessions.md` and its shot
  markers need re-checking, and the section is on the Phase 5 shoot list.
- Progress gains a section that runs `deriveCandidates` per goal. Pure, library-sized, and only on
  a screen the player navigated to; it is not on any hot path.
- A long-term goal marked met stops contributing candidates (the deriver already skips `isMet`) but
  stays in the list, per ADR 0015 S6.
- The word "goal" now names three things. D9 accepts this knowingly; if it proves to confuse in
  beta, the cheapest reversal is renaming this tier — the model name is internal.
