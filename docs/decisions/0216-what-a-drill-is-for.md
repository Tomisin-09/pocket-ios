# ADR 0216 — what a drill is for

- **Status:** Accepted — **both slices built** (2026-09-11): slice 1 on `pocket-319-skills-you-can-see`,
  slice 2 on `pocket-320-shape-what-a-drill-is-for`. Slice 1 is everything that *shows* the link
  between skills and material; slice 2 is everything that *changes* it (D1–D3's rule, D6's editing,
  D7).
- **Date:** 2026-09-11 (`pocket-319-skills-you-can-see`, `pocket-320-shape-what-a-drill-is-for`)
- **Amends:** ADR 0073 — Decision 4's type-only resolution becomes a **default** each drill can narrow
  or expand (D1, slice 2). Path A/B and the soft prerequisite stage stand. Also its §4 (Decision 7):
  a goal may name a custom skill (D7).
- **Amends:** ADR 0074 — the ✨ skill-bucket chip row gives way to a real **Skills** section on the
  loop (D6, slice 2). Recognised bucket tags keep being read, so nothing tagged under 0074 stops
  working.
- **Amends:** ADR 0015 — S2's *"drawn from a defined taxonomy"* is no longer the whole vocabulary: a
  player may create a **custom skill** with their own description (D7, slice 2). The taxonomy stays
  the controlled vocabulary for everything the app authors.
- **Amends:** ADR 0171 — D5's *"the ban on free text is likewise untouched"* no longer holds for
  custom skills (D7, slice 2). The Save gate D5 actually relies on is unchanged.
- **Relates to:** ADR 0187 D24 (the Oracle's goal clarifier — this is the surface it will pre-fill,
  and ADR 0092 §A2's fallback for it), ADR 0211 (why the model version is not being built now),
  ADR 0070 and ADR 0171 D7 (counts, never a numerator), ADR 0139 O6 (*declared, never inferred*),
  ADR 0210 (the backfill that was deleted, and why this one never starts), ADR 0090 (present a model
  sheet by its `uid`), ADR 0189 (why the slice 2 fields are additive)
- **Schema:** slice 1 — none. Slice 2 — `Exercise.skillIDs` and `Loop.skillIDs` (`[String]`,
  declaration-defaulted) and one new entity, `CustomSkill`; additive, so ADR 0189's D1–D3 do not
  engage.

---

## Context

The Oracle is shelved (ADR 0211), and its goal clarifier (ADR 0187 D24, stage S3) is a model call
that needs S2's network stack, which `docs/directions-2026-09.md` §6 ranks *not now*. The reason
goals went first in that document holds without a model: `DueScore` is
`goalWeight × dueness × (1 − mastery/5)`, so a goal that doesn't say what it will schedule degrades
every session the planner builds.

Reading the planner showed the problem is not vague *wording*. It is that the link between a skill
and the player's own material is **invisible, fixed and closed**:

- **Invisible.** Nothing on any screen said which of your drills a skill would pull. The exercise ⓘ
  sheet's Template footer said the type *"groups the exercise in your library"* and never that it is
  also what decides which goals the drill answers. A loop reached a technique goal only through a
  free-form tag that happened to spell a type name (ADR 0074), visible nowhere but a row of ✨
  chips. Skills had names and no explanation anywhere.
- **Silent when empty.** `know.*` and `create.songwriting` resolve only to *Theory* exercises, and
  Theory has not been creatable since 2026-07-22. *Bends* and *Vibrato* resolve to no type at all.
  The only feedback is *"Nothing to schedule yet"*, and only when the whole session comes out empty
  (`PlannerView`), so a goal with one dead skill looks exactly like a goal with none.
- **Fixed.** An exercise serves exactly its type's `SkillFamilyMap` row (ADR 0073 Decision 4). A
  Picking drill serves all six picking skills and nothing else, so keeping *Sweep* and dropping
  *Alternate* in a goal changes nothing, and a Picking drill that is really a timing drill can never
  say so.
- **Closed.** A goal can name only the taxonomy's 32 skills (ADR 0015 S2, ADR 0073 §4, kept by ADR
  0171 D5). Practice the app never anticipated — live looping, say — can't be a goal, even though a
  Freeform block can already *be* that practice.

## Decision

### D1 — one rule for which skills a unit serves (slice 2)

`SkillAssociation` answers it, pure and Foundation-only.

- **Every exercise type has a default list**: its `SkillFamilyMap` row, retired types included.
  *Basic* and *Freeform* default to **empty**, which is today's behaviour.
- **Stored `skillIDs` empty ⇒ the type default. Non-empty ⇒ that list, and only that list.** It
  replaces the default rather than recording changes to it, so narrowing (drop *Alternate*) and
  expanding (add *Metronome timing*, or a custom skill) are one edit. Any taxonomy or custom skill is
  allowed on any type. Unknown and dangling ids are dropped on read, never a crash.
- An edited drill no longer picks up a later change to its type's defaults; *Use its type's skills*
  gets it back. Clearing every skill on a typed drill *is* that reset — an empty list means "the
  type default", so there is no stored "serves nothing" for a Picking drill. On Basic and Freeform,
  empty still means nothing, and a statement on a Freeform block follows ADR 0139 O6: declared, never
  inferred.
- **Warm-up** never serves skills (ADR 0072) and is already left out of the planner's projection.
- **Loop:** its stated `skillIDs` ∪ the skills of any recognised bucket tag. Old tags keep working,
  and **no value migration** copies them anywhere — ADR 0210's backfill was deleted on sight because
  it wrote things nobody chose.
- **Invariant:** with no `skillIDs` stored anywhere, the deriver's output is identical to what it was
  before this ADR. That is a test, not a hope.

### D2 — the schema (slice 2)

`Exercise.skillIDs: [String] = []` and `Loop.skillIDs: [String] = []` — plain string ids, never a
custom enum (ADR 0189 D4). On the wire, `ExerciseRecord.skillIDs`, `LoopRecord.skillIDs` and a
top-level `PracticeArchive.customSkills` are **Optional, and that is load-bearing**: a missing
non-Optional key fails the whole decode (the `ExerciseRecord.folders` precedent). Duplication carries
the list (shape, not provenance); a received routine carries its taxonomy skills.

### D3 — the planner reads the rule, not the map (slice 2)

`PracticePlanner.library` projects each unit's served skills through `SkillAssociation`, and
`CandidateDeriver` reads that set in both `techniqueCandidates` and `prereqMet` — so an expanded drill
also counts toward its new skill's prerequisite readiness. The deriver used to skip any id outside
the taxonomy; it now has a custom-skill branch (D7). `LongTermGoalEcho` inherits all of it, because it
re-derives.

### D4 — the goal editor says what each skill reaches (slice 1)

Under every skill in both goal editors: *"2 exercises · 1 loop"*, *"3 loops · the song itself"*, or
*"Nothing in your library yet"*. **Counts only, never "n of m"** — a count over a total is a score
(ADR 0171 D7, ADR 0070).

`GoalReach` derives **one skill at a time through `CandidateDeriver`**, the `LongTermGoalEcho`
precedent. A hand-rolled walk would be a lookalike that forgets routes — ear-mode loops, backing
tracks, tagged loops — and drifts from what Generate actually does. Deriving one skill at a time
matters too: the deriver keeps only the strongest claim on a unit, so deriving the whole goal at once
would credit a shared drill to one skill and report the other as empty.

A kept skill that reaches nothing offers **one fix**, chosen by `SkillAssociation.fix(for:)`:

| Route | Offered as | When |
|---|---|---|
| Make an exercise | *New Chords exercise* — opens the create sheet on that type | a creatable type serves it by default |
| Run a loop | a line of text | ear skills (*Train your ear*), improvisation (*Improvise*) |
| Target song | a line pointing at the section below | repertoire skills |
| Write your own practice | *Write your own practice for it* — opens the create sheet on a Freeform exercise (*Your own practice* to the player) that already states the skill | every other skill: the ones only a retired type serves (Note names, Intervals, Syncopation, Songwriting), the ones no type serves (Bends, Vibrato), and every custom skill |

The type offered is the creatable one whose family-map row lists the skill **earliest**, ties broken
by create-menu order — so *Clean chord changes* offers Chords, where it leads the row, rather than
Strumming, where it follows strumming itself. Slice 1 shipped two rows the freeform row replaced: *Tag
a loop* for a skill only a retired type serves, and *Nothing you can make works on this yet* for
Bends and Vibrato.

### D5 — every skill has an ⓘ (slice 1)

`SkillExplainer` holds one sentence per taxonomy skill, in our own words (the provenance note in
`docs/practice-techniques.md`), saying what the skill *is* and never how well anyone does it. The rest
of the text is **derived** from the planner's own tables — *"Worked on by Picking and Arpeggios
exercises, and loops tagged Picking or Arpeggios"*, *"Comes after Economy picking"* — so the ⓘ cannot
describe a route the planner doesn't take. A custom skill's ⓘ shows the player's own description
(slice 2).

It appears on goal-editor skill rows, skill-picker rows and both Works on sections, as
`InfoPopoverButton` — the popover half of `FieldInfoLabel`. **The ⓘ and the row's toggle are
siblings, never nested**: a button in a button's label fires both, so reading about a skill would
also add it.

### D6 — the link is visible from the material's side (slice 1 shows, slice 2 edits)

- **Exercise ⓘ sheet — Works on**, above Template. Slice 1 listed the type's skills with their ⓘ,
  and the Template footer says the type *"decides the skills it works on"*. Slice 2 makes it
  editable: **Add skills** or **Change skills** opens the picker over the whole catalogue plus the
  player's own, the type's skills pre-kept and badged *From its type*. The footer reads *From its
  type, Picking* until the list is edited and *Set by you* after, and **Use its type’s skills**
  resets it. Slice 1 left the section off Basic and Freeform, where it could only be empty and
  unchangeable; now that it can be changed it shows on every type but Warm-up, because those two are
  exactly the drills that need to say.
- **Loop editor — Works on**, directly above Tags. It lists the skills the loop states, then the ones
  a recognised tag carries, captioned *From your tag Picking*. **Add skills** edits the stated ones
  only — a tag's skills are the tag's, and go when it does. It reads the loop's *local* copy, so an
  edit shows before Done and Cancel takes it back. The ✨ skill-bucket chip row under Tags is gone;
  the descriptive tag suggestions stay.

### D7 — custom skills, with the player's own description (slice 2)

This lifts the free-text ban in ADR 0015 S2 and ADR 0073 §4, which ADR 0171 D5 kept. That ban had
one reason: *an orphan skill schedules nothing*. D4 makes an orphan **visible** and gives it a
**fix**, so the reason no longer holds.

- **A real row**, because a description needs somewhere to live: `@Model CustomSkill { uid, name,
  info, dateAdded }`, no relationships. Goals and units reference it as `custom:<uid>` inside the
  `skillIDs` they already have, so a rename changes one row and no references. Names are unique
  case-insensitively, through `Labels.canonical`.
- **Created in the shared picker** — **New skill** at the top of *Your own*, or *Create “Live
  looping”* for a search nothing matches — then a form with a name and **What it is**, everywhere
  the picker opens. A skill made there is kept straight away.
- **Managed where it's picked**, under *Your own*: *Edit* and *Delete* as swipe actions. Delete states
  what it's used by, as a count, and strips the id from those goals and units in the same save.
  Present the edit form by `uid`, never `.sheet(item:)` on the model (ADR 0090).
- **Planner:** resolves to every unit that states it; no prerequisites, no down-weight.
- **Backup vs sharing:** the archive carries every `CustomSkill`, and restore folds onto an existing
  one of the same name. A **shared routine drops custom ids** — someone else's vocabulary shouldn't
  create skills in your catalogue — and a drill left empty falls back to its type default.
- Names and descriptions are player text, so they never enter analytics. No event is added.

**Out of scope:** new taxonomy rows, changes to `SkillFamilyMap`'s defaults, new goal fields, any
Oracle code, merging two custom skills (backlog), and custom skills with prerequisites or a mode.

## What building slice 1 settled

- **The family map's order is not an order.** `SkillFamilyMap.skillsByTemplate` is a `Dictionary`,
  and `templates(forSkill:)` reads its iteration order, so anything shown from it would reshuffle
  between launches. Every list on screen is ordered by `ExerciseTemplate.displayOrder` or the
  taxonomy instead.
- **A route list needs a serial comma.** *"Worked on by Picking and Arpeggios exercises and loops
  tagged…"* read as one list; the routes are joined with *", and"*.
- **The fix enum has no `none` case.** A case by that name is one `Optional` comparison away from
  meaning something else; it is `.nothing`.
- **`FieldInfoLabel` was not refactored onto `InfoPopoverButton`.** The new button gives the glyph a
  32-point target, and moving that into `FieldInfoLabel` would shift pixels in every manual figure
  that shows a Mastery or Command tempo label — a figure going stale under a change nobody would
  connect to it.
- **The goal row's accessibility label stays the skill's name**, and the reach line is its *value*, so
  VoiceOver and every UI test find a row by the same words as before.

## What building slice 2 settled

- **A typed drill's picker cannot close empty.** Empty means *the type's default*, so closing the
  Works on picker with nothing kept would silently put back every skill just dropped. For a type
  with defaults, **Done** stays unavailable until one is kept (`requiresOne`) and swiping the sheet
  away is disabled with it; going back to the type is its own button.
- **The fix enum has four cases.** *Tag a loop* and `.nothing` both became `.makeFreeform`: a Freeform
  block stating the skill is a route every skill has, so *nothing you can make works on this* stopped
  being true, and a tag naming a retired type was always a worse route than stating the skill.
- **One vocabulary for names and ⓘ text.** `SkillVocabulary` turns any id into a name and an
  explanation, custom skills included; every row goes through it, and an id that names nothing
  reads *Unknown skill*, never `custom:…`.
- **The planner lets any well-formed custom id through.** `PracticePlanner.library` has no
  custom-skill fetch, so `SkillAssociation.resolvable` with no set of known ids accepts anything
  custom-shaped. A dangling one pulls only units that still state it, and delete strips it from those
  in the same save. Screens pass the set, and drop it.
- **Both ends of a share drop custom ids.** The sender strips them so a skill's uid never leaves the
  device inside a shared routine; the receiver strips them too, for a file another build wrote.
- **Restore lands custom skills first**, before any drill, loop or goal that names one. A same-named
  skill folds onto the existing row and the restore resolver remaps every id that named it; a uid
  already in the store maps onto itself and is not rebuilt. They are left out of the restore's row
  count, which counts things the player practises.
- **`Exercise.swift` was at its 400-line cap.** `kind` moved to `Exercise+Template.swift` to make room
  for the field and its doc comment.
- **Rows are built in functions.** Both Works on sections and the custom-skill form keep their
  modifier chains out of the `Section` builder, where one such chain once segfaulted the routine
  editor.
- **The fix says the template's name, not the code's.** It was first built as *Write a freeform block
  for it*; a screenshot showed it opening a sheet whose template reads *Your own practice*, which
  is what the manual and every other screen call it. "Freeform" is the case name, and a button was
  the only place a player would have met it. It is *Write your own practice for it*.
- **The create sheet says what the drill will work on.** The same screenshot showed the fix opening
  a form with no trace of the skill it was tapped under — the ids ride on the plan, invisibly. The
  configure step now shows a **Works on** section whenever the new drill arrives stating skills,
  and only then.

## Consequences

- A goal now says what it will schedule before Generate is pressed, one skill at a time, and a dead
  skill says so where it's chosen rather than where its absence is felt.
- Six skills had no route a player could take by making a drill — *Note names*, *Intervals*,
  *Syncopation*, *Bends*, *Vibrato* and *Songwriting*. Slice 1 named the honest route for each (a
  loop tag for four of them, none at all for two); slice 2 gives every one a Freeform route, and
  that is now the fix the goal editor offers.
- Two custom skills cannot be merged. A player with near-duplicates deletes one, and re-marks what it
  was on (backlog).
- The goal editor's figure (`sessions/goal-editor`) changes, and is re-shot.
- The Oracle's clarifier, when it comes back, has a form to pre-fill and a fallback that already
  works — ADR 0092 §A2 satisfied before its stage starts.

## Alternatives considered

- **Build the Oracle's clarifier now.** Rejected: it needs the S2 backend first, and its restatement
  line meets the register problem ADR 0211 shelved the Oracle for. A sharper goal would also have
  changed nothing against type-only matching — the planner could not act on it.
- **Show the links, change nothing.** Rejected: trimming skills inside one type would stay theatre,
  and a drill could never say what it is really for.
- **Narrow only.** Rejected: a drill is often for something its type doesn't name. Replacing the
  default outright makes narrowing and expanding the same edit, at the cost of an edited drill no
  longer following its type's defaults — which the reset answers.
- **Record changes to the default (added + removed) instead of replacing it.** Rejected: two fields,
  and a rule for what a removal means when the default later changes, to preserve a behaviour no
  player would notice.
- **A custom skill's id carries its name (`own:Live looping`), no model.** Rejected once a description
  was wanted: the description needs a row, and a name-bearing id makes every rename a rewrite of
  every reference.
- **Free-text skills on goals alone.** Rejected: every one would be an orphan. Custom skills land with
  the place to state them.
