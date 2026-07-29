# ADR 0124 — The idle transport skips in seconds; repeat replaces Set BPM; one speed axis capped at 1.5×

- **Status:** Accepted
- **Date:** 2026-07-29
- **Supersedes / amends:** amends **ADR 0030** (the transport's rewind/forward semantics — rewind's
  single-tap restart is withdrawn while no loop is armed) and **ADR 0024** (the "Set BPM" capsule is
  retired as the tempo entry point; the tempo editor now opens from the metronome). Narrows the
  playback-speed bounds set in `TempoMath` and quoted by ADR 0013's automator ramp, ADR 0082's loop
  percent runs and ADR 0071's song play-along.
- **Number note:** 0120 is reserved for the analytics/privacy ADR in `docs/backlog.md` Slice 8.

## Context

Three findings from the on-device pass of 2026-07-28, all on the practice screen's fixed cockpit,
all changing behaviour that has already shipped. They land in one ADR because they compete for the
same two rows of pixels: whatever the transport's outer glyphs mean, and whatever the speed bar's
right-hand slot holds.

**1. Rewind restarted a song nobody wanted restarted.** With a loop armed the rewind/forward pair is
loop navigation (restart · previous · next, ADR 0030) and earns its place. With **no** loop armed
the same buttons are close to useless: forward is disabled outright — cross-song navigation was
reserved for a later branch that never came — and rewind does the one thing already available by
tapping the start of the waveform. Meanwhile the thing a player does constantly while working a
passage, nudging back a few seconds to take the run-in again, has no control at all: it costs a seek
onto a moving waveform, at whatever zoom happens to be set.

Two sheets from the device pass proposed different fixes — **−10/+10 seconds**, and
**jump-between-markers** — and they cannot both own the buttons.

**2. "Set BPM" occupied a permanent slot to solve a first-minute problem.** The speed bar's right
side shows the effective BPM once a tempo is known, and a **Set BPM** capsule until then. So the
capsule is dead weight for the entire life of every song that has a tempo, and the slot has no
second use. Meanwhile the whole-song **repeat** a slow-downer obviously wants — play the song again
rather than stopping at the end — had nowhere to live and did not exist.

The catch is that the capsule, for all its dead weight, is the *only* visible statement that the
song needs a tempo. A fresh import has no grid, no bar lines, no beat snapping and no click until a
BPM exists, and none of those absences explains itself. Whatever replaces the capsule inherits that
job. (Slice 2's **Set the 1** prompt is the *neighbouring* problem — the half-set state after a
BPM-only commit — not this one.)

**3. The speed axis reached 2.0× and nothing useful lived above 1.5×.** `AVAudioUnitTimePitch` with
`overlap = 3.0` is tuned for transient crispness under *slowdown* (ADR 0001/0006); pushed hard the
other way it smears the pick attack that practice is listening for. Every 0.05 of slider track above
1.5× is resolution taken away from the 0.25–1.0 range where the work happens. The bound was also
quoted in four places — the waveform slider (a literal `0.25...2.0`, not even `TempoMath`'s), the
automator ramp clamp, the loop-run percent field and the song play-along's — so "the cap" was never
one number.

## Decision

### D1 — With no loop armed, the outer transport glyphs are timed skips

`−N` / `+N` seconds in the circular-arrow glyphs (`gobackward.10` / `goforward.10`), clamped to the
song. Holding either opens a menu to change the increment: **5 · 10 · 15 · 30 · 1 min**, shared by
both buttons, stored in `AppSettings.Key.transportSkipSeconds` and sticky across songs — how far you
jump is a habit, not a per-song choice. A skip is a **seek only**: skipping while paused stays
paused.

With a loop armed, nothing changes — restart · previous · next, exactly as ADR 0030 shipped them.
The loop is the unit of work there, and stepping between loops is what the buttons are for.

**Marker navigation is rejected** as the alternative reading of these buttons. Moving freely inside
the waveform is the general capability; markers are already reachable by tapping their row in the
Markers panel, and binding the transport to them would make the buttons' behaviour depend on
whether this particular song happens to have markers.

**Rewind's single-tap restart is deliberately sacrificed** in the idle state. It survives where it
matters (a loop is armed), and its idle equivalent — go to the top — is a tap on the start of the
waveform or a drag of the minimap.

### D2 — REPEAT takes the speed bar's right-hand slot; the tempo editor moves onto the metronome

A **repeat-the-song** toggle (`repeat.1`, not the bare `repeat` the transport's Loop control owns)
replaces the Set BPM capsule. It is **session state, not persisted** — like the armed loop it
complements, and wiped on exit with the rest of the session knobs (ADR 0029). It rides the engine's
existing natural-end callback (`onReachedEnd`), which fires only on a straight-through finish, never
on a manual stop or seek and never while a loop is armed. Because of that last point the control
reads **disabled while a loop is armed** rather than silently doing nothing: that loop is already
repeating its own region.

The tempo editor (ADR 0024's tap-tempo / manual sheet) now opens by **holding the metronome**, from
any state. The BPM readout keeps its own long-press, so a wrong tempo is still correctable where
it's displayed.

**The metronome is never a dead button, and it announces the fresh-import state.** Three modes:

| State | Look | Tap | Hold |
|---|---|---|---|
| Grid exists (tempo + the 1) | accent, filled when on | toggles the click | tempo editor |
| Tempo known, no 1 placed | greyed | tempo editor | tempo editor |
| **Tempo unknown** | accent + **`plus` badge** | tempo editor | tempo editor |

The badge is what discharges the discoverability debt the capsule leaves behind: the fresh-import
state must not depend on discovering a hold. The greyed middle state is honest about the click being
unavailable while still offering the fix — the *announcement* for that state is Slice 2's **Set the
1** prompt on the mode line; this is the second door.

Tap and hold are gestures on a plain shape, **not** a `Button` with `.onLongPressGesture` bolted on:
that pairing fires both recognisers on a hold. The loop row (ADR 0041) established the working
idiom — `.contentShape` + `.onTapGesture` + `.onLongPressGesture` — and this follows it.

### D3 — One speed axis, ceiling 1.5×, with a read-side clamp and named rejection

`TempoMath.maxSpeed` goes **2.0 → 1.5**, and it is the *only* place the ceiling lives: the waveform
slider now reads `TempoMath.minSpeed...TempoMath.maxSpeed` instead of its own literal, and the
automator ramp, the loop-run percent field (25–200% → **25–150%**) and the song play-along's already
derive from it. The slow-downer can no longer outrun the ramp it drives.

**Custom numeric entry** lands on the speed readout (tap → popover). The slider is ~130 pt wide once
the readouts and controls take their share, which is not enough track to land on an exact 0.85×.
Parsing is pure (`TempoMath.parse(speedEntry:)`) and accepts a bare multiplier with an optional
`×`/`x` and either decimal separator.

**Out-of-range is named, not clamped.** Typing `2` under a 1.5× ceiling gets "Between 0.25× and
1.50×" and the field keeps what was typed; silently substituting 1.5 would read as the field eating
the keystrokes.

**Stored speeds are clamped on read, not migrated.** No loop, automator ramp or song resume speed in
existence exceeds 1.5× — checked before deciding — so nothing needed rewriting. But `Loop.resumeSpeed`,
`Loop.armingSpeed` and `Song.resumeSpeed` all pass through `TempoMath.clamped(speed:)` anyway, so a
value authored under the old ceiling can never hand the engine a rate the UI can no longer show.

## Consequences

- **`TempoMath` becomes the single speed authority.** Moving the ceiling again is a one-line change
  plus its test; the tests that used to spell `200` now read `LoopRunView.percentRange.upperBound`
  so they move with it rather than pinning a stale number.
- **Two behaviours shipped users would notice are withdrawn** — idle rewind-to-restart, and any
  playback above 1.5×. There are no users yet (v1.0 is approved but distribution is deliberately
  held), so this costs nothing today and would be a much harder call after release.
- **`onReachedEnd` now has two owners** — `SongPlayAlongModel`'s auto-advance (ADR 0071) and the
  waveform's repeat — on different screens with different engines. The waveform clears its hook in
  `endPlaybackSession`, so the callback can't outlive the screen that set it.
- **The speed bar's row is fuller**: readout · slider · BPM · repeat · metronome. The two circular
  controls are packed into one trailing group so they read as a pair rather than each competing with
  the slider for width; the BPM readout collapses entirely when the tempo is unknown, which is also
  the state where the badge appears.
- **`SpeedBar` moved to `WaveformSpeedBar.swift`** — three more jobs pushed `WaveformSections.swift`
  past the 400-line ceiling. Same split as section 8's `WaveformTransportBar.swift`.
- **Both new pure units are unit-tested** (`TransportSkip`, the speed clamp and entry parser). The
  clamping at a song's ends is exactly the behaviour that would otherwise be found by skipping past
  the end of a track on device.

## Alternatives considered

- **Marker navigation on the idle buttons** — rejected under D1; behaviour that depends on whether a
  song has markers, for a target already reachable by tapping the marker's row.
- **Keeping "Set BPM" and putting REPEAT elsewhere.** There is no elsewhere: the speed bar's row is
  full and the transport's four slots are spoken for (Marker, Loop, and the two skips). Keeping both
  would have meant a permanent capsule for a first-minute problem.
- **A context menu on the metronome instead of a hold.** Native and unambiguous, but it turns a
  one-step action into hold → tap for the app's *most common* tempo correction. The hold is worth
  the gesture arbitration care D2 describes.
- **Clamping a typed out-of-range speed silently.** Rejected under D3 — indistinguishable from a
  broken field.
- **Capping only the waveform slider, leaving loop-practice runs at 200%.** Rejected: it keeps the
  ceiling as a per-surface accident and lets the slow-downer disagree with the ramp it drives. One
  concept, one bound.
- **Whole-song repeat as an engine `loopRegion` of `0...duration`.** It would be gapless like the
  loop path, but that path pre-renders and crossfades the whole region into memory — fine for a
  four-bar loop, not for a five-minute song. Wrapping on the natural end costs one schedule gap at
  the seam and nothing else.
