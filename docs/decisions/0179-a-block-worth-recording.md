# ADR 0179 — a block worth recording

- **Status:** Accepted
- **Date:** 2026-08-22 (`pocket-282-a-block-worth-recording`)
- **Relates to:** ADR 0069 (practice-take recording — this **narrows** its slice-4 gate and extends
  its 2026-08-05 amendment), ADR 0070 (the app never grades the playing, and does not start now),
  ADR 0071 (the routine player and its Done screen), ADR 0077 (a routine block is not the full
  editor), ADR 0117 (a take is captured *during* a run that already logs its own row), ADR 0129/0130
  (the block preview this control joins), ADR 0136 (the freeform block that recorded first), ADR
  0151 (a take outlives its owner)
- **Schema:** one additive `Bool` with a declaration default (`RoutineItem.recordsTake`). No new
  entity, no new relationship, no new `PracticeRunKind`.

## Context

**Recording already happened inside routine sessions — on three of the six block kinds.** That is
the fact this ADR starts from, because it is not what the codebase looks like from the outside.

ADR 0069 slice 4 made takes a standalone-practice feature, gated to `routineContext == nil` on both
the arm toggle and the review bar, on the grounds that *routine blocks stay focused* (ADR 0071/0077).
The **2026-08-05 amendment** then lifted that gate for **freeform**, **improvise** and **ear**
blocks, reasoning that they are open-ended by construction — no ramp, no command, no tempo
trajectory — so *a take is their only record of what was played*.

What was left gated:

| Routine block | Recorded before this | Why |
|---|---|---|
| Exercise (ramped) | ✗ | `routineContext == nil` |
| Loop (trainer / ramped) | ✗ | `routineContext == nil` |
| Exercise (freeform) | ✓ | 0069 amendment §1–2 |
| Loop (ear) | ✓ | 0069 amendment §2 |
| Loop (improvise) | ✓ | 0069 amendment §2 |
| Song play-along | ✗ | no recorder at all |

The amendment's argument for the gate that remained was: *"a ramped drill already has a Done screen
and a logged tempo as its evidence."*

**That is right about evidence and wrong about the question.** A logged tempo says you reached 96
BPM. It does not say whether 96 *sounded* like anything — whether the timing held, whether the tone
fell apart, whether the thing you were actually working on happened. That is a different question,
and a recording is the only thing in the app that answers it. Slice 4's gate answered the first
question and quietly closed the second.

The correction is narrow. Recording is **not** something a ramped block should do by default: most
blocks are not worth hearing back, most sessions are not worth recording, and a routine that
captured everything would be a folder of audio nobody opens. It is something a block can be
**marked for**.

## The constraint that decided the shape

`AppSettings.routineAutoStart` defaults to **true**, and the arm ring lives only in the run screen's
`!isRunning` branch. So the obvious implementation — delete the two `routineContext == nil` checks —
ships a control that flashes past before it can be tapped, on the default setting, for every player.
It would look like the feature and not be it.

That forced the decision *earlier*, to authoring time — which turns out to answer slice 4's original
objection in full rather than overruling it. Nothing new appears on the running block. The player's
hands stay on the instrument.

## Decision

### D1 — the flag lives on the block

`RoutineItem.recordsTake`, set in the routine editor's block preview, beside the length control that
is already there for the same reason (ADR 0130 put the length opt-out next to the numbers it
changes). A routine can record one block and not the rest — which is the actual want: *this* drill is
worth hearing back, the warm-up before it is not.

Declaration default `false`, so every routine authored before this reads exactly as it did.

### D2 — arm is implied; there is no run-time control

A marked block arms its recorder in `.onAppear`, and the `recorder.beginArmedTake()` **already
sitting in both `commitAndStart` paths** starts the take before playback, exactly as it does
standalone. No new audio wiring, and in particular no mid-run category flip — so 0069 slice 2's
audible glitch stays fixed by construction rather than by care.

The ordering is the one fragile thing and it is commented at both sites: arm **before**
`maybeAutoStart()`. `beginArmedTake()` is a no-op on an unarmed controller, so arming late produces a
block that plays perfectly and records nothing, with no error anywhere to say so.

The running block gains a **status readout** — `RecordingStatusView`'s red dot, timer and route cue —
and nothing to tap. It is honesty about a live microphone, not a control.

### D3 — the microphone prompt happens at authoring time

`RecordingController.toggleArm()` is `async` solely because it may raise the system permission
prompt. A routine block cannot wait on one: with auto-start on it is already running by the time a
dialog could be answered.

So flipping the toggle in the editor is what raises the prompt — the settled, non-playing moment
slice 2 wanted it in anyway — and a denial **reverts the flag**, so the block list can never badge a
block that has no way to record. At run time the block arms through a new
`RecordingController.armIfPermitted()`, which is synchronous and never prompts: revoked permission
means the block runs normally, records nothing, and says why.

`armIfPermitted` takes no session lease, so the controller's stated invariant — a controller holds
`(recording ? 1 : 0) + (holding ? 1 : 0)` and **nothing** while merely `.armed` — is unchanged.

### D4 — the take is reachable from the block's Done screen

`RoutineBlockDoneView` already gathers a mastery rating and a note; **"Take saved · 0:47 — Listen"**
joins that completion beat, above the rating, because it is a statement about what just happened
rather than a third thing to fill in. Listen opens the same `TakesSheet` the run screens use.

Two details that are not incidental:

- **The row resolves in the host's `body`.** Reading the owner's `recordingsByRecent` there
  establishes SwiftData observation on the relationship, so the row still appears when the run
  screen's `.onDisappear` finalises the take *after* the Done screen first renders — which is the
  real ordering, since the Done screen is what replaced the run screen.
- **It is guarded by a cutoff, not by recency.** A unit practised before already holds takes, and
  `recordingsByRecent.first` on such a unit is a recording from some earlier day. Offering that on a
  completion beat tells the player they just captured something they captured last week, and they
  have no way to know otherwise. `RoutinePlayerView` stamps when the block began;
  `RoutineTakeLookup.take(from:since:)` holds the rule, pure and tested — **including that a missing
  cutoff returns `nil` rather than falling back on the newest take.**

Where auto-advance is on there is no Done screen, and the take lands in the Journal and on the unit's
own review bar next time it is opened standalone — unchanged from every other take in the app.

### D5 — the review bar stays gated

`PracticeReviewBar` remains `routineContext == nil` on the running block. ADR 0077's rule holds: a
routine block is not the full editor. D4 is the door, and it is on the completion beat where the
player has already stopped playing.

### D6 — song blocks stay excluded

`RecordingOwner.song` remains the unused seam ADR 0069 left it as. Songs are arguably the most worth
hearing yourself over, and song play-along exists *only* inside routines — so this is the weakest of
the six decisions and the one most likely to be revisited. It is out of scope here because it needs a
recorder built on a screen that has none, not a gate narrowed.

### D7 — the flag is read only where it means something

`RoutineSessionPlayer.stage(for:)` carries `recordsTake` for an exercise block and for a **trainer**-
mode loop block, and drops it for ear and improvise. Those already record unconditionally (0069
amendment §2) through their own screens' controls; honouring the flag there too would be a second,
contradictory switch over one behaviour, and the block-list badge would claim to be the reason a
block records when it isn't.

## Consequences

- **No new `PracticeRunKind`.** ADR 0117's rule holds: a take is captured *during* a run that already
  logs its own row, and a second would double-count minutes.
- **No new owner plumbing.** `Exercise.recordings` / `Loop.recordings`, `RecordingOwner`,
  `Recording.ownerLabelAtTake` (ADR 0151) and `TakesSheet` are reused unchanged. A take recorded in a
  routine is owned by the exercise or loop it was played against — **not by the routine** — so it
  survives the routine's deletion and appears wherever that unit's takes appear.
- **One analytics event, at the decision.** `toolOpened(tool: .recording)` fires when a block is
  marked, not once per block-run, which would count the same choice on every play.
- Two run screens' transports moved to their own files (`ExerciseRunView+Transport.swift`,
  `LoopRunView+Transport.swift`) — the status readout pushed both past the length caps CI enforces.

## Alternatives considered

- **Record the whole session.** Declined at the outset, and rightly: a session is 30–45 minutes of
  audio, most of it warm-ups and rests, and nobody listens back to it. The unit that is worth
  hearing is the block.
- **Lift the gate and let the arm ring appear.** The cheapest change, and the one that looks correct
  in a diff. It fails on the default settings for the reason above, and fixing it means suppressing
  auto-start on ramped blocks — changing routine pacing for everyone to make a control reachable.
- **A mid-block record toggle.** Technically available: `holdRecordSession()` already makes a mid-run
  toggle glitch-free on the freeform screen. Declined because it re-opens exactly what slice 4
  objected to — a control competing for the player's hands during a drill that is running to a
  schedule — and D1 removes the need for it.
- **Offer it on the previous block's Done screen**, beside "Up next". Fits the existing IA and reads
  well, but the first block has no predecessor and auto-advance skips Done screens entirely, so it
  cannot be the only door.
- **A global "record routine blocks" setting.** One switch is easier to build and worse to use: it
  says *record everything or nothing*, which is the whole-session idea wearing a smaller hat.
