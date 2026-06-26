# 0045 — Command-anchored exercise progression (supersedes the 0043 "light" model)

- **Status:** Accepted
- **Date:** 2026-06-26

## Context

ADR 0043 gave a standalone-metronome **exercise** a deliberately *light* progress
model: two absolute-BPM tempos — `currentTempo` ("where you practise today,
nudged up manually over time") climbing toward a freely-set `targetTempo` goal —
plus a plain linear floor→ceiling automator. It explicitly deferred a measured
achievement and any logged history to V2, and reserved the term **"command
tempo"** for `Loop.commandTempo` (the *measured* fastest tempo a player owns a
loop at, as a fraction of song speed). At the time, the user's conversational
"command tempo" meant *a target you set*, so 0043 kept the term off exercises to
avoid conflating an aspiration with an achievement.

Designing the exercise trainer further surfaced a pedagogy the light model can't
express. **An exercise, unlike a loop, has no extrinsic target tempo** — there is
no song section fixing the finish line. The only meaningful reference is the
player's *own current clean ceiling*. Three distinct quantities fall out:

- **Working tempo** — a comfortable warm-up floor, deliberately slow; where a
  session's ramp *begins*. New concept; the light model has no floor.
- **Command tempo** — the fastest the player can play the exercise *clean and
  repeatable*. A measured/owned achievement. This is precisely the established
  meaning of `Loop.commandTempo`, in absolute BPM rather than a song fraction.
- **Target tempo** — command **+ a proportional stretch**; the reach, *derived
  from* command, not freely set.

The user's definition of "command tempo" has converged on 0043's reserved
meaning (a measured achievement), so extending the term to exercises is now
consistent rather than a collision — the reverse of the situation 0043 guarded
against.

This reverses two 0043 choices: `targetTempo` stops being a free goal (it becomes
command-derived), and the model grows from two tempos to three. It also makes the
automator's *shape* command-aware (warm-up → command → brief summit → backoff)
rather than a single linear climb. The logged-history piece 0043 parked for V2
becomes the substrate for **auto-suggested promotion**, designed here but built
later.

## Decision

A two-phase change. **Phase 1 is built now; Phase 2 is designed here so the data
model needs no second migration when history lands.**

### Terminology (canonical, supersedes 0043's two-tempo framing)

| Term | Meaning | Storage |
|---|---|---|
| Working tempo | Comfortable warm-up floor; the ramp's start. | `currentTempo: Int` (existing; aliased `workingTempo`) |
| Command tempo | Fastest clean-and-repeatable tempo owned. The anchor. | `commandTempo: Int?` (new) |
| Target tempo | Command + stretch. The reach. | `targetTempo: Int` (existing; now command-derived) |

`Loop.commandTempo` (a song fraction) and `MetronomeExercise.commandTempo`
(absolute BPM) now share **one meaning** — "fastest clean tempo owned" — differing
only in unit because a loop has a song to be a fraction of and an exercise does
not. This is the alignment 0043 anticipated.

### Phase 1 — model, math, ramp shape, manual promotion (built now)

**Model — additive only (the CoreData 134110 / ADR 0011-0012 discipline):**

Only **one new field** is needed, because 0043's `currentTempo` *is already the
working tempo*: the UI labels it "Working tempo", the bridge seeds it from the
automator's **start** BPM, and the action bar writes it from a `working` value.
0043 simply conflated the warm-up floor and the owned ceiling into that single
"day-to-day" number; this ADR separates them by adding command above it.

- **`commandTempo: Int?`** — the only new field. **Optional, no declaration
  default** ⇒ migrates pre-0045 rows to `nil` with no store wipe (optionals are
  exempt from 134110), exactly like `Loop.commandTempo`. Optional *on purpose*: a
  non-optional default would claim an owned tempo the player never demonstrated.
  Until measured, the effective command falls back to the working tempo
  (`command = commandTempo ?? currentTempo`) — your command is at least where you
  currently practise — so an un-promoted exercise degrades gracefully to the old
  light behaviour.
- **`currentTempo` is the working tempo** — retained as-is (no rename, no
  migration). New code reads it through a `workingTempo` computed alias for
  clarity; storage and every existing call site are untouched.
- **`targetTempo: Int`** — retained, but its role changes from *free goal* to
  *command-derived default*. On promotion it is recomputed from command (below);
  a manual edit still sticks until the next promotion. (A `targetIsPinned` flag to
  make a manual target survive promotions is **Phase 2**; Phase 1 keeps it simple —
  promotion overwrites target.)

**The stretch (pure, unit-tested — AGENTS.md mandates it):**

```
target = clamp( round(command × (1 + p)), command + 3, command + 15 )
```

with `p = 0.06` default. A flat BPM stretch is wrong because difficulty tracks
*relative* change; the clamps stop it being trivial at low tempos and brutal at
the top. Lives as a pure `TempoStretch.target(forCommand:)` (free of SwiftUI /
AVFoundation), the kind of tempo math that breaks silently.

`TempoStretch` is written **unit-generic** — proportional with *caller-supplied*
clamps — so it is reused unchanged by the planned **loop** progression ADR
(0046), where command/target are fractions of original tempo (`×`) rather than
absolute BPM and the clamps are expressed in `×` units. Designing it generic here
avoids forking the math when loops adopt the same working/command/target model.

**Command-anchored automator profile (pure stepping logic, unit-tested):**

The 0043 automator is a single linear floor→ceiling climb. It gains a
command-anchored *profile* that the engine steps through:

1. **Warm-up ramp** — start at `workingTempo`, step up to `commandTempo`.
2. **Dwell at command** — hold command for an extended interval (the bulk of the
   reps). This is where consolidation happens, not an equal-time plateau.
3. **Summit at target** — a brief hold at `targetTempo`. The reach, not the
   destination of every session; reaching it is allowed to be occasional.
4. **Backoff tail** — drop to a tempo *below* command (default `command − stretch`,
   floored at `workingTempo`) and hold, to end the session reinforcing clean
   control rather than the sloppy edge.

The legacy linear ramp remains available; the command-anchored profile is the
default for an exercise once `commandTempo` is set.

**Engagement surface — Training Mode (revises the implicit engagement).** The
first cut engaged the command profile *implicitly* — only when a promoted
exercise happened to load with its automator pre-armed. In use this proved
undiscoverable and produced an incoherent screen: the working/command/target chip
and the free-play automator panel showed three unrelated tempo regimes at once,
and you still had to arm the linear automator by hand. The command-anchored
routine is therefore surfaced as an **explicit Training Mode**: a single entry
(the progress chip becomes its summary + opener) presents working / command /
target and a **Start** that *configures and arms the routine in one action* —
no separate arm step. The free-play **Off / By Bars / By Time** linear automator
stays for ad-hoc tinkering; arming it and starting Training Mode are mutually
exclusive at runtime (the engine carries a command tempo for one, `nil` for the
other). The fixed routine shape (dwell/backoff auto, not exposed) is the
auto/minimal default; the one knob surfaced is **how many intermediate warm-up
steps** to climb through (0 ⇒ jump straight to command), stored as the warm-up
`stepBPM` via the pure `CommandRamp.warmupStepBPM`/`intermediateSteps` pair.

*Edits are local until Start.* Training Mode holds working / command / steps in
view state seeded from the exercise on open, and only writes back to the model
(and saves) when **Start** is pressed — **Close** discards. This is deliberate:
because `command` falls back to `currentTempo` when unmeasured, editing the model
in place made the three tempos move together (lowering working dragged command
down), and a "Done" button read as if it saved. Local state decouples the tempos
while editing and makes the save explicit. *First-open defaults:* with no measured
command, command seeds from the exercise's current tempo and working from
`TempoStretch.warmupFloorBPM` (a clamped proportional drop below command), so the
two start apart rather than equal.

**Manual promotion ("I own this"):** a single action that sets
`commandTempo := <promoted tempo>` (the current target, or a value the user
confirms) and recomputes `targetTempo` from it. No history record in Phase 1 —
just the number ratcheting up, keeping faith with the light model's promise for
one more release while the meaning sharpens.

### Phase 2 — clean-rep history & auto-suggested promotion (designed, built later)

This is the logged-history infrastructure 0043 scoped to V2. Designed now so the
schema is forward-compatible:

- **New `@Model ExerciseTempoMilestone`** — `uid: UUID`, `date: Date`,
  `command: Int`, `kind: String` (promotion / clean-session), with a to-one
  relationship back to `MetronomeExercise` (and the inverse `[milestones]`
  collection on the exercise). Same model discipline: business `uid`, declaration
  defaults, enum-through-`String`.
- Each promotion (and, later, each completed clean session) appends a dated
  milestone — the "banked clean reps" history.
- **Auto-suggested promotion** reads the history to prompt *"you've held 132 clean
  for 4 sessions — promote it?"*. The promotion stays **user-confirmed**: the
  persisted command is never silently auto-rewritten, preserving the spirit of the
  light model even as the suggestion becomes automatic.
- Enables a trend view (command over time) — the V2 planner surface.

## Consequences

- Exercises gain a three-tempo model (working floor / command ceiling / derived
  target) that matches how speed-building actually works, where a loop's
  extrinsic target never applied.
- "Command tempo" now means one thing app-wide — *fastest clean tempo owned* —
  across both loops (song fraction) and exercises (absolute BPM).
- The automator becomes a pedagogy, not just a ramp: dwell at command, summit
  briefly, back off to lock in control.
- Migration is fully additive and minimal: a single new optional field
  `commandTempo`. `currentTempo` (already the working tempo) and `targetTempo` are
  untouched — no store wipe, no rename, no custom migration stage.
- 0043's "Three progress clocks" section and its "nothing auto-rewrites the
  persisted number / no measured achievement on exercises" promise are superseded:
  exercises now carry a measured command, and Phase 2 will *suggest* (never force)
  bumps.
- Phase 1 ships within V1 scope (no history infra); Phase 2's history + trend
  rides with the V2 planner, where 0043 already placed it.

## Alternatives considered

- **Keep the light two-tempo model** — rejected: it can't express a warm-up floor,
  a measured ceiling, or a target that reaches *past* what you own, which is the
  whole point of an exercise with no extrinsic tempo.
- **Anchor target to the working tempo** (the user's first framing) — rejected: the
  working tempo is deliberately sandbagged, so a target derived from it is a tiny,
  arbitrary reach. Target must anchor to *command*.
- **Flat +5–10 BPM stretch** — rejected: doesn't scale (14% reach at 70 BPM, 5% at
  200). Proportional-with-clamps tracks perceived difficulty.
- **Rename `currentTempo` to a new name** — rejected: a SwiftData attribute rename
  is not lightweight-additive and risks the 134110 store wipe the repo guards
  against. `currentTempo` already *is* the working tempo, so it stays put and new
  code reads it through a `workingTempo` computed alias — no migration stage.
- **Build the history now (single phase)** — rejected: the logged-history infra is
  V2-scoped (0043), and the within-session pedagogy delivers value without it.
  Designing the schema here avoids a second migration later.
- **Auto-promote command from the automator** — rejected even in Phase 2: the
  persisted achievement stays user-confirmed; the app *suggests*, the player
  *decides*, preserving the light model's no-silent-rewrite principle.
