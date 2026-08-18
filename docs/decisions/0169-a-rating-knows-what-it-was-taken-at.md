# ADR 0169 — a rating knows what it was taken at

- **Status:** Accepted
- **Date:** 2026-08-18 (`pocket-272-mastery-conditions`)
- **Relates to:** ADR 0036 (mastery and command tempo as separate fields), ADR 0039
  (optional-on-purpose — "unrated" is not zero), ADR 0070 (the app never grades the player,
  and never silently changes a number they set), ADR 0072 (gave `Exercise` a `mastery`),
  ADR 0015 S5 (`dueScore`), ADR 0121 (`commandNotesPerBeat` — a BPM without its note rate is
  half a fact), ADR 0038 (a journal snapshot is immutable), ADR 0134 (the offer moves both
  ways), ADR 0058 (the exercise journal snapshot)
- **Does not touch** the two-axes position. See *What this is not* below — that is the first
  thing to say, because the obvious version of this change is one the app has already refused
  in writing.

## What this is not

Mastery and command tempo are **deliberately two axes**, and this ADR leaves that exactly
where it found it. The position is stated in three places already:
`PracticeFieldInfo.commandTempo` ("Command is speed; Mastery is cleanliness — deliberately
two axes"), the FAQ answer that interpolates it, and `docs/manual/terms.md`: *"a loop can sit
at a high command tempo and a low mastery … it is the reason the app refuses to average them
into a single score."*

That position is right. Nothing here derives one axis from the other, averages them, or
weakens "high command, low mastery" as a thing you can express. **The gap is not that mastery
should be derived from command tempo. It is that a mastery rating does not record which
command tempo it was taken at.** A stamped reading *dates* an assessment; it does not collapse
the axes.

## Context

### The mechanical consequence: a successful raise retired the drill

Trace one raise through `commitDone` (`RoutinePlayerView+Done.swift`):

1. Run at command 70. The player taps mastery **5** on the Done screen.
2. `CommandOffer.preferredStance` reads 5 → `.raise`; the offer opens at the reach, 90.
3. The player accepts. `exercise.mastery = 5` **and** `promoteCommand(to: 90)` — in that
   order, in one commit.
4. `DueScore.masteryTerm(5)` returns `0`, zeroing the whole product → the drill **sinks to the
   bottom of the ranking.**

**Precisely how far it sinks, because "retired" overstates it.** `SessionBuilder.ranked` filters
on `priority > 0`, not on score, so a 0-scoring candidate is *ordered last*, not excluded. It is
still dealt when the pool runs shorter than the session's slots — which means the effect is total
in a well-stocked library and only partial in a small one. And because the score is a **product**,
`masteryTerm(5) == 0` zeroes it however due it becomes, so unlike a 1–4 no amount of elapsed time
brings it back. The `warmUpPick` LRU ignores mastery altogether, so a `.warmup`-template drill is
unaffected either way.

The rating that earned the raise was the same rating that retired the drill — at a tempo it
had never been rated at, and which by definition had not yet been played cleanly, because it
was the *reach* seconds earlier. ADR 0072 is explicit that mastery 5 retires an item "until
the player themself lowers the rating", so this was silent and sticky: the drill fell behind
everything else in the ranking, and the player's own successful promote is what did it.

`promoteCommand` could not fix this at the model layer. It writes `commandTempo` and
`commandNotesPerBeat` and has no way to reason about mastery, **because mastery did not know
what tempo it described.**

The **settle** direction was already coherent, by luck rather than design: `preferredStance`
only leans `.settle` on mastery 0–2, whose terms are already comfortably positive. The bug
bit upward only. That asymmetry is worth recording, because it is why the bug survived a
well-tested `CommandOffer` and a well-tested `DueScore` — every value in isolation was
correct, and only their *order* was wrong.

### The repo had already stated the principle three times

1. **ADR 0121, inside `promoteCommand` itself:** *"Bind the achievement to the rhythm it was
   just measured in… a BPM without its note rate is only half a fact."* That is
   `commandNotesPerBeat`. A mastery rating without its tempo is half a fact by the same
   argument.
2. **`RhythmChange`** gives the doctrine for when measurement conditions move: *"silently
   leaving 80 in place revalues that achievement with no event marking it; silently rescaling
   it rewrites it without asking."* A promote did the first of those to mastery.
3. **`JournalEntry` already refuses to store one without the other.** A loop entry snapshots
   `masteryAtEntry` **and** `commandTempoAtEntry` together, *"so the entry stays a truthful
   record of where things stood even as the owner keeps moving."* The journal *about* a unit
   was stricter than the unit.

## Decision

### D1 — stamp the reading, in the sibling position `commandNotesPerBeat` occupies

Three additive optionals:

| Field | Unit | Why |
|---|---|---|
| `Exercise.masteryTempo: Int?` | absolute BPM | the command the rating describes |
| `Exercise.masteryNotesPerBeat: Int?` | notes per beat | 90 at eighths and 90 at sixteenths are not the same claim (ADR 0121) |
| `Loop.masteryAtSpeed: Double?` | `×` of original | the loop mirror; no rhythm term, because a fraction of the recording's own tempo carries the material's rhythm with it |

**Freeze-safe.** Additive optionals are permitted under the schema freeze, and optional is
exempt from the CoreData 134110 mandatory-attribute rule, so existing rows migrate to `nil`
with no store wipe.

### D2 — one write path per model, on the model

`Exercise.rateMastery(_:)` and `Loop.rateMastery(_:)` set the rating and stamp the conditions
together. On the model rather than at a call site for exactly the reason `promoteCommand` is:
five surfaces rate a unit today, and a stamp that each of them has to remember is a stamp a
sixth surface will forget. Clearing the rating clears the stamp — conditions with nothing to
condition are noise, and leaving them would let a later re-rate inherit an unrelated tempo.

**The ordering at each call site is a decision, not an accident**, and it goes two ways:

- **The run/Done screens stamp before the revision.** The rating is about the run that just
  happened; an accepted raise then moves the command off it. That gap *is* the staleness. On
  the standalone exercise screen this works because `commitAndStart` has already persisted the
  run's command, so the model holds the tempo actually played.
- **The loop editor stamps after the command.** `writeEdits` commits one coherent declaration
  — "I own this at 85%, and I rate it 4" — so the rating is about the command being set in the
  same breath. Stamping the value it is *replacing* would invent staleness out of an edit.
- **`LoopEditSnapshot.restore` writes the stamp verbatim, not through `rateMastery`.** It is an
  undo. Re-stamping there would silently re-date a rating whose edit the player is discarding.

### D3 — staleness, not wiping

When the command (or, for an exercise, the rhythm) has moved off the stamp, the reading is
**stale**: shown as stale, kept, never silently rewritten. This is `RhythmChange`'s doctrine
applied to the rating instead of the tempo, and it is what keeps ADR 0070 intact — the app
marks that conditions changed; it does not change the player's number.

**An unstamped rating is not stale.** Every rating already in the store has no stamp, and
reading "unknown conditions" as "moved conditions" would demote the entire library on first
launch after the update. Unknown is not moved.

### D4 — a stale reading floors at `masteryTerm(4)`; it never zeroes the score

`DueScore.masteryTerm` gains an `isStale` parameter and a floor, `staleMasteryFloor`. The
floor is not a new constant: it is *exactly the term a mastery 4 earns*, which reads as **a
rating whose conditions have moved is worth no more to the planner than a 4 is.** It bites
only at `5`, the one rating whose term is `0` and which therefore zeroes the whole product. A
promote now **resurfaces** the drill instead of retiring it.

It is written as `1.0 - 4.0 / 5.0` rather than the arithmetically equal `1.0 / 5.0`, so it is
bit-identical to `masteryTerm(4)`. The two forms differ in the last place of a `Double`, which
is enough to rank a stale 5 a hair *above* a fresh 4 — an inversion of the axis. The test that
asserts it cannot happen is what found it.

`isStale` is an explicit input rather than a redefinition of the term, so **the existing
`5 → 0` assertions in `DueScoreTests` and the `CommandOffer` suites all still hold** — they
describe a *fresh* 5, which still retires. Nothing had to be swept.

### D5 — the reading shows on read-back surfaces only

"Rated at 90 BPM · 8ths", captioned under the mastery row on the exercise detail's Progress
section and the loop edit sheet; stale reads "— command has moved since", a fact about the
command rather than a verdict on the rating. The caption carries the rating it describes
(`MasteryReading.Display.rating`) and is hidden while an editor's dots have been walked
somewhere else, so a caption can never sit under a number it is not about.

**The Done screen shows nothing new.** It is a commit beat, not a read-back, and putting the
stamp there would rewrite `exercises.md` and `routines.md` and force both completion-screen
shots to be re-taken for no gain the detail sheet does not already give.

### D6 — `PracticeFieldInfo.mastery` gains the condition

It is the app's single definition of mastery, quoted verbatim by the ⓘ popover, the FAQ
answer, and `docs/manual/terms.md` (enforced byte-for-byte by `check-manual.py` C5). A rating
that now carries a tempo has to be said there. The independence sentence is untouched, so
nothing in the FAQ or in `terms.md`'s two-axes paragraph becomes wrong. **The
`terms/mastery-info` shot is that popover and must be re-taken** when manual Phase 5 resumes.

### D7 — the exercise journal entry keeps its rating

`JournalEntry.forExercise` passed `masteryAtEntry: nil`, and the field comment said why:
*"Exercises have no mastery."* That was true under ADR 0058 and stopped being true on
2026-07-08 when **ADR 0072 gave `Exercise` a `mastery`**; the comment was never revisited, so
for four months an exercise entry snapshotted its command BPM and its rhythm and silently
dropped the rating, while a loop entry kept both. Fixed: `forExercise` takes
`masteryAtEntry`, and `JournalOwner` passes it.

**Old entries are not back-filled.** The snapshot is immutable (ADR 0038), and inventing
today's rating for a note written months ago would be the exact defaulted-semantics lie ADR
0039 removed. The entry-detail sheet therefore gates the exercise Mastery row on the value
being present: `MasteryReadout` renders `nil` as "Unrated", which is a claim about the player,
where the truth is "unrecorded".

### D8 — `MasteryRollup` stays as it is

`rollup` averages a loop rated 5 at 60% with one rated 3 at 100% and returns 4, which
compares two readings taken under different conditions. Stamping does not fix that by itself,
and the same objection applies to `PracticeLibrarySort.mastery` and `SongCard.accentColor`,
which both rank a 5-at-half-speed above a 3-at-full.

It stays. The song rollup is a **coarse library-sort signal**, documented as derived, and it
drives no scheduling — the planner reads per-unit ratings, never the rollup. Making it
condition-aware means choosing a normalisation, which is a way of averaging the axes together
through the back door, and `terms.md` already tells the player the way to move a song's
mastery is to rate the loops underneath it. Recorded here so the next person to notice it
finds a decision rather than an oversight.

## Alternative considered and rejected

**Redefine mastery as "at command" and clear it on every promote.** More coherent on paper: a
rating would always describe today's tempo. Rejected because it destroys existing ratings —
destructive under the schema freeze in spirit if not in letter — and puts a mandatory re-rate
in front of every raise, taxing the player for making progress. **Stale beats empty.**

## Consequences

- A drill promoted on a 5 ranks as a 4 rather than a 0, so it competes for a slot again instead
  of sitting at the bottom of the pool. Players who hit this already have drills sunk that way;
  those ratings carry no stamp, so they stay sunk until re-rated. Nothing back-fills them, for
  D3's reason.
- **This ADR does not reopen whether a *fresh* 5 should sink forever.** That is ADR 0072's
  decision — mastery is never auto-decayed (ADR 0070), so only the player lowering the rating
  brings such a drill back. 0169 changes only the case where the command moved out from under
  the rating.
- One new `@Model` field on `Loop` and two on `Exercise`, all additive optionals.
- `PlannerCandidate`, `PlannerExercise` and `PlannerLoop` each carry a defaulted
  `masteryIsStale`, so every existing construction site and test is unchanged.
- `Exercise.swift` was against the 400-line cap, so `markPracticed` and the two freeform gates
  moved to the new `Exercise+Mastery.swift` alongside the mastery accessors.
- Manual: `terms.md` gains the "rated at" fact; the `terms/mastery-info` shot must be
  re-taken. No other shot is affected (D5).

## Verification

The bug is a **sequence, not a state** — no assertion on `masteryTerm` alone can catch it,
because every value in isolation is correct. `MasteryConditionsTests` replays `commitDone`'s
order against the models (rate 5 → promote → project → score) and asserts the candidate still
scores above zero, with `testAFreshFiveStillRetires` as the guard against over-correcting.
Neutralising the floor makes that test fail at `0.0`, which is how it was confirmed to be
testing something.
