# Backlog

Deferred work that's intentionally parked — known, but not scheduled. Each item
notes enough context to pick it up cold. Promote to a branch (and an ADR if it
closes off an alternative) when it's time to act.

## Release sequencing (decided 2026-06-24)

The order below reflects a deliberate scoping call, not just priority:

- **V1 (first release):** practice screen + library + a richer **creation
  experience** + **notes/journal**. **No planner.**
- **Planner → V2.** Routine generation and goal-driven selection (ADRs
  0014 / 0015 / 0016) are designed but deferred to the second version. Don't
  treat the planner as "next" — notes/journal comes first.
- **AI layer → late phase.** Every AI feature (note summaries, suggested
  automator settings, etc.) is built only once the rest of the app is solid
  and the foundations are in place: the Claude proxy backend (ADR 0002, still
  paper-only) and a settled pricing/cadence model. Cleanly separable from the
  user-editable foundations below — build those first, gate AI behind them.

## Near-term (active, not parked)

These are scheduled to be picked up shortly — listed here so they're not lost.

- **Loop tags — show existing as well.** Tag suggestion chips (ADR 0034)
  suggest tags from *other* loops; verify the tags already **on this loop** are
  surfaced clearly when editing, and that the in-use list is discoverable.

## Notes & journal — DONE (ADR 0038)

Shipped in PR #50: a per-loop **practice journal** (dated entries snapshotting
mastery + command tempo at write time, immutable; typed entry kinds) opened from
a book icon on the loop row, plus **song notes** (free-text `Song.comment`)
editable inline in the song details sheet. Narrowed ADR 0012's three-scope
forecast to loop-only; markers get neither. AI summaries over the journal remain
in the AI phase (below).

## Loop experience (sense-check decided 2026-06-24)

Outcome of a UX review of loop properties + the loop-making flow. Numbering
matches the discussion thread.

**#2 + #4 — DONE (ADR 0039).** The loop row now surfaces **mastery** (dots) and
**command tempo** (a percent badge, the achievement) under the name, shown only when
set — last-practiced speed is *not* shown. The three judgment fields (**mastery,
command tempo, focus**) became Optional with an explicit "unset" state, so a default
never masquerades as a rating (the `1.0` command-tempo "100%" lie is gone). Existing
loops migrated to `nil` for free; `MasteryRollup` skips unrated loops; the edit sheet
gained set/clear affordances (dot walk-down, command-tempo Set/Clear, focus menu).

**#3 — DONE (ADR 0040).** Each loop now remembers the speed you last practised it at
(new `Loop.lastPracticedSpeed`, kept separate from `loop.speed` = automator ramp start to
avoid clobbering it). Persisted on leave via a single `activeLoopID` `didSet` choke point
(not per slider tick); arming a loop — tap or transport skip — restores its speed, falling
back to `loop.speed` when never practised. Session still opens clean (full song, 1×),
refining ADR 0029. The user-defined toggle (loop speed always = command tempo *vs* last
playback) stays V2.

**#6 A/B as the creation primitive — DONE (ADR 0041, branch pocket-054).** The
ephemeral A↔B span is now the single creation primitive: tap A/B to set A then B (or
hold-drag), the span loops with no ✓/✗ gate, its labelled A / B handles drag in place,
**Save as loop** persists it. Dragging a saved loop's edge lifts it back into A/B for a
range edit (**Save changes** writes back), dissolving the three-hop range edit. **Fine
mode and the capture/confirm system were retired** — the transport left column is now
A/B · Marker. Built in 5 slices (pure `ABSpan` state machine → play-along set → handle
adjust → range-edit lift → Fine retirement + hold-drag wiring).

**V2 / planner-era:**

- **#4 test-data seeding** to exercise the planner before real fill-rate exists.
  Validates planner *logic*, not fill-rate — only real usage shows whether users
  actually fill the fields.

**Parked — deliberate, leave as-is:**

- **#5 Multi-select loops:** parked until the friction is real. Useful for bulk
  delete / cleanup and batch re-tag / type / focus, but it's a *scale* feature —
  it only pays off with many loops, or once the planner makes bulk-focus a real
  workflow. At a handful of loops, one-at-a-time editing doesn't hurt, so building
  the selection-mode UI now is speculative. *Inheritance and duplicate were
  considered and rejected* — multi-select is the only bulk move we'd want.
  **Revisit when** one-at-a-time editing starts to hurt, or when the planner lands.
- **#1 Marker→loop bridge:** not needed as an explicit action. Markers already
  snap loop edges during creation (ADR 0021), and a marker is approximate, so an
  "exact marker→loop" would mislead. The passive snap is the right amount.
- **#7 Resume-to-last-loop:** leave as-is (ADR 0029 wipes the active loop on
  exit); revisit via A/B test. Could ride on the `lastPracticed` field cheaply if
  reconsidered.
- **#8 "Loop 1/2/3" naming:** deferred naming (ADR 0019) stays — if a loop's
  unclear you play it to remember, and the glanceable row (#2) lowers the cost
  further.

## Loop & marker creation

- **A/B ephemeral span ("not saved").** A transient A↔B selection the musician
  sets on the fly to rehearse **several consecutive saved loops together as
  one**, without persisting a new loop. Distinct from saved region loops
  (ADR 0006); think scratch/rehearsal span. Net-new. *Note:* the A/B span is now
  also the basis for **#6 (A/B as creation primitive)** above — build the span
  once, serve both the rehearsal and the save-as-loop use.
- **Loops accessible outside their song?** Open question. Today a `Loop`
  belongs to one `Song`. Cross-song access is largely what the **planner**
  delivers (pulling loops across songs into a session) and ties to cross-song
  filter-by-tag (deferred in ADR 0034). Revisit when the planner (V2) lands;
  decide whether anything is needed before then.

## Onboarding — "the art of creating loops" + musician voice

A coherent vision, captured for V1's creation experience:

- **Guided creation flow, onboarding-only and skippable.** An opinionated,
  3-step path layered over the free-form practice screen, shown during
  onboarding; the user can skip it. Implementation approach TBD (the point now
  is to capture intent, not design the mechanism):
  1. **Listen whole** — original tempo, no speed changes. Think about parts you
     liked / want to recreate. Add a **first journal entry** (goals, aims).
  2. **Mark sections** — replay (author suggests ~0.8–0.9× tempo, musician's
     discretion) and drop **markers** on sections of interest. Markers set
     automatically with a standardised name (see marker auto-naming above),
     renameable anytime.
  3. **Create loops** — with the song signposted by markers, build loops from
     those positions (author suggests 50% tempo, playback starting at 50%,
     zoomed in to a set level).
- **Musician voice / ritual (cross-cutting design principle).** Address users
  as *musicians* throughout; use language that helps them internalise the
  identity. Frame **completing the first loop** as a small ritual — the moment
  you "become" a musician — felt via tutorial guides and docs/copy. When acted
  on, this belongs in `docs/design-brief.md` as a voice/tone principle and
  should then govern copy app-wide.
- **Rotary haptic zoom mode (net-new interaction).** A zoom mode where finger
  rotation acts like a physical dial/knob — direction-sensed, reflected in
  haptics (rotate one way to zoom in, the other to zoom out). Alternative/
  complement to pinch-to-zoom (ADR 0010). Self-contained; could ship
  independently of the guided flow.
- **Method provenance guardrail:** this flow encodes a practice author's method
  ("the author recommends…"). Per the content strategy, encode the **method**,
  never ship his words — all copy must be ours.

## AI phase (late — gated on backend + pricing)

Parked until the foundations above are solid (see Release sequencing). Captured
so the intent isn't lost:

- **AI note summaries** over the song/loop timestamped logs — user-editable
  stays; the AI proposes a summary on top.
- **AI-suggested automator settings** derived from a loop's notes/journal (the
  speed-trainer ramp). Loop notes reachable from the automator make this the
  natural surface.
- **Cadence & monetization question (open):** how often should an AI summary
  refresh? Candidate: ~24h (or weekly) on a free tier, daily/hourly behind
  pay — find the sustainable balance without burning backend cost. Decide
  alongside the backend build (ADR 0002).

## UI / polish

- **Fine-tune the song details sheet.** `SongDetailsSheet` (opened by holding the
  song title on the practice screen) currently stands up the read-first overview on
  a plain SwiftUI `Form`. It works, but the presentation is a first pass. Candidate
  refinements:
  - Richer header treatment (artwork? larger title, tighter artist/album/year line).
  - A more bespoke descriptive layout than a stock grouped `Form` — spacing,
    grouping, and typography tuned to the app's design tokens (brief §3).
  - Decide the relationship with the scroll-area `SongInfoPanel`, which shows an
    overlapping subset (key · proficiency · progression · collections) — consolidate
    or differentiate so the two don't drift.
  - Consider inline editing vs. the current Edit → `SongEditSheet` hop.
  - Surface tempo precision / downbeat state if useful (currently shows rounded BPM).
