# V2 close-out plan — weekend device notes + ADR 0132

**Branch:** `pocket-228-v2-closeout` (planning only; each slice below gets its own branch)
**Date:** 2026-08-04
**Scope rule:** these eleven items are v2. Anything found outside them goes to `docs/backlog.md`
under a **v3** heading, not into a slice here.

Source: a weekend device pass (three annotated boards, 10 notes) plus **ADR 0132 — the click
withdraws itself**, which has been Proposed and unbuilt since 2026-07-31.

---

## 1. Triage — what each note actually lands on

Every note was checked against the code before being sized. The "what's there now" column is the
thing that surprised me in at least three cases.

| # | Note | What's there now | Fix | ADR |
|---|---|---|---|---|
| N1 | Follow toggle state is invisible | `WaveformSections.swift:107` — the *only* on/off signal is `textPrimary` vs `textSecondary` on a `Label` | Give it a selected-chip treatment (filled capsule + filled symbol), like the tag chips | — |
| N2a | Show the old command tempo to compare | `RoutineBlockDoneView+CommandRow.swift:94` — the stepper renders `revisionValue` alone; `anchors.command` is in scope and unused | Render `90 → 96`, old value dimmed | — |
| N2b | "…ensure this surfaces for loops as well" | Standalone loop runs **already** get it (`LoopRunView.swift:208`). **Routine loop blocks don't** — `RoutinePlayerView+Done.swift:revisionAnchors` returns `nil` unless `stage.exercise`. This contradicts ADR 0134 (see below) | Build percent anchors for `stage.loop`, thread `unit: .percent`, commit the revision in `commitDone`'s `.loop` case (it currently writes mastery only) | — (0134 already covers it) |
| N3 | Goal target-song list UI | `GoalEditorView.swift:209` — a menu `Picker` over the entire song library, unsearchable, truncating | Replace with a pushed searchable list reusing the `AddRoutineUnitRow` grammar | — |
| N4 | Journal in the live run sheet | `showingJournal` is gated `!isRunning && routineContext == nil` in **both** `ExerciseRunView.swift:131` and `LoopRunView.swift:163` — so it's unreachable mid-run *and* unreachable in a routine at all | Compact capture everywhere + inline field where there's room | **new ADR** |
| N5 | Keyboard obscures the note field | `RoutineBlockDoneView.swift:228` — a growing `TextField` in a `ScrollView` with no focus-driven scroll. Same shape in 4 other places | One reusable focus-scroll modifier, applied at all 5 sites | — |
| N6 | Routine-level session journal entry | `JournalOwner` is `loop \| exercise` only; `JournalEntry` has two owner relationships | Third owner, loose-id shaped like `PracticeRun` | **new ADR** |
| N7 | Journal entries should link to their unit | The owner caption **already renders** (`JournalEntryRow.swift:28`) — it's just dead text | Make the caption a link; add the unit list to a session entry's header | folds into N6's ADR |
| N8 | Collapsible categories, universal | `ExerciseLibraryView.swift:106` uses plain `Section`; `LoopLibraryView.swift:116` is a **flat** `ForEach` with no grouping at all | Reusable collapsible section + group loops by song first | — |
| N9 | Record in Improvise | Infra all exists (`RecordingController`, `RecordArmToggle`, `Recording.loop`), but ADR 0069 scoped takes to standalone runs and excluded songs | Arm control on the improvise surface | amend 0069 |
| N10 | Split key selection by note and tonality | `SongEditSheet.swift:74` — one 25-row menu over `MusicalKey.pickerOrder` | Root picker × major/minor, composed into the enum | — |
| N11 | ADR 0132 metronome fade / click withdrawal | Proposed, **no code** | Build slices 1 and 2 as specced | 0132 (exists) |

### Three corrections to how the notes read

- **N2b is narrower than it looks, and it is a plain bug.** Loops already carry the offer when run
  standalone; the gap is routine loop blocks only. And that gap was never decided — ADR 0134's
  Scope line reads *"exercises **and** loops … standalone runs **and routine blocks** under manual
  advance"*, and its §8 rejects the exercises-only build in terms that describe today's app exactly:
  *"Building it for exercises only would leave two completion screens that look identical and behave
  differently."* The `nil` in `revisionAnchors` carries a comment claiming loop blocks are
  "unchanged by 0134" — that comment asserts a rule the ADR never made. **No amendment is owed; the
  ADR is already right and the code is behind it.**
- **N7 is mostly done.** `JournalTimeline.ownerLabel` already produces `"Canon in D Major · Loop 2"`
  and the row already renders it. The work is navigation plumbing, not data. It is correctly the
  cheapest of the prioritised items.
- **N4 has a nastier half than the screenshot suggests.** The note frames it as a layout problem
  ("free space on loops, no space on fretboard drills"). The real blocker is the
  `routineContext == nil` gate — journal capture is currently *absent from routines entirely*,
  which is where most practice happens.

---

## 2. Slices

Ordered so the one thing that needs a week of living with it starts first.

### Slice 1 — ADR 0132 Slice 1: the click withdraws itself
**Why first:** ADR 0132 §5 says the eight-bar distributions in §2 can only be judged by playing
against them, and its own Slice 2 is deferred "because a week of practice against the global
default is what tells you which drills actually want to differ." Building it last means shipping
untuned defaults. Building it first means every subsequent device pass in this plan doubles as its
soak test.

Everything in ADR 0132 §1–§5, §7, §7a, §8. No `@Model` change.

- `Pocket/Core/Audio/ClickWithdrawal.swift` — new, pure (no SwiftUI, no AVFoundation). The three
  levels, the eight-bar cycle table, `resolve(exercise:global:strumArmed:)`.
- `StandaloneMetronomeEngine+Withdrawal.swift` — new split. `drillOriginTick` capture and its
  invalidation on `reanchorPhase()`. **Never the core file:** it is at 399 lines against a 400-line
  `--strict` cap.
- `StandaloneMetronomeEngine+Strum.swift` (51 lines) — the `scheduledLevel` branch, and the
  precedence chain asserted in tests rather than left to reading order.
- `Settings/ClickWithdrawalSection.swift` — new. `SettingsView.swift` is at 394.
- `BeatIndicator` reads the level the click was voiced at; run caption carries the static word
  (the VoiceOver carrier — the indicator is `accessibilityHidden`).

Tests: the level at every bar of all three cycles, cycle restart on re-anchor, the
`nil`/`off`/level resolution table, the strum-armed exclusion, bar arithmetic across a ramp step.

### Slice 2 — small surfaces and the Done-screen gap (N1, N5, N10, N3, N2)
Five independent fixes, one device pass. No ADR, no schema.

- **N2** — the Done screen. `revisionStepper` renders `anchors.command → revisionValue` instead of a
  bare new value, and `revisionAnchors(for:)` stops returning `nil` for loop stages: percent anchors
  from `Loop.backoffSpeed` and `TempoMath.percentRange`, `unit: .percent` threaded through, and
  `commitDone`'s `.loop` case calling `loop.settleCommand(to:)` / the raise mirror instead of
  writing mastery alone. Every piece it needs was built by ADR 0134 §3/§8 and left unwired.

- **N5 first** — it is a shared modifier (`@FocusState` + `ScrollViewReader` → `scrollTo(anchor:
  .center)` on focus *and* on text change, since the reported failure is growth on a line break).
  Applied to `RoutineBlockDoneView`, `JournalSheet` (×2), `LoopModeNoteSection`,
  `SongDetailsSheet`, `FreeformSettingsSections`.
- **N1** — Follow gets the selected-chip treatment. Grid stays as-is: its effect is self-evident
  (gridlines appear), Follow's only shows on the next pinch, which is exactly why it reads as dead.
- **N10** — add a pure `MusicalKey.make(pitchClass:quality:)`; the sheet becomes a 12-root picker ×
  a major/minor segmented control, with Unknown as the cleared state. `pitchClass`, `quality` and
  `NoteSpelling.forMusicalKey` already exist, so the spelling stays key-first (ADR 0123). Unit-test
  the round-trip `make → parse → make`.
- **N3** — pushed searchable song list.

### Slice 3 — journal reach (N4, N7) · **new ADR**
The prioritised pair, and they share one seam: the journal stops being a post-run, standalone-only
surface.

**N4 — capture during a run.** Recommended shape: **one compact capture sheet reachable everywhere**
(a note button in the run chrome, live during a run and present inside routines), *plus* the
existing inline `LoopModeNoteSection` field where there is genuine room — the loop trainer's live
readout, improvise, ear. That answers the note's own "not so ideal for fretboard based exercises" —
the fretboard drill gets the button, not a squeezed field. Opening it must not pause the engine
(cf. `pauseForNestedAudio`, which exists for the opposite case).

**N7 — link the caption.** `JournalEntryRow`'s `ownerLabel` becomes a navigation target into the
exercise or loop. **Route by stable `uid`, never `persistentModelID`** — ADR 0090's dismissal trap.

The ADR is needed because this closes off "journal capture is a post-run reflection surface", which
ADRs 0038/0058 currently imply.

### Slice 4 — the session journal (N6) · **new ADR, one schema change**
The only slice that touches the store.

Recommended shape, following `PracticeRun`'s precedent exactly: `JournalEntry` gains
**loose optional id copies** (`routineUID: UUID?`, plus the practised-unit snapshot) rather than a
third SwiftData relationship — deleting a routine must not delete the reflection written about it.
Additive optionals, so lightweight migration is exempt from the CoreData 134110 rule.

Write seam: `RoutinePlayerView.finishedView` — which **already computes `practicedTitles`**, the
exact "exercise list on the header of each entry" the note asks for. The summary screen gains the
same composer the Done screen has.

`JournalOwner` gains a `.session` case; `JournalTimeline.ownerLabel` and the search haystack learn
it. Depends on Slice 3 for the linked-header rendering.

Release note: v1 is approved but **held**, so there are no installs in the field and no user
migration is owed — but the device test must still run over *existing* data on the dev device. A
clean install cannot show a migration failure.

### Slice 5 — collapsible, grouped lists (N8)
One reusable collapsible section, persisted expansion state, applied to the exercise library
(already sectioned) and the loops library (**needs grouping by song added first** — it is flat
today). Match the bucket grammar of `AddRoutineUnitSheet`, which is what the note points at.

### Slice 6 — record over a backing track (N9) · **amend ADR 0069**
Arm control on the improvise surface, owner `Recording.loop`. The amendment has to state the
bleed position honestly: the backing track is playing out loud, so an un-headphoned take captures
both. `RecordingRoute.isClean` and `RecordSetupHint` already carry that nudge — reuse, don't
re-invent. Stays on-device, no sharing, per the note.

### Slice 7 — ADR 0132 Slice 2: the per-exercise override
`Exercise.clickWithdrawalRaw: String?` (raw string, computed accessor — a stored custom enum traps
on device migration), the `ConfigureExerciseForm` row, and the resolver gaining its `exercise:`
argument. `nil` means inherit and **cannot** be collapsed into `off`.

Last on purpose: it is the only part of 0132 that can break an existing install, and by then Slice
1 will have had six slices' worth of practice time to prove or move the §2 distributions.

---

## 3. Decisions worth your call before the ADRs are written

1. **Session-journal storage** — loose `routineUID` + a snapshot of unit ids/names (recommended,
   matches `PracticeRun`, deletion-safe), *or* a real `Routine` relationship (simpler queries, but a
   deleted routine takes your reflections with it).
2. **Live capture shape** — one compact sheet everywhere + inline where there's room
   (recommended), *or* inline-only, which leaves fretboard and chord drills with nothing.
3. **Slice 1 ordering** — building 0132 first is the recommendation above and it inverts the
   obvious "small fixes first" order. Say if you'd rather clear Slice 2 first for the morale.

## 4. Not in v2

Anything discovered during these slices that isn't one of N1–N11 goes to `docs/backlog.md` under a
new **v3** heading. Named candidates already visible:

- ADR 0131's deferred `sound` mode and §6 precedence — ADR 0132 §8 makes it materially cheaper once
  Slice 1 pays for `drillOriginTick`, but it is still its own feature.
- Waveform panel deletes (ADR 0125, deferred).
- Journal year tier / wrapped / streaks (ADR 0117, deferred).
