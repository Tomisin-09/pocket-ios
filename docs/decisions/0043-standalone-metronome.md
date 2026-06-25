# 0043 — Standalone metronome with exercise presets

- **Status:** Accepted
- **Date:** 2026-06-25

## Context

ADR 0026 built the in-song click and explicitly deferred a **standalone**
metronome: own tempo, no song clock to ride. It named the parts that would carry
over unchanged — `ClickVoice` (the AVFoundation voice) and `MetronomeSchedule`
(the pure scheduler) — and parked the tool "until the homescreen / navigation
exists … incorporated with warm-up routines rather than hung off the Library
toolbar."

We're building it now, ahead of that home surface, because the standalone
metronome carries its own product idea that doesn't need a home screen to be
useful: **savable presets, where a preset *is* a practice exercise.** Most
metronome apps treat tempo as ephemeral — you re-dial it every session. The value
here is the opposite: "Alternating picking" and "Spider" are not settings, they
are named, persistent things you return to, each with its own working tempo. A
preset list *is* an exercise library.

That reframing also gives progress tracking for free. Each exercise holds a
**current working tempo** (where you practise today) and a **target tempo** (the
goal you climb toward). The gap between them is the progress signal — no audio
engine, no waveform, no journaling infrastructure required. This is the "light"
progress model (locked with the user): the number moving over time, not a logged
per-session history. A logged-history/trend view is deliberately out of scope and
belongs with the V2 planner, which these presets become natural inputs to.

Benchmarking the field (Frozen Ape's *Tempo*, 2026-06-25) confirmed three
controls a practice-grade metronome is expected to carry beyond bare tempo: a
**tempo automator** (ramp the BPM up over time), a **session tracker** (how long
you've been at it), and a **visible beat indicator**. The user called the
automator and tracker as important as the tempo control itself, which reverses
this ADR's original decision to defer the automator. They are folded into scope
below.

### A vocabulary collision to avoid

`Loop.commandTempo` already exists and means *the fastest tempo the player has
**measured** they own a loop at* — an achievement. The user's phrase "command
tempo" in conversation meant a *target they set*. These are different concepts and
must not be conflated. This ADR keeps them distinct: the exercise's user-set goal
is **`targetTempo`**, and its day-to-day working value is **`currentTempo`**. The
term "command tempo" stays reserved for the measured-achievement meaning.

## Decision

### Reuse the engine; add only a generator

The standalone metronome runs its **own `AVAudioEngine`** (there is no song clock
to share) but reuses `ClickVoice` and `MetronomeSchedule` unchanged, exactly as
ADR 0026 anticipated. The in-song path feeds `MetronomeSchedule` a song's beat
grid; the standalone path feeds it a **generated** beat sequence.

The one new pure piece is that generator: given a BPM, a time signature, and a
horizon, produce ascending `(time, isDownbeat)` pairs (beat interval `60 / BPM`,
downbeat every `beatsPerBar`). That sequence goes straight into the existing
`MetronomeSchedule.upcoming(...)` at `rate = 1.0`, and `ClickVoice` sounds it.
The generator is Foundation-only and unit-tested — it is precisely the UI-free
tempo math the house rule (AGENTS.md) says must have coverage, because it breaks
silently otherwise.

The same generated sequence drives the **on-screen beat indicator** (a flashing
dot per beat, the bar's downbeat emphasised): the visual and the audio read from
one source, so they can't drift, and it gives a silent/visual practice mode and
an accessibility affordance for free.

### A new audio-free model: `MetronomeExercise`

A new SwiftData `@Model`, separate from `Loop` (a `Loop` is bound to an audio
file/region; an exercise has no audio source — overloading `Loop` would leak audio
assumptions into a click-only entity). It follows the established model discipline
(ADR 0011/0012): a `uid: UUID` business id, declaration defaults / optionals so
SwiftData lightweight migration stays additive (the CoreData 134110 rule), and any
enum stored through a `String` backing field (the ADR 0036 enum-attribute rule).

Fields:

- `name` — the exercise ("Alternating picking", "Spider")
- `currentTempo: Int` / `targetTempo: Int` — absolute BPM (no song to be a
  fraction of, unlike `Loop.speed`/`commandTempo`)
- time signature (beats-per-bar + note value) and subdivision
- `accentPattern` — which beats accent (default: downbeat only)
- the **automator recipe** — step size (BPM), interval (a count + a **bars or
  seconds** unit), and ceiling (defaults to `targetTempo`). Persisting it makes
  "Spider" a full practice prescription, not just a number: loading the exercise
  loads its ramp.
- `tags: [String]` — routed through the shared `Labels` canonicaliser, like
  `Loop.tags`
- `notes` — optional free text

The **session tracker is deliberately not a field** — it's elapsed wall-clock for
the current sitting and resets on exit. Persisting accumulated practice time per
exercise is the logged-history infrastructure this ADR scopes out to the V2
planner.

### Reachability — temporary, by decision

There is still no home surface. Per the user, the metronome is reached for now via
a **provisional Library entry** (toolbar/menu), explicitly marked temporary. This
knowingly revisits ADR 0026's "not off the Library toolbar" note: that note stands
as the *eventual* intent (the tool belongs with warm-up routines on a home
screen), but a temporary entry unblocks the feature without waiting on app-wide
navigation. When the home screen lands, the entry point moves and this temporary
hook is removed.

### Three progress clocks, kept distinct

Folding in the automator and tracker means the tool now carries three notions of
"getting better." They are complementary, not competing, and the UI must keep
them legible:

- **Tracker** — how long you've practised *this session*. Ephemeral, resets on
  exit.
- **Automator** — pushes the BPM up *within* a session, automatically.
- **`currentTempo` → `targetTempo`** — where you've climbed *across* sessions.
  The persisted, "light" achievement.

The tie-in: the automator's ceiling defaults to the exercise's `targetTempo`, so
a ramp climbs toward the same goal the cross-session number tracks. For v1 the
cross-session bump stays **manual** (the user nudges `currentTempo` up) — keeping
the light-model promise that nothing auto-rewrites the persisted number. An
"automator suggests a bump" affordance is a later idea, not v1.

### The automator — bar-stepped, a sibling of `AutomatorConfig`

The in-song speed trainer (`AutomatorConfig`, ADR 0013) already encodes the
linear-ramp math, but it ramps a **speed multiple** (× of original) keyed on
**loop passes** — both meaningless for a song-less metronome. The standalone
automator is a **sibling** that reuses the ramp *shape* over different units:
**absolute BPM**, holding at the ceiling (default `targetTempo`). The step
**interval is selectable** — either every N **bars** or every N **seconds**:

- **bars** — the musical unit; falls straight out of the beat sequence we already
  generate (count downbeats elapsed).
- **seconds** — the benchmark's "+10 bpm every 30s"; rides the same wall-clock the
  session tracker already keeps.

So the automator is parameterised by a `(amount, interval, unit)` where `unit` is
bars-or-seconds, and the pure ramp resolves the current BPM from either an elapsed
**bar count** or **elapsed seconds**. Like its sibling it is pure,
Foundation-only, and unit-tested across both units.

### The tracker — ephemeral session time

A wall-clock elapsed readout for the current sitting, shown running while the
metronome plays. It is **not persisted** (see the model note above): it motivates
in the moment without dragging in the logged-history infrastructure reserved for
the V2 planner.

### Subdivisions need a third click level

The benchmark offers sub-beat clicks (eighths, triplets, sixteenths). The beat
generator can emit them, but `ClickVoice` today synthesises only **two** levels —
an accented downbeat (1200 Hz) and a plain beat (900 Hz). Subdivision ticks want
a **third, quieter** voice so the main beats still read through them. That is a
small additive change to `ClickVoice` (a third buffer + a level argument),
sequenced in the subdivision slice rather than assumed away.

### Reuse: tap tempo and the tempo marking

Tap-to-set-tempo already ships (PR #22, `TempoEstimator`); the standalone screen
reuses it rather than rebuilding tap math. The Italian tempo marking ("Andante",
"Allegro", …) is a pure BPM→name lookup — cheap, charming, unit-testable — added
alongside.

## Slices (one PR each)

1. **Beat-sequence generator** — pure `MetronomeBeats` (BPM + time signature →
   `(time, isDownbeat)` pairs) + unit tests. No UI, no audio. Also the pure
   BPM→tempo-marking lookup.
2. **`MetronomeExercise` model + migration** — SwiftData model (name, current /
   target tempo, time signature, subdivision, accent pattern, automator recipe,
   tags, notes) following the 0011/0012 discipline, with model tests.
3. **Standalone metronome screen** — own `AVAudioEngine`, play/stop, BPM control,
   time signature, the running **session tracker**, the **beat-flash indicator**,
   tap tempo (reused) and tempo marking, driving the generator →
   `MetronomeSchedule` → `ClickVoice`. Reached via the temporary Library entry.
4. **Tempo automator** — pure `MetronomeAutomator` (step BPM every N bars *or* N
   seconds, hold at ceiling) + unit tests for both units, wired into the screen
   (the beat sequence supplies bar counts, the tracker clock supplies seconds).
5. **Subdivisions** — generator emits sub-beat ticks; add the third, quieter
   level to `ClickVoice`; subdivision picker on the screen.
6. **Preset list (the exercise library)** — save / edit / delete exercises; tap a
   preset to load its full configuration (tempo, target, signature, subdivision,
   automator recipe) and surface the loaded exercise's name as the screen title.
7. **Light progress** — current-vs-target readout per exercise; manual nudge of
   the current tempo up over time.

## Consequences

- The feature reuses the tested `ClickVoice` + `MetronomeSchedule` from ADR 0026;
  the new logic (beat generator, bar/seconds automator, tempo-marking lookup) is
  all pure and unit-tested, so the audio layer stays thin. Low audio risk.
- Subdivisions are the one change that touches the audio plumbing — a third,
  quieter click level on `ClickVoice` — kept additive and isolated to its slice.
- A new persisted model means a new (additive) migration. Following the 0011/0012
  rules keeps it from wiping the store.
- Three progress clocks (session tracker, in-session automator, cross-session
  current→target) coexist; the design keeps them distinct so the screen reads
  clearly and the persisted "light" number is never auto-rewritten.
- Presets-as-exercises gives a progress signal with no journaling infrastructure,
  keeping the feature inside V1 scope, and leaves the exercises as ready inputs for
  the V2 planner.
- The temporary Library entry point is technical debt by design: it contradicts
  ADR 0026's eventual placement and must be removed when the home screen exists.
  Tracking it here so it isn't forgotten.
- "Command tempo" now has one meaning only (the measured achievement on loops);
  the exercise's goal is `targetTempo`. Keeping the terms distinct avoids a
  semantic merge that would corrupt both.
