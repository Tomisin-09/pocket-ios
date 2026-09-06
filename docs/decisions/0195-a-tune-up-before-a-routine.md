# ADR 0195 — a tune-up before a routine, offered where the room is already quiet

- **Status:** Accepted
- **Date:** 2026-09-07 (`pocket-302-tuner-and-stat-strip`)
- **Relates to:** places the tuner **ADR 0115** built and **ADR 0144** made free forever. Constrained
  by **ADR 0069** §3's session discipline and the `AudioPlumbing` note that discipline was written
  from. Adds a fifth row to the screen **ADR 0162** D2 named; a new phase in the player **ADR 0071**
  designed; a second trailing item on the Done screen **ADR 0071** R4 gave it. Declines to become
  the ⋯ menu `docs/directions-2026-09.md` §5a imagined. Picked up from §5a / §6 Tier 2 item 4.
- **Schema:** none. One `UserDefaults` key, `routineTunerOffer`.

## Context

Tuning is the one thing a player does before every session, and the app has had a good tuner since
ADR 0115 — buried in the Toolkit, behind a card that for a while did not even mention it.
`docs/backlog.md` found this from the other end and fixed it by rewriting the card's copy, which
addresses discoverability and not reach: mid-routine, the tuner is four taps and an exited session
away.

So: put it where a routine can reach it. The placement question turned out to be an **audio**
question, and §5a said so — *the gating unknown is the audio session, not the UI* — so this ADR
opens with the spike rather than the design.

### The spike, and what it found

A routine block renders through `AVAudioEngine` under a `.playback` session. A tuner taps the
microphone and needs `.playAndRecord`. Reaching the tuner from a **running block** therefore means
flipping the shared session's category underneath a live engine, and two things go wrong:

1. **A take armed on the block is destroyed.** ADR 0179 lets a routine block be authored to capture
   a take while it runs. Closing the tuner restores `.playback` — and forcing `.playback` while a
   take is rolling removes input from the route, the system stops the `AVAudioRecorder`,
   `currentTime` then reports `0`, and `RecordingController` reads that as an accidental
   half-second tap and **deletes the file**. That is not a hypothetical: it is why
   `AudioPlumbing.ensurePlaybackSession` exists, and it destroyed real playing on 2026-08-05.
2. **The block's own engine may stop.** A category change is a route change, and none of the six run
   screens observes `AVAudioEngineConfigurationChange`. The failure mode is silence with no error
   anywhere — the worst kind this app has.

ADR 0069 solved the same collision for recording by never flipping the category mid-flight, only
around an armed take. The lesson generalises: **do not put the tuner anywhere the flip would have to
happen.**

That is a real constraint and it is also a good design. You cannot tune over a backing track anyway.

## Decisions

### D1 — Offered, never a gate

Nothing here can stop a player playing. The question before block 1 has two answers that start the
routine and one that stops it ever being asked again; the between-blocks affordance is a button, not
a step. And nothing anywhere says you are *out of tune* — the tuner reports the pitch of a string you choose to play it, which is
ADR 0070 holding exactly as it does everywhere else.

### D2 — Two placements, both on the player's own screens

**Before block 1 — a question, asked by default.** A three-button alert: `Tune up` · `Don't ask
again` · `Not now`. Put once per presentation of the player, never repeated within a session.
`Tune up` leads to the tuner screen in D4; the other two start the routine.

**Between blocks — ungated.** A `tuningfork` toolbar button on the **rest** screen and the **Done**
screen. Not governed by the preference: reaching a tool is not something that happens to you, and a
setting that has to be found before a button appears is a setting that hides a button.

Both surfaces belong to `RoutinePlayerView` itself, and on both the block's run screen has already
been torn down — so its engine is stopped and its take is finalised **before** the tuner is built.
The hazard in the spike is designed out rather than guarded against. A guard would have been a
runtime check that has to stay right as six run screens change; a placement is a fact about where
the code is.

The rest screen is silent by construction (a visual countdown, no click). The Done screen is where
most between-block time actually is, because manual advance is the default (ADR 0071 R4).

⚠ **D2 and D6 were rewritten after a device pass** (2026-09-07). What shipped to the phone first was
the tuner screen *itself* before block 1, behind a default-**off** setting. Two things were wrong
with it, and only one was visible in the simulator:

- On the phone it read as the routine having been replaced by something else. A full screen is a
  fine place to tune and a bad way to be greeted.
- More seriously, a default-off setting is found by nobody — so the tuner would have stayed exactly
  as buried as `docs/backlog.md` found it, which is the complaint this ADR exists to answer. The
  first design solved reach and quietly gave up discoverability.

A question is cheap enough to ask everyone, which is what lets the default flip. The tuner screen
survives unchanged as what *yes* leads to (D4).

### D3 — The mid-block tuner is declined, and what that costs

A player who notices they are flat during block three cannot tune without leaving the block. They
can skip to the next one, or exit. That is the cost, and it is stated rather than hidden.

Making it work would mean a uniform "stop this block's audio and finalise its take" across
`ExerciseRunView`, `LoopRunView`, `FreeformRunView`, `ImproviseLoopRunView`, `EarLoopRunView` and
`SongPlayAlongView` — six screens with no shared pause, since `RoutineSessionPlayer` has `start`,
`advance`, `skip`, `back` and `end` and deliberately nothing in between. That is a different piece
of work with its own failure surface, and doing it as a side effect of placing a tuner is how the
2026-08-05 deletion happened in the first place.

**The honest answer is §5a's later one: a `Tune up` block type.** It makes tuning part of the
*plan*, travels with a shared routine (ADR 0188), and needs no session flip at all because it *is* a
block — nothing else is playing. It is a new `RoutineItem` kind, so ADR 0134 §11's switch over
`RoutineStage.Payload` gains a case and ADR 0127's *no rest next to a rest* gains a sibling rule.
Additive-only, so safe under ADR 0189's criteria. Not built here.

### D4 — The question is three answers, and *yes* is a whole screen

`Tune up first?` — *Check your strings before you start. You can always tune between blocks.* Over
`Tune up` · `Not now` · `Don't ask again`.

**`Don't ask again` is a third answer and not a checkbox** because a checkbox reaches the same
outcome in one *more* tap — tick it, then dismiss. That holds whatever the question is made of, so
it survived the restyle in D7 unchanged. It writes the same key `Settings ▸ Routines` writes,
through the same binding, so the row can never disagree with what the player just told the prompt.

Answering `Tune up` shows `TunerView` with `Start practising` pinned to the bottom — a full screen,
because by then the player has said they are tuning, and a tuner in the corner of something else is
a worse tuner. That button says `Start practising` and not *Skip*: leaving it is the beginning of
the session, not the abandonment of a step.

The question is drawn on a screen of its own, not over block 1. Building the block behind it would
start its engine under the question, which is the one thing the prompt must not do.

The session does **not** run underneath the offer: `player.start()` is held back until the offer is
dismissed. A routine whose first item is a rest would otherwise have counted its breather down while
the player was still tuning.

The rule is pure — `RoutineTuneUpOffer.shouldOffer(alreadyDecided:isEnabled:hasStages:)` — because
the interesting condition is the latch, not the preference. `onAppear` re-fires every time the
player returns to the front, and a second offer arriving between blocks four and five is the "never
repeated" rule broken. The latch is set whether or not an offer is made: deciding *not* to offer is
a decision, and re-deciding it on the next appear reopens the same hole. A routine with nothing to
play is skipped entirely — an all-orphaned one lands on the summary, and offering to tune up for it
would be the app asking you to prepare for nothing.

### D5 — `TunerEngine` restores the session only if it took it

`start()` records whether the category was already `.playAndRecord` and `stop()` restores `.playback`
only when this engine is what flipped it. Previously `stop()` restored unconditionally, which is the
D1-hazard move performed by whatever presents the tuner — a latent trap that this ADR's placements
happen to avoid and a future call site might not. `ensureRecordSession` replaces the unconditional
`configureRecordSession` for the same reason.

### D6 — Default on, and why that is not the same as a gate

The question is asked until it is told not to be.

The earlier default-off reasoning — *an offer nobody asked for is a gate with a Skip button on it* —
is true of a **screen** and false of a **question**. A screen takes the session away and hands back
something you did not ask for; a question costs one tap, and one of its three answers ends it
permanently. The asymmetry that decides it: a player who never wanted this pays three taps in total,
ever, while a default-off setting costs the player who *does* want it a feature they will never find.

Bound to `AppSettings.routineTunerOfferDefault` at both sites, because the literal an `@AppStorage`
declares is what SwiftUI uses for an unset key and it does not consult the accessor. The prompt and
the Settings row write the same binding.

### D7 — The question is the app's own screen, not a system alert

Added 2026-09-07, after the device pass that produced D2's amendment had already shipped once more.

The first two cuts both handed the question to a SwiftUI `.alert`. An alert is the one surface in
this app that **cannot be branded**: no font hook, no colour hook, no layout hook. Every other screen
is Futura via `Font.futura` (ADR 0061), so the tune-up question was the only thing in the routine
flow set in the system face — and it was the *first* thing a session showed you.

It was also **already paying for a screen it wasn't using**. An alert needs something behind it, so
the cut shipped a full-height `tuneUpBackdrop` — a fork glyph and the routine name — purely as
backing. Full-screen cost, none of the benefit.

So the backdrop and the alert become one screen: the app's ground, `futura`, the fork in a
`practiceCircleWash` circle, and `Tune up` in the same `Capsule` filled `PocketColor.practice` that
`RoutineDetailView.startBar` wears two screens earlier. Same three answers, **same tap count**,
nothing about the rule, the latch or the audio placements touched — `RoutineTuneUpOffer` is
untouched, and its tests pass unchanged.

**Deliberately not the ceremony.** `ArtistNamePromptSheet` (ADR 0113) is the repo's precedent for
exactly this feedback — its header records that *the plain sheet read flat* on a device — and it
answers with a 140 pt crescent, a staged 0.9 s fade and a dark lock. That is earned there because it
happens **once, ever**. This asks at the top of every routine, and **ceremony scales inversely with
frequency**: the same treatment here would read as something to get past by the fourth session. The
brand is carried by type, ground, hue and the capsule; there is no choreography and no seal.

`Don't ask again` moves **below** `Not now`, inverting the alert's cancel-role ordering. On a screen
the eye travels down, and the answer that ends the feature permanently should not be the one nearest
the thumb.

**Hue: teal to get there, indigo inside.** The `tuningfork` was `practice` on the backdrop and
`toolkit` on the toolbars — one glyph, two hues, inside one feature. It is now `practice`
everywhere on the way in, and `TunerView` keeps its own `toolkit` indigo. §3.1's rule is that hue
tells you which space you are in: you are in Practice until the tool opens, and then the tool
announces itself.

The cost is what an alert gave for free — Dynamic Type layout, VoiceOver framing, and the
unmistakable *this is a question* read. The last is bought back by keeping the screen sparse and the
primary answer the only filled thing on it; the first two are now this screen's to hold right.

## Consequences

- ⚠ **`reference/settings-routines` is knowingly stale**, showing four rows where the screen now has
  five. Not reshot here for the reason ADR 0196 gives: the manual shoot is batched with the Home
  tile-grid work, and this figure rides along with it. Recorded in the Tier 3 entry of
  `docs/directions-2026-09.md`.
- `Settings ▸ Routines` carries five rows, as `Ask to tune up`. It stays four sibling toggles plus a
  stepper — no new Settings destination, so `check-manual.py` C1's count of ten holds. It is the one
  row on that screen reachable from somewhere else, because the prompt carries its own off switch.
- The tuner screen inherits `TunerView`'s microphone permission flow, so a player who has never
  opened the Toolkit meets the system prompt there. It is reached only by answering `Tune up`, which
  is what keeps this acceptable under a default-on question: the mic is asked for by someone who just
  said they want to tune, never by the act of starting a routine.
- The Done screen gains a second toolbar item; the rest screen gains its first. Both are glyphs, per
  ADR 0126's grammar, and both are `practice` teal (D7).
- `ManualRoutineShots` queries the two answers as `app.buttons`, **not** `app.alerts.buttons` — D7
  moved them out of an alert. Still unshot, for the reason above.
- **Declined: the practice screen's ⋯ menu** that §5a imagined. There is no such menu — the run
  screens carry explicit trailing items (`ExerciseRunView` already has three) and inventing a menu
  to hold one tuner would churn ADR 0126's nav-bar grammar for every practice surface. A standalone
  run reaches the tuner from the Toolkit, as it always has.
- **Not covered:** tuning during a block, and the `Tune up` block type that is its real answer.
