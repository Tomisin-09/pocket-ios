# ADR 0131 — Warn before the tempo changes: the ramp announces its next step

- **Status:** Accepted, **built in part** on `pocket-211-tempo-change-warning`. §1, §2, §3, §3a, §4 and
  §7's quiet fallback are shipped. §3's `sound` mode and the machinery it needs — **§5** (the
  scheduled-beat boundary) and **§6** (the `scheduledLevel` precedence change) — are **deferred**, as is
  **§7**'s loop warning. See *Build slicing* below.
- **Date:** 2026-07-31
- **Builds on:** ADR 0045 (the command-anchored ramp) · ADR 0043 (the free-play linear automator) ·
  ADR 0048/0052 (the count-in and its beat boundary) · ADR 0071 R5 (per-slot click voicing) ·
  ADR 0050 (Settings V1) · ADR 0070 (never grade the player).
- **Reserves a seam for:** the **metronome fade** (withdraw the click for a bar or two so the player
  hears their own drift) — not built here, but §6 fixes the precedence rule it must obey.

## Context

Every ramp in the app changes tempo *without saying so*. `CommandRamp` steps from one plateau to the
next the instant `automatorBarsElapsed` crosses an interval boundary; `MetronomeAutomator` does the
same on its linear climb. The click simply speeds up mid-bar-line, and the player finds out by being
wrong — a beat or two of scramble while they work out that the ground moved.

This is a real practice defect, not a polish item. A tempo change you *react* to is a tempo change you
play badly through; a tempo change you *anticipate* is one you prepare for. The whole point of the
staircase (ADR 0045) is that the climb is gradual enough to absorb, and that intent is undercut if
every step lands as a surprise. Two or three wasted bars per plateau, across a ramp with eight or ten
plateaus, is a meaningful fraction of a block.

The information already exists and is already pure. `CommandRamp.plateaus` knows every boundary and
`currentPlateauIndex(elapsedBars:elapsedSeconds:)` already walks to the current one. Nothing new needs
to be measured — only reported, early.

**Why this is its own ADR and not part of ADR 0129.** 0129/0130 decide *how long* a block is and
*whether the player can decline that*. This decides what the click and the screen tell you *during*
the block. Different question, different surfaces, and it applies equally to free-play and standalone
runs that have no block around them at all.

**It stays clear of ADR 0070.** Announcing a change the app itself is about to make is the app being
legible about its own behaviour. It says nothing about how the player is doing — no measurement, no
judgement, no pass/fail. If anything it is the opposite of grading: it removes an artificial
difficulty the app was imposing by being silent.

## Decision

### 1. A pending change is a pure derivation on the ramp, not engine state

Add to `CommandRamp` (and, through `TempoRamp`, to `MetronomeAutomator`):

```swift
/// The next tempo boundary, and how far away it is in the ramp's own interval unit.
struct PendingTempoChange: Equatable {
    var from: Int          // the plateau now holding
    var to: Int?           // the plateau next — nil ⇒ the ramp ends here
    var unitsRemaining: Double
    var unit: MetronomeIntervalUnit
    var isRise: Bool { (to ?? from) > from }
}

func pendingChange(elapsedBars: Int, elapsedSeconds: TimeInterval) -> PendingTempoChange?
```

The ramp reports **how far and to what**; it never decides what counts as "soon". That belongs to the
consumers, which know the tempo and the meter and the ramp does not. This split keeps the plateau
arithmetic in the same pure, exhaustively-tested place as `bpm(…)` and `currentPlateauIndex(…)`
(AGENTS.md: tempo math is the logic that breaks silently), and means the warning cannot ever disagree
with the change it is warning about — both read the same `plateaus` walk.

`unitsRemaining` is a `Double`, unlike the `Int`-flavoured plateau cursor: the warning lives *inside*
the last interval, so fractional position is the whole point.

### 2. The window is at most one bar, and it is not configurable

The warning arms when **less than one bar of the current plateau remains**. A bar is the unit the
player is already counting in, and — crucially — it scales with the music: one bar is four seconds at
60 BPM and 1.2 seconds at 200 BPM, which is the right amount of notice at both ends. A fixed number of
seconds would be a yawn at the bottom of a ramp and useless at the top.

For a `.seconds`-unit ramp the conversion is done by the consumer at the live tempo:

```
barsRemaining = secondsRemaining × (bpm / 60) / beatsPerBar
```

This is exact within a plateau, because the tempo is by definition constant across the window being
measured.

**Clamped to half the plateau.** A bar is the *maximum* window, not a fixed one:

```
window = min(one bar, half the current plateau)
```

Without the clamp the feature is visibly broken at the low end, and broken by default. The minimum
plateau is one interval, so a bar-unit ramp with `intervalCount = 1` has a one-bar plateau that the
window covers entirely — the indicator never turns off, and a warning that is always on is not a
warning but a permanent next-tempo readout. The defaults hide it (`automatorDefaultBars` is 4, so the
window is a quarter of the plateau) which is precisely why it would otherwise survive to device. Half a
plateau is still two beats of notice in 4/4 at the worst case, and never permanently lit.

### 3. Three carriers, one Settings row

`TempoChangeWarning: String, CaseIterable` — `off` · `show` · `sound`, stored under a new
`AppSettings.Key.tempoChangeWarning`, **default `.show`**, resolved through a
`resolvedTempoWarning(storedValue:)` in the same shape as `resolvedAppearance` / `resolvedClickTimbre` /
`resolvedSpelling`, so an unrecognised stored value falls back rather than crashing.

| Mode | What happens during the warning window |
|---|---|
| `off` | Nothing. The ramp behaves exactly as it does today. |
| `show` *(default)* | The live readout's caption becomes the incoming tempo and the direction — *"→ 96 next bar"* / *"backing off to 84"* / *"last bar"* when the ramp ends. `RoutineStairs` pre-lights the next plateau at reduced opacity alongside the live cursor. The **drill surface takes a static warning edge** for the duration of the window (§3a). |
| `sound` | Everything in `show`, plus: every **on-beat** tick of the warning window is voiced at `.accent`, and its downbeat fires one haptic **when `AppSettings.hapticsEnabled` is already on**. |

**One row, not three toggles.** The carriers are not independent choices a player would mix — they are
increasing degrees of insistence. A player looking at the screen wants `show`; a player looking at
their hands (which is most of practice, and the reason a visual-only warning is close to worthless in
the real case) wants `sound`.

**Haptics ride the existing global setting** rather than adding a second one. A player who has turned
haptics off has already said what they want from the phone's motor.

**Why "every beat accented" for the audible carrier.** It is unmistakable without being a new sound:
the bar audibly *sits up*, and then the tempo moves. It needs no new sample, no new voice, and no
change to `ClickTimbre` — only a branch in `scheduledLevel(forTick:ticksPerBeat:)`, which is already
the single place per-slot voicing is decided (ADR 0071 R5). **On-beat ticks only:** sub-ticks stay at
`.subdivision`, or a warning bar with sixteenths armed becomes a wall of accents rather than a signal.

**No warning during the count-in.** `automatorCountingIn` holds the ramp at its floor (ADR 0048), so a
boundary reported there is not approaching and must be suppressed — the same gate `scheduledLevel`
already applies to strum schedules.

### 3a. The in-gaze carrier is a **static** edge on the drill surface

The caption and the staircase are both always present, and both are in the wrong place: the caption
sits at the top of the screen and the staircase below the drill, while the player is looking at the
board. A warning nobody sees is the same as no warning, and it fails hardest on exactly the drills
where an unannounced tempo jump costs most.

The beat dots cannot carry it. `ExerciseTemplateSurface` renders `BeatIndicator` only in its **fallback**
branch — a fretboard, strumming, chords or strum-chords drill has no beat dots on screen at all. Any
carrier that lives in the dots is absent from four of the five run configurations.

So: **for the duration of the window, the drill surface takes an edge in `PocketColor.practice`.**
Static — it appears, it holds, it goes. Four properties earn it the slot:

- **The signal is the edge's *presence*, not its hue.** The drill surfaces render on bare
  `PocketColor.background` with no border at all today (`FretboardView`, `ChordChangeView`,
  `StrummingLaneView`), so an edge appearing is already an unambiguous state change. It does not need a
  contrasting colour to be read — only to be absent the rest of the time. That is why the space's own
  teal is the right choice rather than a compromise one: no new token, no borrowed meaning, and no
  colour discrimination for the player to perform.

- **It is not motion.** A pulse would have to respect Reduce Motion — so a pulsing carrier would be
  silent for precisely the players this feature is for — and, the stronger objection, a pulsing
  carrier *is a visual metronome*, which is not what a tempo warning should be. A state change that
  does not animate is governed by neither, and needs no exemption or special case.

  > **Amended by ADR 0157.** This paragraph originally also rested on `exerciseAnimates` defaulting
  > **off** as a photosensitivity precaution, attributed to ADR 0050. Both halves were wrong: ADR 0050
  > never decided the default, and ADR 0157 has since flipped it to **on**. The decision here is
  > unchanged — it stands on the two reasons above, neither of which depended on that default.
- **It is one insertion point, not four.** `ExerciseTemplateSurface` is a single view switching
  internally across all five branches, so the modifier lands there and every drill kind — plus the
  plain-metronome fallback — is covered at once. None of `FretboardView`, `StrummingLaneView`,
  `ChordChangeView` or `StrumChordsView` changes, and the carrier cannot drift out of sync between
  drill kinds.
- **It is additive, so it does not repaint the drill.** Swapping the `tint:` those four views already
  take would be fewer characters, but on a fretboard drill the tint colours the note dots, which carry
  information. An edge leaves each drill's own colour language intact.

**Its weakness, named rather than buried:** the edge does not exist for VoiceOver. It is the *fast*
channel, not the *complete* one — the caption carries the identical warning as text, which is the
redundancy that makes the pair sufficient where neither is alone (see Consequences). Note this is
**one** redundancy requirement, not two: because the signal is presence rather than hue, colour vision
is not required to read it.

**Semantics rejected on purpose.** `PocketColor.danger` is the worst option available — this is not a
fault, and a red edge on a practice screen reads as *you did something wrong*, which is the feeling
ADR 0070 exists to keep out of the app. `confirm`/`active` green reads as go. `journal` gold and
`library` terracotta belong to other spaces. `marker` orange is a live collision rather than a
theoretical one: on the loop run screen (§7) the waveform's markers are already orange and on screen
at the same moment.

`metronome` plum was the serious contender and is recorded as such — a tempo change *is* the click
speaking, so the click's own colour is semantically exact. Rejected because it borrows another space's
identity onto a Practice screen, and that association is a fact about this codebase more than a fact
about the player. If device testing shows the teal edge reading as too native to notice, plum is the
first thing to try, and it should be checked in both appearances before it is adopted.

`LoopRunView` does not route through `ExerciseTemplateSurface`, so a loop run takes the equivalent edge
on its own surface (§7).

### 4. The ramp's **end** is a boundary too

`to: nil` — the final plateau running out — warns like any other, worded *"last bar"*. This is the
moment a block ends and `RoutineBlockDoneView` takes the screen; being dropped out of a run
mid-phrase is the same defect as being sped up mid-phrase. Cheap, and it falls out of the same
derivation rather than needing its own path.

### 5. The audible warning is computed from the **scheduled beat**, not from `elapsed`

This is the implementation trap, stated here because it has bitten this codebase before (ADR 0052: the
count-in engaged a beat early because `currentBeat` was read at the wrong moment).

`tick()` advances `automatorBarsElapsed` in ~20 ms steps, but `scheduledLevel(forTick:ticksPerBeat:)`
is asked about beats **inside the look-ahead window** — beats that have not happened yet. Deciding the
audible warning from `automatorBarsElapsed` would therefore voice it late, and by a variable amount.
The accented window must be decided from the *tick index being scheduled*. The visual carriers, which
describe the present, correctly read `automatorBarsElapsed`; the two disagree by one look-ahead window
by design.

**This needs one new piece of engine state, because the two clocks do not currently meet.** `tickIndex`
counts sub-ticks from `phaseOrigin` (set at `start()`); ramp progress zeroes independently at
`engageAutomator()`, after the count-in. Nothing maps between them. The bridge is to capture, at
engage, the **tick index and frame position the ramp engaged on** — after which a scheduled tick's
ramp position is exact in both units, with no reference to the wall-clock integrator at all:

```
barsAtTick    = (tickIndex − engageTick) / ticksPerBeat / beatsPerBar
secondsAtTick = (subSample(tickIndex) − engageFrame) / sampleRate
```

Both are exact rather than approximate, and that is not obvious: a tempo change re-anchors
`phaseOrigin`, but `MetronomeGrid.reanchoredOrigin` pins tick `scheduledThrough` to the same frame and
re-derives the origin around it, so **`tickIndex` stays monotonic across every plateau of the climb**.
The bar form counts musical units; the frame form counts real time; each matches the unit its ramp is
keyed on.

**The captured origin is invalidated by a mid-run meter or subdivision change**, which is the edge case
to write a test for: `reanchorPhase()` resets `phaseOrigin` to `nil` and `scheduledThrough` to `−1`, so
a run whose signature changes mid-climb must re-capture rather than carry a stale tick origin (which
would silently place every subsequent warning in the wrong bar).

All of this is unit-testable through pure boundary helpers, as `countInCountdown` /
`countInHasElapsed` are.

### 6. Precedence in `scheduledLevel`, fixed now for the fade's benefit

The click is becoming a channel that carries scheduled information beyond the meter. The order is:

```
count-in  >  warning bar  >  strum pattern  >  meter default
```

Two changes from today's code, both deliberate:

- **The warning outranks a strum pattern.** Today the strum schedule wins over everything but the
  count-in. But a strum pattern silences slots, and the one bar you must not silence is the bar that
  says the ground is about to move. During a warning bar the pattern **is replaced, not re-accented** —
  its rhythm is gone for that bar and a steady accented pulse takes its place. That is a real cost,
  stated plainly here rather than softened, and it is why `show` is the default.
- **The warning will outrank the metronome fade**, when the fade is built. A fade withdraws the click
  precisely so the player carries the pulse themselves — and a *silent* tempo change is the worst
  version of the problem this ADR exists to fix. A warning bar is never faded out.

This is the sense in which the two features pair: they are the same mechanism, the click scheduled
against the near future, pointing in opposite directions. Withdrawing the click is only safe once the
click can also announce itself. **The fade is not built here** — this ADR only guarantees the seam it
will land in, and the precedence rule that keeps the two from cancelling each other out.

### 7. Loop ramps warn in **passes**, and visually only

A `LoopCommandRamp` counts intervals in loop repetitions, not bars — there is no metronome bar clock
to hang a one-bar window on, and its click is the song. So a loop run warns during the **final pass**
of a plateau, worded *"last pass at 85%"*, on the run screen and the staircase. No audible carrier: the
pass boundary is already audible, and the notice a loop needs is measured in repetitions, not bars.

**The half-plateau clamp (§2) is load-bearing here, and it costs a fractional rep.**
`LoopCommandRamp.defaultRepsPerStep` is 1, so every non-dwell plateau is exactly one pass long — warning
for the whole final pass would leave the indicator lit for the entire ramp except the dwell. Clamped,
the warning covers the **back half of the final pass**, which `LoopRunModel` cannot currently express:
it tracks whole passes (`elapsedReps: Int`) and feeds them to `currentPlateauIndex` as reinterpreted
"bars". A fractional rep position — the playhead's fraction through the loop region, which the run
driver already knows — is a prerequisite for this section, not an implementation detail.

Ear-training blocks have no ramp (ADR 0104 Slice 2) and are unaffected.

## Build slicing

The visual carriers and the audible one turned out to have very different cost and risk, so they
shipped apart.

**Built:** the pure `PendingTempoChange` derivation and `pendingChange(…)` on both ramps (§1), the
one-bar window and its half-plateau clamp (§2), the `off`/`show` setting (§3), the caption, staircase
pre-light and drill-surface edge (§3, §3a), and the ramp-end boundary (§4). None of it touches the
audio path or changes any existing behaviour; `TempoChangeWarning` ships with two cases rather than
three, so the UI never offers a mode that does nothing.

**Deferred:** `sound`, and with it §5 and §6. Those are the whole risk budget — new engine state
threaded through `engageAutomator`, a stale-origin invalidation path on mid-run signature changes, and
a deliberate regression that costs a strum drill its pattern for a bar. All of it needs device
verification on the audio path, which is this project's most expensive loop.

**The reason the split works** is that the visual carrier is better aimed than it first appears. Four of
the five run configurations — fretboard, strumming, chords, strum-chords — are *screen-directed by
design*: the player is already watching the surface the edge lands on. The case for the audible carrier
is the plain untemplated metronome exercise and loop practice, where the eyes are on the hands. So the
cheap third of this ADR covers most of the app, and the expensive two-thirds serves the rest. Whether
that rest is worth the audio surgery is a question practice with the shipped half can answer.

**§7 is unbuilt but safe rather than broken.** A loop ramp keys on whole passes, so a one-pass
plateau's clamped window (half a pass) cannot be reached by an integer rep count and those plateaus
stay quiet — the always-lit failure the clamp exists to prevent. The four-pass command dwell does warn,
on its final pass, which is correct behaviour and is pinned by a test. Nothing needs the fractional rep
position until the rest of §7 is built.

## Consequences

- **No stored model change** — one `UserDefaults` key, no `@Model` field, no migration, additive to
  the privacy manifest's existing UserDefaults declaration (CA92.1).
- **New pure surface to test**, and it must be: `pendingChange(…)` across both units, at plateau
  boundaries, at the ramp's end, on a one-plateau ramp, and on a flat/disabled automator; plus the
  bars-remaining conversion, the half-plateau clamp at `intervalCount = 1`, the scheduled-beat boundary
  from §5, and the mid-run signature change that invalidates the captured tick origin.
- **Three files are at or near the 400-line cap and cannot absorb this**, so the split is decided up
  front rather than discovered under a failing `--strict` lint:
  `StandaloneMetronomeEngine.swift` is at **399** — the engage-tick state and the warning derivation go
  in `+Automator` or a new `+Warning` split, never the core file; `ExerciseRunView.swift` is at **377**
  (it already has `+Ramp` / `+Actions` to extend); `SettingsView.swift` is at **387** (the row goes in
  a section file, as `MetronomeSoundSection` and `NoteSpellingSection` do).
- **Accessibility is part of the feature, not a follow-up.** The drill-surface edge and the staircase
  pre-light are both silent to VoiceOver, so on their own `show` would deliver nothing to a
  screen-reader user. The readout caption is the redundancy that makes the set sufficient: it must
  carry the warning as *text*, and the live readout's `.accessibilityElement(children: .contain)` must
  surface it rather than flattening it away. This is why the caption is a decided carrier and not
  merely the fallback one. **Colour vision is not a requirement** — §3a's edge signals by presence, not
  hue — so the accessibility burden here is VoiceOver only.
- **One new modifier on `ExerciseTemplateSurface` covers all five run configurations**, so no drill
  view changes and the carrier cannot diverge between drill kinds. `LoopRunView` needs its own.
- **The click's voicing gains a second conditional branch.** `scheduledLevel` stays the one place it
  is decided, but its precedence chain is now four deep and needs the order asserted in tests rather
  than left to reading order.
- **A strum drill's pattern is interrupted for one bar** per plateau in `sound` mode. Accepted, and
  the reason `show` is the default.
- **Free play benefits too** — the linear automator in `MetronomeAutomatorPanel` gets the same warning
  through the same `TempoRamp` conformance, with no panel-specific work.
- **ADR 0070 is untouched.** Nothing here observes the player.

## Alternatives considered

- **A configurable window (1/2/4 bars).** Rejected. The backlog entry asked for the feature to be
  "configurable in Settings", and it is — on/off and how loudly. But the *length* is a musical
  constant, not a taste: less than a bar is not enough time to prepare, more than a bar means the
  warning is showing during most of a short plateau and stops reading as a warning at all. A setting
  here would mostly let players configure the feature into uselessness.
- **A distinct new click sound for the warning.** Rejected — a new sample interacts with `ClickTimbre`
  (ADR 0114), which would have to grow a warning voice per timbre. Re-accenting the existing voice
  costs nothing and is at least as legible.
- **A countdown of numbers on screen ("4 · 3 · 2 · 1 to 96").** Rejected — that is the count-in's
  grammar, and reusing it for a *mid-run* event would make the two indistinguishable at a glance,
  which matters because they mean opposite things (one is "not yet", one is "very soon").
- **The beat dots as the in-gaze carrier.** Rejected on fact, not taste: `BeatIndicator` is only
  rendered in `ExerciseTemplateSurface`'s fallback branch, so it is absent from every templated drill
  (§3a). It would have shipped a carrier that works on the plain metronome and nowhere else.
- **A pulsing tint on the drill surface.** Rejected — a pulsing carrier is itself a visual metronome,
  and being motion it falls under Reduce Motion, disabling it for players this feature exists to
  serve. Static costs nothing and is exempt by construction. (Amended by ADR 0157: this rejection
  also cited `exerciseAnimates` defaulting off, which is no longer true. The rejection stands.)
- **Swapping the drill views' existing `tint:` for the window.** Rejected — the smallest possible
  change, but on a fretboard drill the tint colours the note dots, so the warning would overwrite
  information the player is reading. Additive edge, not a repaint.
- **Warn only on rises, not on the backoff.** Tempting — a slow-down is easier to absorb. Rejected: the
  backoff exists so the session ends on clean control, and being dropped 12 BPM unannounced is exactly
  the scramble that spoils it.
- **Make the warning always on, no setting.** Rejected — the app's standing rule is opinionated
  defaults, everything overridable, and a player who wants the ramp to test them is making a
  legitimate (and research-defensible) choice.
- **Build the fade in this ADR.** Rejected — the fade needs its own decisions (how many bars, where
  the schedule is authored, whether `microRestEvery` from ADR 0014 R4 is the carrier). Fixing the
  precedence rule now is what the two actually need to share.
