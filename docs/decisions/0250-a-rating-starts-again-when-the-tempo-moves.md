# ADR 0250 — A rating starts again when the tempo moves

- **Status:** Accepted — decided with Tomisin, 2026-10-03/04. Built on `pocket-360-manual-reshoot`
  in two slices: the reset (D1–D7), then the speed beside a song's dots (D8–D10).
- **Date:** 2026-10-04
- **Amends:** ADR 0169 — D3 (*staleness, not wiping*) no longer answers a command move: the move sets
  the rating aside (D1). Its rejected alternative, *clear it on every promote*, is adopted in a form
  that keeps the old rating. D5's caption gains *Last rated…* (D5). D8's rollup gains a speed line
  beside it (D8). The stamp, its fields and the stale floor all stand.
- **Amends:** ADR 0117 — a loop counts as *mastered* only at 5 **and** full speed (D10).
- **Relates to:** 0070 (the app never grades) · 0072 (a fresh 5 retires — unchanged) · 0039
  (unrated is not zero) · 0036 (two axes) · 0134 (the offer moves both ways) · 0121 (a tempo needs
  its rhythm) · 0058 (the journal snapshot)
- **Schema:** `Exercise.previousMastery: Int?` and `Loop.previousMastery: Int?` — additive optionals.

## Context

Tomisin, 2026-10-03: *"mastery … should be reset every time the command tempo is changed. The
general aim should be to increase the command tempo when the mastery is at 5 stars."*

That is a cycle: rate a drill up to 5, take the 5 as the cue to raise the command, rate again at the
new tempo. ADR 0169 had already stamped each rating with the tempo it was given at, and marked it
*stale* when the command moved, keeping the number. But the cycle broke one run later:

1. Rate 5 at 70 and accept the raise to 80. The rating is stale, which is correct.
2. On the next run at 80, the Done screen pre-fills the stored rating (`RoutineBlockDoneView`'s
   `initialMastery`). Five dots are lit at a tempo never rated. The revision offer, seeded from the
   same pre-fill, already leans toward *another* raise.
3. Tap Continue without touching the dots. `rateMastery(5)` runs anyway and re-stamps the 5 at 80.
   It is no longer stale, so `masteryTerm(5) == 0` retires the drill: the exact bug 0169 fixed.

The second gap was the song: *Mastery ★★★★★* for a song whose loops are all 5 at 60%. ADR 0169 D8
saw it and left it.

## Decision

### Slice 1 — the reset

**D1 — A command move sets the rating aside.** The unit reads **unrated** at its new tempo, and the
old rating moves to `previousMastery`. The existing stamp (`masteryTempo` / `masteryNotesPerBeat` /
`masteryAtSpeed`) keeps describing it, so at most one of the two ratings is ever set. *Any* move
counts: a raise, a settle, an edit-sheet change, a re-measure. It is written in one place per model,
`moveCommand(to:)`, which `promoteCommand`, `settleCommand` and the loop editor all go through:

- **A stamped rating** is set aside when its stamp no longer matches the new command (`isStale`).
- **An unstamped one** (pre-0169) is set aside when the effective command actually changes.
- **Never on a write that lands where it already was.** `ExerciseRunView.persist` and
  `LoopRunView.persist` promote on every Save and Start, and a first promote turns a fallback into a
  measured command at the same value. A loop's run screen writes `speed` before it promotes, and an
  unmeasured loop's command falls back to `speed`. That is why a stamped rating is judged by its
  stamp rather than by a before/after compare.

`ratingWouldBeSetAside(movingTo:)` is the same rule asked ahead of the write, so a screen can show
what it is about to save.

**This is not ADR 0070's silent change.** The move is the player's own act, the new state is
visible (blank dots, *Last rated…*), and nothing is erased.

**D2 — Unrated, not a default number.** Tomisin's first idea was a default of 3. It is rejected for
four reasons:

- A 3 the app writes is a grade from the app (ADR 0070, ADR 0039).
- 3 is `CommandOffer`'s deliberate dead band, so the Done screen would show no offer at all.
- A placeholder 3 can never be told apart from a real one.
- `DueScore` treats unrated as most due (term 1.0), which is right for a tempo just moved to. A 3
  would rank it below drills never rated.

**D3 — An unchanged rating writes nothing; a new one supersedes the set-aside one.** `rateMastery`
returns early when the value equals the stored one. Every completion screen hands its row back on
Continue whether or not it was touched. Without the guard, a blank row after a move would wipe
`previousMastery`, and a pre-filled one would launder a rating to a new tempo. Nothing is lost: by
D1, a current rating is always at today's command.

**D4 — Keeping the note speed keeps the rating; re-measuring sets it aside.** `keepNoteSpeed`
restates the same notes at the same speed in new units, so a rating given at the command is still
true: its stamp is restated beside the command. `reMeasureCommand` clears the command, so nothing is
rated at the new rhythm, and the rating is set aside.

**D5 — *Last rated 5 at 70 BPM · 8ths*.** On the read-back surfaces: the exercise detail's Progress
section and the loop edit sheet. `MasteryReading.Display` gains `isPrevious` and
`describes(_:)`. A current reading captions its own number; a set-aside one captions the blank row
the move left. The loop editor previews a move still only on screen: the dots go blank with the
caption, and moving the slider back restores them, because nothing is written until Done. A rating
tapped in the same edit lands on top of the move and stands. **The Done screen gains nothing
visible** (0169 D5 holds): its pre-fill is simply blank after a move, so the offer opens neither
way. `CommandOffer.preferredStance`'s own doc already asked for that.

**D6 — The Done note records the run as played.** `commitDone` now writes the journal entry after
the rating and before the revision. Its snapshot is the rating just given and the tempo it was given
at, not an unrated row at the tempo the raise moved to. The standalone run screens already commit in
this order.

**D7 — Ratings already stale are set aside at launch.** `MasteryStaleBackfill` runs every launch,
beside `PieceDateBackfill` and for its reason: an archive restored from an older build can carry
the 0169 shape. It writes only to a stale rating, and unstamped ratings are left alone, since
unknown is not moved. The stale machinery stays as the fallback for anything that still arrives
moved-off: `masteryIsStale` (now `false` with no current rating), the `DueScore` floor and *command
has moved since*.

### Slice 2 — speed beside the dots

**D8 — A song shows its slowest loop beside its mastery.** Under the dots on the player's title
strip, *slowest 60%*, or *full speed* once the slowest measured loop is at 100% or above. It is the
speed you can play the whole song at, read off the loops (`SongSpeed`, pure), not a formula.
Unmeasured loops are skipped, as the rollup skips unrated ones, and backing-track loops are left out
because you play along to them, not practise them. **The two axes stay two** (ADR 0036): they sit
side by side and are never folded into one number.

**D9 — Song details say what the dots are made of.** The Mastery row adds *(2 of 3 loops rated)*,
and a new row names the slowest loop: *Slowest loop · Intro riff · 60%*.

**D10 — *Mastered* means 5 at full speed.** The Practice log's tile counts loops rated 5 whose
command is at 100% or above. Under D1 a 5 always means *at the current tempo*, so a 5 at 60% is
the cue to raise, not a loop finished.

## Alternatives rejected

- **Fold tempo into a loop's stars** ("5 stars at 90% is really a 4"). Tapping 5 and seeing 4 is
  the app overruling the player (ADR 0070). Every formula for it is arbitrary: why does 90% cost
  one star, and what does 50% cost? It would also destroy the 5's job as the cue to raise. Speed
  goes beside the song's dots instead (D8).
- **Keep 0169's staleness and only stop the Done screen pre-filling a stale rating.** That fixes the
  one screen, but the loop rows, the song rollup and the *Mastered* tile go on counting a 5 at a
  tempo nobody rated. One rule at the write beats a guard at every reader: there are about seven
  places the command is written and about forty that read mastery.

## Consequences

- A just-raised drill is **most due** to the planner, where 0169 floored it to rank like a 4. This is
  intended: the new tempo is the thing to work on. ADR 0072's *a fresh 5 retires* is not reopened.
  Rate 5 and decline the raise, and the drill still retires.
- A song's dots now average only ratings at each loop's current tempo. A loop you just raised drops
  out until you rate it, and the speed line carries what it no longer says.
- *Mastered* falls when a loop is raised, and rises only at 5 at full speed.
- The ⓘ definition of mastery (`PracticeFieldInfo.mastery`) and the song's (`songMastery`) change.
  The FAQ and `docs/manual/terms.md` quote both, so `terms/mastery-info` and every figure showing the
  title strip, the song details or the loop edit sheet's mastery row are re-shot in the pocket-360
  reshoot.
- Archives carry `previousMastery`. It is `Optional`, so an archive from before 0250 still decodes,
  and the receive door drops it with the rest of a stranger's practice.

## Verification

`MasterySetAsideTests` replays the sequence from the Context against the models:

- rate 5, raise, then Continue past an untouched row;
- `previousMastery` survives, the offer opens `.open`, and the drill scores above zero.

It also pins every rule in D1–D7, including:

- a write that lands where it was;
- an unstamped rating;
- a loop's tolerance and its unmeasured fallback;
- the backfill;
- the archive round trip, including an archive with no key.

`MasteryConditionsTests`' three move assertions are rewritten to the new behaviour.
