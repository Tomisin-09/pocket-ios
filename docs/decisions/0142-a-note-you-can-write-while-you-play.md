# 0142 — A note you can write while you play

- **Status:** Accepted — built 2026-08-05 (`pocket-231-journal-reach`), v2 close-out Slice 3.
- **Date:** 2026-08-05
- **Builds on:** ADR 0038 (the practice journal — dated entries, immutable snapshots), ADR 0058 (one
  owner-aware write path; a journal belongs to a *unit*), ADR 0088 (writing a loop's journal no longer
  needs a run), ADR 0100 (the Journal space — one aggregated, read-only timeline, and the `EntryKind`
  tag vocabulary), ADR 0104 / 0135 (the inline note field on the two ramp-less loop modes), ADR 0136
  (the freeform block), ADR 0090 (present by stable `uid`, never `persistentModelID`), ADR 0138
  (each loop mode gates on what it needs), ADR 0112 (free runs, Pro authors).
- **Reverses:** the implicit rule in ADR 0038/0058 that journal capture is a **post-run, standalone**
  surface. Nothing wrote that rule down; the gate in the run screens enforced it anyway.

## Context

A weekend device pass produced two notes about the journal, and they turned out to be one problem
seen from both ends.

**N4 — there was nowhere to write during practice.** The journal is reached from
`PracticeReviewBar`, and on both run screens that bar is gated `!isRunning && routineContext == nil`.
Read plainly: you can write a note *before* you start, alone. Not while the ramp is climbing, not
while the loop is looping, and — this is the half that matters — **not anywhere inside a routine**,
which is where most practice actually happens. The moment a journal exists to capture is the moment
something happens on the instrument, and the app's answer was to stop the run first.

**N7 — the Journal space names the unit and can't take you to it.** Every item on the aggregated feed
renders an owner caption from `JournalTimeline.ownerLabel` — "Little Wing · Verse riff", "Spider ·
exercise". It has always been dead text. A reflective timeline whose whole job is looking back
couldn't get you to the thing you were looking back at.

Neither is a layout problem, which is why they hadn't been fixed by moving something. The capture
half is a *reachability* rule, and the caption half is a *missing destination*.

Two things already existed and pointed the way. `LoopModeNoteSection` — the inline field on ear
training and improvise (ADR 0104 / 0135) — has been the right shape since it shipped: a field, a
Save, a quiet receipt, no history. It was hard-wired to a `Loop` only because those were its two
hosts. And `JournalWriter.add(to:text:kind:into:)` (ADR 0058) is already the single owner-aware write
path, so nothing new has to learn what a snapshot is.

## Decision

- **J1 — Capture is reachable from every run surface, in every state.** While running, while stopped,
  standalone, and inside a routine. The rule the gate encoded — *reflection happens after* — is
  wrong about how practice works: the note is owed at the moment, and by the Done screen the sentence
  has already changed.

- **J2 — A compact sheet, not the full journal.** `QuickJournalSheet` is one field, the kind chips,
  and Save, on a medium detent. `JournalSheet` stays exactly as it is and keeps its job: browse, edit,
  delete, and the snapshot explainer. Presenting a browse-and-edit surface over a running drill would
  put the whole history, push-to-edit and swipe-to-delete in front of someone holding a guitar. Two
  surfaces, two verbs — **write** in the nav bar (`square.and.pencil`), **read** in the review bar
  (the 📕 *Journal* pill with its count).

- **J2a — Same write path, same vocabulary.** The sheet calls `JournalWriter.add`, so the owner-aware
  snapshot logic is untouched: an exercise note carries an absolute BPM, a loop note carries mastery
  plus a percent, and neither can cross (ADR 0058). Its tag row is `EntryKindChipRow`, extracted from
  `RoutineBlockDoneView` rather than copied — a note tagged 🧗 mid-run and one tagged 🧗 on the Done
  screen are the same thing on the same timeline, and two copies of a chip vocabulary drift apart one
  small fix at a time.

- **J3 — Opening it does not touch the transport.** No pause, no duck, no stop. `LoopRunView` already
  carries the inverse precedent (`pauseForNestedAudio`, for a nested engine that *would* collide);
  this is the case where nothing should pause, and it is stated here so a later "tidy-up" doesn't add
  one. A note that costs you the drill is a note you won't write.

- **J4 — Inline where there is genuine room; the sheet everywhere.** `LoopModeNoteSection` becomes
  `JournalNoteComposer`, taking a **`JournalOwner`** instead of a `Loop` and rendering as either a
  `Form` section or a standalone card. It stays on ear and improvise, and joins the **freeform block**
  (prose and a clock — the most room on any run screen, and the practice most likely to produce
  something worth writing) and the **loop trainer's running readout** (one number, a caption and a
  staircase). It deliberately does **not** join the exercise run's running screen: a fretboard board
  or a chord grid has no space, and a field squeezed under one would be worse than the nav-bar sheet
  those screens get instead.

- **J5 — The owner caption is a link, and it leads to the unit's ordinary run screen.** No bespoke
  "journal detail" surface: a note is *about* a unit, and the unit already has a home. An exercise
  goes through `ExerciseRunScreen`, which routes a freeform block onward (ADR 0136).

- **J5a — A loop is not one screen, so the caption opens the mode the loop qualifies for.**
  Precedence is `LoopModeAccess`'s own order — trainer, then ear, then improvise — because an
  unmeasured loop has no staircase to open, and sending a caption there is exactly the mistake ADR
  0138 had to unpick. Where **no** mode qualifies (a loop whose audio no longer resolves) and for a
  **song**-owned take (songs never got a standalone run surface, ADR 0069) the caption stays plain
  text. An affordance that can't keep its promise is worse than no affordance.

- **J5b — Routes are identified by the unit's stable `uid`.** `JournalOwnerRoute` is `Hashable` on
  `uid` alone, never `persistentModelID` — a destination keyed on the latter pops itself when
  SwiftData flips a temporary id to a permanent one (ADR 0090, `docs/swiftdata-gotchas.md`).

- **J5c — The link honours the paywall.** A locked Pro drill opens the paywall, not its run screen —
  the same `AccessPolicy.canRun` gate `ExerciseLibraryView`'s rows apply. A player who wrote notes
  while subscribed keeps the notes when the subscription lapses, and the notes must not become a way
  around the gate (ADR 0112).

- **J6 — Still no store change.** Everything here writes `JournalEntry` exactly as it is. The
  session-level entry, which *does* touch the model, is ADR 0143's problem.

## Consequences

- The journal stops being a post-run surface and becomes a practice surface. That is the point, and
  it is also the risk: notes will now be written mid-run, in a hurry, and some of them will be
  fragments. That is the correct trade — a fragment written at the moment beats a paragraph that
  never got written.
- Routine practice gains a journal for the first time. Entries written inside a routine still belong
  to the **block's unit**, not to the session; the compact sheet names the unit it will write to for
  exactly that reason. Session-level entries are ADR 0143.
- Two composers now exist (`JournalNoteComposer` for the inline field, `QuickJournalSheet` for the
  modal). They share the write path and the tag row but not their chrome, and that is deliberate: one
  is a section on a screen you are already reading, the other is an aside over a screen you are not.
- The Journal space becomes navigable, which makes it a plausible *entry point* to practice rather
  than only an archive. No screen advertises it that way yet.

## Alternatives considered

- **Inline capture only, everywhere.** Rejected: the fretboard, chord and strum drills have no room
  on their running screens, so the surfaces most in need of a note would have got nothing.
- **A floating capture button over the run.** Rejected: every run screen already owns its bottom
  inset for the transport, and a floating control there is a mis-tap next to Stop.
- **Reusing `JournalSheet` and letting it open mid-run.** Rejected in J2 — it is a browse-and-edit
  surface, and its history, push-to-edit and swipe-to-delete are all wrong to put in front of someone
  mid-drill.
- **A bespoke journal-entry detail screen for the caption to open.** Rejected in J5: it would be a
  second place to read one entry, and the honest destination is the unit itself.
- **Letting the caption always open the loop trainer.** Rejected in J5a — an unmeasured loop has
  nothing to anchor a ramp, and ear notes are written on exactly those loops (ADR 0138).
