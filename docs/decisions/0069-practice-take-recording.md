# 0069 — Practice-take recording (mic-only "audio journal")

- **Status:** Accepted (2026-07-16)
- **Date:** 2026-07-07 (proposed), 2026-07-16 (accepted)

## Build (accepted 2026-07-16)

Sliced post-v1 on its own branch, never riding the paused v1.0 submission:

- **Slice 0 (foundations, this branch `pocket-148`)** — mic permission string +
  `AVAudioApplication.requestRecordPermission` flow; a record-capable session
  config in `AudioPlumbing` (§3); and the **pure route classifier** that drives
  the headphone-clean vs speaker-bleed cue (§2), unit-tested. No model, no
  capture, no UI yet. The session options are the copyright/quality guardrails
  baked in at the substrate: `.playAndRecord` + `.defaultToSpeaker` +
  `.allowBluetoothA2DP` **without** `.allowBluetooth` — output stays high-quality
  A2DP and input falls back to the built-in mic (avoids the Bluetooth
  HFP-collapse; the guitar is in the room, not the earbuds).
- **Slice 1 (model + capture + storage, `pocket-148`)** — `Recording` SwiftData
  model (§5): app-authored AAC file addressed by a relative `fileName`, with a
  **polymorphic owner** (`loop`/`exercise`/`song`, the JournalEntry/ADR-0058
  pattern; `ownerKind` derived, no stored enum) that is **cascade-owned** by its
  owner via an inverse `recordings` array on `Loop`/`Exercise`/`Song`, mirroring
  the sibling `journal` pillar — deleting an owner deletes the take's row, and the
  now-unreferenced file is reaped by the orphan sweep. (A bare unidirectional
  relationship was found to leave the link *dangling* at a deleted model rather
  than clearing — the inverse is required for any delete rule to fire.)
  `RecordingStore` owns the container directory + delete/size and the pure
  orphan-sweep retention logic. `TakeRecorder` captures mic-only to AAC via
  `AVAudioRecorder` (not tapping the playback engine — engines stay unchanged per
  §3). Owner-resolution + orphan logic unit-tested; real capture is device-only.
- **Slice 2 (loop-trainer UI, `pocket-148`)** — recording is a **pre-start arm
  toggle** beside Start training (off by default), not a mid-run button (device
  feedback 2026-07-17). Arming requests mic permission on the setup screen and
  samples the route so the headphone-vs-speaker nudge shows *before* the run; the
  take begins when the run commences (after the count-in) and stops when the run
  does. This also **fixed an audible glitch**: configuring `.playAndRecord` before
  playback starts, rather than flipping the category mid-stream, removes the
  interruption. Same slice: standalone **loop training now gets the visual
  count-in** (respecting the Count-in setting) that exercises already had.
- **Slice 3 (relisten, `pocket-148`)** — a loop's takes are reachable from the
  run-setup screen and play back: `RecordingPlayer` (one `AVAudioPlayer` take at a
  time) + `TakesSheet` (rows with play/pause + swipe-to-delete, deleting the file
  and the row). Surfaced **beside the journal** — the ADR frames recording as the
  audio counterpart to the notes/journal pillar. To keep the setup screen from
  drowning as history builds (device feedback 2026-07-17), the two stacked inline
  previews (journal + takes) were replaced by a single-row **`PracticeReviewBar`**:
  two count pills, each opening its sheet — bounded to one row forever, counts as
  the at-a-glance signal, content in the sheets.
- **Slice 4 (exercise runs + scope, `pocket-148`)** — recording extended to the
  standalone **`ExerciseRunView`**, the exact loop-trainer treatment (arm toggle +
  `PracticeReviewBar` + Takes sheet), which also **unified the journal presentation**
  (exercises' old stacked `JournalPreviewSection` → the same pill bar). The record
  controls (`RecordArmToggle` / `RecordSetupHint` / `RecordingStatusView`) were
  extracted to a shared, owner-agnostic `RecordControls.swift` so both screens style
  them in one place. The metronome engine's `configureSession()` gained a guard so it
  won't downgrade an armed `.playAndRecord` session on `start()` (unlike the loop
  engine it reconfigures every start). **Scope decision — recording is a standalone-
  practice feature only**, gated to `routineContext == nil` (arm toggle *and* review
  bar): routine blocks stay focused (ADR 0071/0077), and since **song play-along
  exists only inside routines**, songs are **deliberately excluded** — no standalone
  song surface to record against. `RecordingOwner.song` stays in the model for a
  future standalone song surface. Exercise take start is before the engine's audible
  count-in, so a *speaker* take catches a couple of count-in clicks; a headphone take
  stays clean.

## Amendment — open-ended blocks record too (2026-08-05)

The v2 close-out's last slice took recording to the two surfaces that had no way
to reach it: **improvise** (ADR 0135) and **freeform blocks** (ADR 0136). No model
work was owed — a freeform block *is* an `Exercise` and improvise *is* a `Loop`,
so `Exercise.recordings` / `Loop.recordings` already existed. What was owed is two
reversals of decisions taken in slices 2 and 4, stated here rather than left as
drift.

**1. The arm grammar bends for a surface with no Start.** Slice 2's "armed before
the run, not toggled mid-play" stands for every surface that *has* a Start —
every ramped run, and improvise, whose 108 pt play button is a real Start and so
takes the existing arm-then-Start wiring at no cost. A **Start-less surface gets a
direct toggle** (`RecordTakeToggle` → `RecordingController.toggleTake`), because
you cannot arm for a Start that does not exist. The original objection — fiddling
with controls mid-drill, hands on the instrument — is about ramped drills running
to a schedule; a freeform block is prose and a clock, and the player is already
tapping things on it.

ADR 0136 F4 is **not** amended: a freeform block still has no transport, its clock
still starts on arrival, and the click still starts in `.onAppear`. The reversal
is confined to this ADR's arm grammar, where it belongs.

**The category flip is the real constraint**, and it is what made the arm grammar
right in the first place. A mid-session toggle would flip `.playback` →
`.playAndRecord` with the click already ticking, and back again on stop — the
audible glitch slice 2 removed, twice. So a Start-less screen that ticks
**holds the record-capable session for the lifetime of the screen**
(`holdRecordSession()` in `.onAppear`, *before* the click starts;
`releaseRecordSession()` on the way out), and the take toggle changes no category
at all. With no click there is nothing sounding, so nothing is held and the
session stays `.playback` — §3's "only while a take is armed" holds wherever it
can, and "never a global flip" is untouched either way.

**2. The routine gate lifts for open-ended blocks only.** Slice 4 gated recording
to `routineContext == nil` because routine blocks stay focused. That gate stays
for **ramped** exercise and loop blocks: a ramped drill already has a Done screen
and a logged tempo as its evidence. It lifts for **freeform and improvise blocks**,
which are open-ended by construction — no ramp, no command, no tempo trajectory —
so a take *is* their record of what was played. Most practice happens inside a
routine, which is where these two blocks mostly live.

Consequences: no new `PracticeRunKind` (a take is captured *during* a run that
already logs its own row; a second would double-count). `RecordingStatusView` is
unchanged — on improvise the bed is playing out loud and
`RecordingRoute.speakerBleed` already carries that honesty cue; `RecordSetupHint`
gained a `startPhrase` parameter, since "when training starts" is wrong on a screen
whose button says *start the backing track*. A freeform block never opens
`ExerciseRunView`, so it carries its own **Takes** entry in the ⋯ menu; without it,
its takes would exist only in the Journal tab. `RecordingOwner.song` still has no
standalone surface and stays unused.

**3. The recorder is a session holder** (added on the device pass that followed,
2026-08-05, after takes were found to be **destroyed on stop**).

`AudioPlumbing` reference-counts the shared session, and every audio producer takes
a lease — except, until now, the recorder. So the last *other* producer stopping,
or anything asserting `.playback`, tore the session out from under a live
`AVAudioRecorder`. `AVAudioRecorder.currentTime` then reads `0`, which
`RecordingController` read as an accidental tap below `minTakeDuration` and deleted
the file. Three things follow, and together they are the fix:

- **`RecordingController` holds two `AudioSessionClaim`s** — one for the duration of
  a take, one for the duration of a held record session. The invariant is stated on
  the property: a controller contributes `(recording ? 1 : 0) + (holding ? 1 : 0)`
  holders, and nothing while merely `.armed`, because arming touches no session.
- **The `.playAndRecord` guard is no longer per-engine.** It lived inline in
  `StandaloneMetronomeEngine`, under a comment reasoning that `PracticeAudioEngine`
  "configures once at load" and so didn't need it. True on the loop trainer, which
  preloads; false on improvise, where the first play tap loads *after* the take was
  armed. It is now `AudioPlumbing.ensurePlaybackSession` / `ensureRecordSession`, and
  every producer goes through it — including `RecordingPlayer`, which was downgrading
  the session when a take was auditioned and so breaking the *next* take.
- **`beginArmedTake` asserts the record category rather than trusting `holdsSession`.**
  A flag can be right while the session has since been changed underneath it, which is
  exactly what the Takes sheet did.

`TakeRecorder.stop()` also stops believing a zero: when `currentTime` reports nothing
it reads the true length back off the written file (`AVAudioFile`, header-only), and
logs — reaching that fallback always means something stopped the recorder behind our
back. **A file holding real audio is never deleted for looking empty.**

This repairs the **shipped** surfaces too, not just the two new ones: `LoopRunView`
and `ExerciseRunView` both finalise takes from `.onChange(of: isRunning)`, which runs
after their engine has already released the session. Those seams are now commented as
lease-dependent, since there is nothing there to reorder.

**3a. Deleting a take is a hold, and it is undoable** (2026-08-06). `TakesSheet`
deleted on a plain `.onDelete` swipe and called `RecordingStore.delete` straight
through, which made it the easiest place in the app to lose a recording. A take has
no source to regenerate it from — unlike an exercise, which can be rebuilt from the
same idea — so the gesture should cost what the mistake does: delete moved to the
row's hold menu, and the sheet took the shared `RowDeletionCoordinator`, so the
owning screen's existing delete closure now runs as the *deferred* action and the
file survives as long as the Undo toast does. The host screens were not touched.
Rename keeps its swipe: it destroys nothing.

**4. A take can be named.** `Recording` gains an optional `title` (additive, no
declaration default). Takes are the only row on the Journal feed with nothing but a
timestamp to distinguish them — a note carries its own words, a session note carries
its routine's name — so naming is offered here and on no other entry kind. Renaming is
reachable from both surfaces a take appears on, through one shared alert keyed on the
take's stable `uid` (ADR 0090). A named take also joins
`JournalTimeline.searchHaystack`, or naming one would make it identifiable everywhere
except the search field.

## Context

The product should let a user **record their practice** — capture their playing,
then relisten and review it — an audio counterpart to the notes/journal pillar.
Full sizing lives in `docs/research/feasibility-practice-recording.md`; this ADR
records the decisions that close off alternatives.

Pocket is deliberately **local-first** and its engine is built on DRM-free local
files because Apple Music streaming audio cannot be tapped (ADR 0001). ADR 0064
then made audio the one thing that never rides a sharing rail — exercises are the
shareable unit; loops and audio are not. A recording feature has to be designed
inside those two walls, not against them.

Two framings of the feature pull in opposite directions:

- **"Record me"** — mic capture of the user's own playing. The user owns their
  performance; no third-party rights attach.
- **"Record my session with the track"** — a mixdown of the mic *and* the app's
  loop playback in one file. This is what users often picture, but it bakes a copy
  of the copyrighted recording into a user file — the exact wall ADR 0001/0064
  exist to keep the product clear of.

A separate question is **isolation**: when recording over a playing loop, can we
capture just the guitar? With mic-only capture the loop couples into the
recording **acoustically, not digitally** — if we record the input node and never
tap the mixer, the loop's samples never enter the file; the only path is speaker →
air → mic. So isolation is a function of the output route, not a DSP feature we
must build (detail and the AEC dead-end are in the research doc).

## Decision

1. **Ship mic-only "practice takes"; do not build the mixdown.** A take captures
   the microphone (the user's playing) only. The app never renders its own loop /
   song playback into a recording file. This keeps every recording free of
   third-party rights and consistent with ADR 0001/0064. The mixdown framing is
   closed here until a rights framework reopens it (same posture 0064 took on loop
   sharing).

2. **Isolation over a loop is solved by route, not by cancellation.** Use
   `AVAudioSession.currentRoute.outputs` to detect the output path and set
   expectations:
   - Headphones / Bluetooth → a **clean take** (the loop is not in the room);
     record with confidence.
   - Built-in speaker → surface a nudge that the backing track in the room will be
     captured, and recommend headphones for an isolated take.

   We explicitly **do not** ship acoustic echo cancellation for this: the built-in
   voice-processing AEC is speech-tuned and degrades instrument tone, and DIY
   cancellation is a research project with imperfect results. Messaging beats a
   fight we can't win at music quality.

3. **Recording uses its own session config, not a global flip.** Recording needs
   `.playAndRecord`; playback/metronome keep `.playback`. Add a separate
   record-capable configuration (with `.defaultToSpeaker` as appropriate) applied
   only while a take is armed, so the shared `AudioPlumbing` path and the
   non-recording behaviour of both engines are unchanged.

4. **Permission and privacy land in the same PR as the feature.** Add a specific
   `NSMicrophoneUsageDescription` (never a vague one — rejection risk) and use the
   iOS 17+ `AVAudioApplication.requestRecordPermission` flow. Update
   `PrivacyInfo.xcprivacy` if a required-reason API is touched. No mic key exists
   or is added before this feature ships (per the standing dev guide).

5. **Recordings are app-authored files with their own model.** Unlike songs
   (security-scoped bookmarks to files in place), takes are files the app owns in
   its container, encoded AAC (not raw PCM — storage). Model them as a SwiftData
   `Recording` entity carrying created-at, duration, and a link to the
   session/song/exercise the take was made against, plus a retention/cleanup story.

6. **Recordings stay local; they never enter the social rail.** Consistent with
   ADR 0064, a take is never shared and never transits the social backend. Whether
   takes ride *personal* CloudKit sync is deferred (audio is heavy; not required
   for the feature to be useful) and is not decided here.

## Consequences

- **The clean core ships without touching the hardest problem** (audio rights):
  mic-only takes, headphone-clean isolation for free, a speaker nudge for honesty.
- **New submission surface** — a mic permission string + privacy manifest review +
  app-container audio files — all inside the `/ready-to-ship` gate, handled in the
  feature PR.
- **A "record with the track" request later is a new ADR against §1**, not a
  drift — same discipline ADR 0001/0064 hold for streaming and loop sharing.
- **Storage grows with use** (AAC keeps it modest); retention UX (delete takes,
  maybe a per-take size hint) is part of the first slice, not an afterthought.
- **Isolation is a UX cue, not an engine feature** — no AEC/DSP burden, and the
  "headphones recommended" framing reinforces existing practice guidance.

## Alternatives considered

- **Mixdown of mic + app playback** — rejected as the default (decision 1): bakes
  copyrighted audio into user files, contradicting ADR 0001/0064. Available in
  principle for local files only, gated behind a future rights decision.
- **Acoustic echo cancellation to isolate on speaker** — rejected (decision 2):
  built-in AEC is voice-tuned and wrecks instrument tone; custom cancellation is
  research-grade and imperfect.
- **Tapping the mixer / output node** — rejected: capturing app output is either
  pointless (song only) or the mixdown case above.
