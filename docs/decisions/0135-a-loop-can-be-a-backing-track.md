# 0135 — A loop can be a backing track (improvise over your own music)

- **Status:** Accepted — **Slices 1 and 2 built and device-verified** 2026-08-02 (S1 on
  `pocket-220-backing-track-loops`, S2 on `pocket-223-improvise-block-and-lengths`, which supersedes
  it). Slice 3 (the planner) outstanding. See §Build notes for what landed, the one slice boundary that moved, and the question
  Slice 1 inherits rather than answers.
- **Date:** 2026-08-01
- **Builds on:** ADR 0104 (ear training as "loops, re-surfaced" — the mode-on-a-loop pattern this ADR
  copies almost verbatim), ADR 0070 (Pocket never grades the player), ADR 0094 (the no-grading line
  around theory/ear work), ADR 0001 (practice audio = DRM-free local/iCloud file playback), ADR 0119
  (`isFavorite` — the precedent for a typed, curation-only `Bool` on `Loop`), ADR 0074 (loop skill
  tags), ADR 0036 (`LoopType`), ADR 0100 / 0058 / 0038 (the Journal write path and typed `EntryKind`),
  ADR 0014 (`play` blocks are surfaced but unbudgeted), ADR 0015 / 0073 (goal-driven candidate
  selection, and the "Improvise in a style" intent).
- **Narrows:** the backlog's **"Backing tracks"** item, which framed this as a content-production
  question (outsource vs self-record 3–5 first-party tracks). This ADR answers it a different way for
  the first build: the player already owns backing tracks — they are sections of their own songs.
  First-party recorded content stays parked, not cancelled.

## Context

Looping a chord section of a song and playing over it is already a thing this app does; it just isn't
a thing the app *knows* it does. A loop set over the intro or outro of a song — a chord progression,
no vocal — stops being a passage to master and becomes a bed to solo over. Every mechanism that
requires is already shipped: the region loops gaplessly (`PracticeAudioEngine` folds a 15 ms
equal-power crossfade into the seam), the rate is adjustable live in percent-of-original, and notes
capture to the Journal.

What's missing is **classification and resurfacing**. A backing-suitable loop is buried among every
other loop of that song, indistinguishable from the four-bar lick the player is grinding at 60%. It
can't be found later, can't be run in a mode that suits it, and can't be reached by the planner.

ADR 0104 already solved this exact shape of problem for ear training, and its E5 already settled the
audio question this ADR would otherwise re-litigate: play the **real music**, not the Hear synth
(ADR 0097). A synthesised bed built from a `ChordProgression` was considered and rejected here for the
same reason, plus two of its own: the unloaded `AVAudioUnitSampler` tone is a pitch reference, not
something to solo over for five minutes, and `HearSequencer` schedules absolute deadlines off its own
queue, which is right for a one-shot audition and wrong for a continuous bed.

There is also a concrete hole in the planner. `improv.vocabulary` ("Soloing / improv vocabulary") is
classed `.repertoire` in `SkillTaxonomy`, so it resolves on **Path B** — and `repertoireCandidates`
opens with `guard let songUID = goal.targetSongUID else { return [] }`. The "Improvise in a style"
goal template sets `requiresTargetSong: false`. So today that goal's improv-specific skill contributes
**zero candidates**; the goal works only through its two scale skills, which surface Scales exercises.
Improvising has no unit in the library that can serve it. A backing loop is exactly that unit.

## Decision

- **B1 — A backing track is a *flag on a loop*, not a new unit type and not a new kind of material.**
  `Loop` gains `var isBackingTrack: Bool = false` — a plain `Bool` with a declaration default, so
  SwiftData lightweight migration fills pre-0135 loops with `false` (additive, no store wipe; the
  CoreData 134110 rule, ADR 0012). `isFavorite` (ADR 0119) is the precedent in every respect: typed,
  player-set, never derived, never a grade.

- **B1a — It is not `LoopType`, and it is not a tag.** `LoopType` answers *what material is this*
  (lick / riff / chords / passage) and is single-select; a backing-suitable section could be any of
  them, so folding it in would destroy that axis's meaning. `Loop.tags` (ADR 0034 / 0074) are open,
  descriptive, and canonicalised free text; this flag **drives a surface and a filter**, so it needs
  to be typed and exact-matchable rather than recognised from a string. The planner consequence of
  keeping it typed is handled in B6.

- **B2 — Improvise is a *mode* on that loop, launched from the loop edit sheet.** `LoopRunMode` gains
  a third case, `improvise`, alongside `trainer` and `ear`. A sibling row to "Train your ear" appears
  in `LoopEditSheet`'s Practice section — like ear training and unlike "Practice now", it is **not**
  gated on a command tempo, since jamming over a section needs only audio, not a measured target. The
  row appears on **every** loop; the flag governs *resurfacing*, not permission (B4).

- **B3 — The mode holds one tempo, adjustable live; it does not ramp.** Continuous playback of the
  loop's own audio at a fixed, player-chosen rate, with the same −/+ percent-of-original adjuster ear
  training ships (`LoopRunModel.setAuditionPercent`, 25–150% in 5% steps, live while cycling). No
  ramp, no rep clock, no staircase: this is an open jam, and the app never tells you to stop playing
  (ADR 0014 R1). This follows ADR 0071's rule for a song block, not the loop trainer's.

- **B3a — Capture reuses the Journal, exactly as ADR 0104 E3 does.** Notes written during or after a
  jam go through `JournalWriter.add(to: .loop(loop), …)` (ADR 0058) and land on the loop's journal and
  the cross-cutting timeline. No new note store, no bespoke scratch field. A new
  `EntryKind.improvise` (🎸 "Improv") tags them so they're filterable like every other kind — added
  the established safe way, a new case on the `String`-raw enum with a computed glyph/label, never a
  raw enum attribute on the `@Model`. Unknown raws still fold to `.note`, so no migration.

- **B3b — The run ends when the player says so, and that counts (ADR 0104's shape).** A jam has no
  ramp and no natural end, so — exactly as `EarLoopRunView` does — the clock starts on appearance
  rather than on a transport action, and an explicit **Done** is treated as a *genuine completion*,
  not a hand-stop: the player deciding they're finished **is** the end of the run. Skip and exit log
  nothing. It writes a `PracticeRunKind.improvise` row (a new case beside `.earLoop`, on the same
  reasoning — the same material doing a different job, so it earns minutes and days without muddying
  a loop's tempo trajectory) with **no tempo**: a jam isn't practised *at* a tempo you own, and the
  live percent is a comfort setting, not an achievement. Like an ear block and unlike a trainer
  block, it shows **no `RoutineBlockDoneView`** — there is nothing to grade or promote (B5).

- **B4 — The flag's job is a filtered collection.** The Loops library gains a backing-tracks filter
  beside the existing Favourites one, which across every song's loops gives the player a *jam over
  something* shelf the per-song browse can't. Implemented as an **in-memory** filter on the fetched
  loops, matching `favoritesOnly` — deliberately not a SwiftData `#Predicate`, which starves the main
  thread on optional comparisons (`docs/swiftdata-gotchas.md`).

- **B4a — Setting the flag carries guidance, not a check.** The toggle's caption says what makes a
  good bed — roughly *"Works best over a whole number of bars, with no vocal."* It is **advice**: the
  app verifies nothing, and the copy must not imply it does. Note the guidance is deliberately
  *musical*, not technical — the audio seam already crossfades, so there is no click to warn about;
  what ruins a bed is a phrase that lands mid-bar or resolves where the next repeat can't follow.

- **B5 — Nothing listens, and nothing is scored (ADR 0070 / 0094 T3).** The mode plays *to* the
  player. No mic, no analysis, no transmission, no verdict on what was played over it — the same
  posture ADR 0104 E6 holds for ear training, and for the same reason. Any progress ever shown is
  exposure-based (minutes jammed, loops jammed over), never performance-based.

- **B6 — The flag feeds the planner, and it is what makes the "Improvise in a style" goal resolvable.**
  A backing loop is a candidate for `improv.vocabulary` **without requiring a tag**: `PlannerLoop`
  carries `isBackingTrack`, and the deriver resolves that skill to the library's backing loops when
  the goal names no target song. Path B's existing behaviour is untouched where it already works — a
  goal that *does* name a target song still resolves to that song's own loops first. This is the
  narrowest change that closes the hole in Context, and it is only defensible because the flag is
  typed (B1a): a free-text tag would have made "which loops can I improvise over" a string match.

- **B6a — A backing loop plans as a `play` block, never `focused`.** `RoutineItemKind.play` is
  precisely this: a full run-through / jam, surfaced but **unbudgeted** (ADR 0014 R1). A jam that
  counts against a focused time budget would be miscounted work, and would drag session sizing
  (ADR 0129) around by a block that has no defined length. The planner's materialisation must also
  carry the run mode down to the block, so a planned backing loop opens in improvise mode rather than
  the trainer — `SessionBlock` does not carry a `LoopRunMode` today, and this is the one
  non-mechanical piece of the planner slice.

- **B7 — Free, like ear training.** Running a loop you already own in a different mode is *running*,
  not authoring, so it sits on the free side of ADR 0112's line. Nothing here is gated.

## Consequences

- **The build is small, because it is ADR 0104 again.** Net-new: one `Bool` on `Loop` (+ its
  `LoopEditSnapshot` staging field), one `LoopRunMode` case, one `EntryKind` case, one mode view with
  its two hosts (a sheet from the loop edit sheet, a run view inside the routine player), and one
  library filter. Every audio behaviour it needs — gapless region looping, live rate change, Journal
  capture — already ships.
- **The "Improvise in a style" goal starts producing candidates.** Today its improv skill silently
  yields none. That is a latent defect this ADR fixes as a side effect; it is worth noticing that it
  was invisible precisely because a goal with two working skills still looks like it works.
- **A second, small `Bool` axis lands on `Loop`.** `isFavorite` and `isBackingTrack` are different
  claims (*keep this close* vs *this suits jamming*) and must not be conflated, but a third such flag
  should prompt a rethink toward a typed set rather than a widening row of booleans.
- **The backlog's backing-track content item is narrowed, not resolved.** First-party recorded beds
  would still serve a player whose own library has no suitable section — a beginner with three loops,
  all of them licks. They ride the existing engine unchanged if ever built.
- **Design risk: the flag is a claim the app can't check.** A player who flags a loop that lands
  mid-bar gets a bad jam bed and no explanation. B4a's copy is the only mitigation, deliberately —
  bar-boundary detection is an analysis feature this app has no appetite for.
- **Scope risk: "it's a backing track" pulls toward a backing-track *library*.** Bundled beds,
  transposition, key detection, drum tracks. Each is a separate ADR; none is implied by this one.

## Alternatives considered

- **Synthesise a bed from a `ChordProgression` via the Hear engine (ADR 0097).** Rejected — it
  re-litigates ADR 0104 E5 and loses. The point is playing over *real music*; the sampler tone is a
  pitch reference, not a bed, and its off-main scheduler is built for one-shot auditions rather than a
  continuous groove locked to a clock. It would also require authoring a progression the player has
  already got, recorded, in the song.
- **Reuse `LoopType.chords` as the signal.** Rejected (B1a) — that axis answers what the material
  *is*, and backing-suitable sections are not all chord loops.
- **Reuse `Loop.tags` (a "Backing" tag) as the signal.** Rejected (B1a) — tags are descriptive free
  text recognised by string match; this drives a filter, a surface, and planner resolution, and wants
  to be exact. It would also collide with ADR 0074's tag vocabulary, which is explicitly the
  *skill-bucket* namespace.
- **Retype `improv.vocabulary` from `.repertoire` to `.loopDrill`.** Rejected for this slice — it
  would route the skill through Path A globally and change how *existing* song-targeted improv goals
  resolve, a wider blast radius than the hole being fixed. B6's narrower rule leaves working
  behaviour alone. Worth revisiting if backing loops become the dominant improv unit.
- **A dedicated "Improvise" exercise template with a synthesised progression and a scale overlay.**
  Rejected as the first build — heavier, and it invents content the player already owns. The scale
  overlay survives as a follow-up on *this* surface (below).
- **Let any loop be jammed with no flag at all (mode only, no classification).** Rejected — the mode
  alone is already possible by pressing play; the value the player asked for is *resurfacing*, and
  resurfacing needs a classification to resurface on.
- **First-party recorded backing tracks first.** Deferred (see Narrows) — a content-production and
  licensing commitment before a code one, and it doesn't use the player's own material.

## Slices

- **Slice 1 — the flag, the surface, the shelf.** `Loop.isBackingTrack` + its snapshot staging and the
  toggle with B4a's caption; `ImproviseSheet` hosted from the loop edit sheet (continuous playback,
  live percent, Journal note); `EntryKind.improvise`; the Loops-library filter. Independently useful:
  the player can flag sections and jam over them.
- **Slice 2 — the routine block. ✅ BUILT.** `ImproviseLoopRunView` inside the routine player,
  mirroring ADR 0104 Slice 2's wiring for `.ear`, plus B8's Improvise bucket (carried here from Slice
  1 — a bucket authors a block, so it needs the block). A backing loop becomes something a routine can
  end on. Built with **ADR 0141 Slice 1**, which gives it a length.
- **Slice 3 — the planner.** B6/B6a: `PlannerLoop.isBackingTrack`, the `improv.vocabulary` resolution,
  the `play`-kind placement, and carrying `LoopRunMode` through `SessionBlock` into the materialised
  `RoutineItem`. Closes the empty-goal hole.

## Amendment — access points, and the gate that would have hidden them (2026-08-01)

Where the mode is reached from, decided against the two screens rather than in the abstract. Both
follow ear training's placement exactly; the third item is a defect the placement exposed.

- **B8 — A fifth bucket in the add-to-routine sheet.** `AddRoutineUnitSheet` already carries "the four
  typed buckets (ADR 0104 Slice 2 adds Ear training)"; **Improvise** joins them as one more
  `bucketRow`. Note what its **count** says that Ear training's cannot: the Ear bucket shows every
  library loop, because any loop can be sung back; the Improvise bucket shows only flagged ones. The
  two counts diverging on screen is B1's distinction made visible, and is the cheapest possible
  explanation of what the flag is for.

- **B8a — A per-row button in the loops library, on flagged rows only.** `LoopLibraryView`'s rows
  carry a trailing **Ear** button; Improvise sits beside it — but **only when `isBackingTrack`**,
  unlike Ear which is on every row. The asymmetry is deliberate and is the same asymmetry as B8: the
  button's presence *is* the flag's payoff, and a row that isn't a backing track shouldn't offer an
  affordance that leads to a bad bed.

- **B9 — The measured-loop gate has to widen, or B8/B8a surface nothing.** Both screens filter on
  `commandTempo != nil` (`LoopLibraryView.visibleLoops`; `AddRoutineUnitSheet.trainableLoops`) —
  setting a command tempo is what promotes a loop into Practice → Loops at all. **A backing track has
  no command tempo and must not need one**: it is a bed, not a measured target, which is exactly why
  B2 ungates its launch from the edit sheet. Without this, a loop the player flags and never measures
  is invisible on both screens the flag exists to populate. The gate becomes
  `commandTempo != nil || isBackingTrack` in both places, and the "no measured loops yet" empty-state
  copy — which today instructs the player to set a command tempo — has to admit the second route in.

- **B9a — The same tension already exists for ear training, unresolved.** *(Resolved by ADR 0138,
  which recasts B9's widened gate as a per-mode precondition — same outcome for backing tracks,
  stated so it answers ear training too.)* ADR 0104 ungated the
  edit-sheet launch but its routine bucket kept `trainableLoops`, so an unmeasured loop cannot be
  added to a routine as an ear block either. Nobody hit it because ear training has no flag of its own
  to be overruled. Widening the gate per B9 does not fix ear training's case; whether ear training
  should also escape the measured gate is a separate question this ADR does not settle.

- **B10 — Known limitation on B6: loop dueness is inert.** *(Closed by ADR 0137, which derives
  dueness from the practice log rather than a stored field — the fix is planner-wide, so it was
  argued there rather than folded in here.)* `Loop` has no `lastPracticed` field, and
  `PracticePlanner.library` hard-codes `lastPracticed: nil` for every loop, which `DueScore.dueness`
  treats as **max-due**. So a backing loop resolved for the improv goal ranks on `goalWeight ×
  mastery` alone — the time-driven resurfacing half of the formula does nothing for any loop, not
  just these. Not caused by this ADR and not fixed by it. Worth naming because ADR 0117 now writes
  timestamped per-unit-run rows (`.loop`, `.earLoop`, and `.improvise` when it lands), so the data to
  make loop dueness real exists for the first time — nothing reads it back yet. Parked as its own
  decision.

## Build notes — Slice 1 (2026-08-02)

- **`LoopRunMode.improvise` landed here, not in Slice 2.** ADR 0138's `LoopModeAccess` switches over
  `LoopRunMode` with no `default`, so the third gate could not be stated without the third case. The
  enum case is Slice 1; the *routine block* it eventually tags is still Slice 2.

- **B8's Improvise bucket moved to Slice 2.** The amendment listed the `AddRoutineUnitSheet` bucket
  under Slice 1, but a bucket adds a **routine block** — which needs the pick case, the player's
  stage dispatch and `ImproviseLoopRunView`, i.e. all of Slice 2. Shipping the bucket first would have
  authored blocks that fall back to running the *trainer* against a loop with no command tempo. B8a's
  per-row button, which needs none of that, is built.

- **The shelf reads from every loop, not from the measured listing.** `LoopLibraryView`'s
  "Backing tracks only" filter replaces the trainer gate rather than composing with it. Composing
  would have hidden exactly the loops B9 exists to admit: a section flagged as a bed and never
  measured. Same argument as B9, one screen further in.

- **The improvise precondition is `isBackingTrack` *and* `audioResolves`**, not the flag alone. The
  flag is a claim about *suitability*; a claim over audio that won't resolve (no song, or an Apple
  Music catalog item — ADR 0001) leaves nothing to solo over.

- **The two ramp-less modes now share their sections.** `LoopModeSections` holds the identity header,
  `ContinuousLoopControls` and the Journal note capture; `EarTrainingView` and `ImproviseView` differ
  only in copy and the note's `EntryKind`. `EarTrainingPlayer` was renamed `ContinuousLoopPlayer` for
  the same reason — a shared engine named for one of its two callers is how the next reader concludes
  that improvising *is* ear training.

- **One behavioural difference between them, and it is deliberate:** improvise seeds its tempo from
  the loop's `armingSpeed` (command tempo, else **full** tempo — ADR 0089's rule) rather than ear
  training's `ramp.command`, which falls back to the loop's stored practice `speed`. A section drawn
  at 70% to pick a lick off it would otherwise open a jam at 70%; a bed's honest default is the tempo
  the record plays at.

- **The standalone `ImproviseSheet` writes no practice-log row.** B3b's logged run is the *routine
  block*, which Slice 2 builds. This inherits the shape standalone `EarTrainingSheet` already has —
  and with it the open question ADR 0117's device verification raised and ADR 0138 did not settle:
  whether an open-ended standalone mode should log at all. It is now **two** surfaces, not one, which
  is the argument for deciding it rather than a reason to decide it here.

## Parked follow-ups (not sliced)

- **A scale/box overlay on the improvise surface**, driven by `Song.key` and the scale catalog —
  "here's the A-minor pentatonic box over this section." The differentiator a backing-track video
  can't match, but it needs a key that is often unset, and it is not needed to jam.
- **Bulk-setting the flag** from the loops multi-select bar (ADR 0125 / `LoopBulkEdit`), if flagging
  turns out to happen in batches.
- **Exposure surfacing** — "loops you've jammed over" on the Progress screen (ADR 0117), strictly
  exposure-based per B5.
- **First-party recorded beds** — the original backlog item, unchanged.
