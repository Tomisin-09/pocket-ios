# 0040 — Loops remember their last-practiced speed (refines 0029)

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

When you slow a loop down to drill it — say 0.7× — then move to another loop and
come back, the speed is gone: you're back at whatever the session speed happens to
be, and you re-slow it by hand every time. The speed you practise a loop at is a
property *of that loop's practice*, not of the sitting, and it should persist with
the loop.

ADR 0029 ("clean on entry, wipe on exit") explicitly **rejected** "persist the last
active loop / speed per song," on the grounds that a sitting should start fresh
rather than resume a stale loop. That call still holds for the **session**: opening a
song must land on the full song at 1× with no loop armed. But it conflated two
different things — *which loop is armed when the screen opens* (session state, rightly
wiped) and *what speed a given loop resumes at once you deliberately arm it*
(per-loop practice memory, worth keeping). This ADR refines 0029 to separate them: the
session still opens clean; individual loops remember their speed.

### The `loop.speed` collision

The obvious move — "make `loop.speed` mean last-practiced" — doesn't work. `loop.speed`
is already the **automator ramp start** (ADR 0013): it's the "Start" field in the
Automator sheet and the floor the speed-trainer ramps up from, written through
`loop.automator`. Auto-overwriting it every time you leave a loop would silently move
the user's deliberately-set ramp floor. The two values update on different triggers
(ramp start = deliberate, in the sheet; last-practiced = automatic, on leave), so they
must be **separate fields**.

## Decision

### New field: `Loop.lastPracticedSpeed: Double?`

A new Optional stores the speed you last practised the loop at (× of original).
`nil` = never practised. `loop.speed` is unchanged — it stays the automator ramp
start. Optional with no declaration default, so pre-0040 loops migrate to `nil`
without a store wipe (the CoreData 134110 rule; optionals are exempt — same pattern
as ADR 0039's judgment fields).

This makes three distinct loop tempos explicit:

- **`lastPracticedSpeed`** — where the loop *resumes* (this ADR).
- **`speed`** — the automator ramp *start* (ADR 0013).
- **`commandTempo`** — the fastest tempo *owned* (ADR 0036/0039, the row badge).

### Persist on leave, restore on arm

- **Persist on leave** via a single choke point: a `didSet` on `activeLoopID` writes
  the *outgoing* loop's current `speed` into its `lastPracticedSpeed` whenever the
  active loop changes — switch, exit-loop chip, transport skip, or screen exit. One
  place, so no leave path is missed, and it fires **on leave, not per slider tick**
  (an in-loop speed change doesn't touch persistence until you leave). A just-deleted
  loop is naturally skipped (it's no longer in `loops`).
- **Restore on arm**: arming a *different* loop (tap its row, or a transport
  prev/next skip) sets `speed = loop.lastPracticedSpeed ?? loop.speed`. The fallback
  to `loop.speed` gives migrated loops a sensible resume (their creation /
  ramp-start speed) until they're practised once. Re-tapping the *already-active*
  loop only toggles play/pause — it never yanks the speed you're sitting at.

### Session entry stays clean (0029 preserved)

The screen still opens on the full song at 1× with no loop armed; `wipeTransientState`
still resets `speed` to 1× on exit. Per-loop memory only takes effect once you
deliberately arm a loop — exactly the "arm by intent" contract from 0029. Creating a
loop keeps the speed you punched it at (no restore on create); its `lastPracticedSpeed`
stays `nil` until practised, and the `?? loop.speed` fallback already covers it.

## Consequences

- A loop you slowed to 0.7× reopens at 0.7×; the per-loop practice speed survives
  across loops and across sittings, persisted on the `Loop`.
- The choke point means every present and future "leave the loop" path persists for
  free — no enumerated list of call sites to keep in sync.
- Three loop tempos now coexist without overloading one field; the automator ramp
  start is no longer at risk of being clobbered by practice.
- The user-defined toggle floated in the sense-check (loop always resumes at
  *command tempo* vs. last playback) is **not** built here — last-practiced is the
  default; the toggle is deferred to V2 (`docs/backlog.md`).

## Alternatives considered

- **Repurpose `loop.speed` as last-practiced** — rejected: it's the automator ramp
  start (ADR 0013); auto-overwriting it on leave clobbers a deliberately-set ramp
  floor. Separate fields keep the two update triggers from fighting.
- **Persist reactively on every `speed` change** — rejected: thrashes persistence per
  slider tick for no benefit, and an in-loop speed change isn't a "decision" worth
  recording until you leave. The leave event is the natural commit point.
- **Enumerate persist calls at each leave site** instead of a `didSet` — rejected:
  ~8 call sites change `activeLoopID`; a list invites a missed path. One choke point
  is correct by construction.
- **Restore at the session level too** (reopen the song on its last loop/speed) —
  rejected: that's the 0029 call we're keeping. The session opens clean; only
  individual loops carry memory.
