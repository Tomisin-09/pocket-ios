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

- **Bug: loop Type won't change.** The edit sheet's **Type** picker
  (Lick / Riff / Chords / Passage, ADR 0036) doesn't apply a change. Shipped
  last in 0036, so likely a binding/regression in `SongEditSheet`/loop edit.
- **Loop tags — show existing as well.** Tag suggestion chips (ADR 0034)
  suggest tags from *other* loops; verify the tags already **on this loop** are
  surfaced clearly when editing, and that the in-use list is discoverable.

## Notes & journal (next up — pre-planner V1 work)

A two-tier record on both songs and loops, user-editable from day one (AI
summaries come later — see Release sequencing):

- **Song notes:** a general summary **and** a timestamped journal log.
- **Loop notes:** same shape (summary + timestamped log), with **two access
  points** — the loop row and the automator ("A" control).
- This is also a planner input later (session history / intent), so the data
  model should anticipate that even though the planner is V2.
- Foundation in ADR 0012 (journaling was scoped there); needs its own build
  slices + likely an ADR for the notes/journal data model.

## Loop & marker creation

- **Markers auto-name like loops (reversal of ADR 0019).** Today loops are
  created instantly with an auto-name (ADR 0019) while markers force a naming
  step ("a marker *is* its label"). Decision: markers should also set with a
  **standardised auto-name**, renameable later via loop/marker settings — the
  naming step becomes non-obligatory. This unblocks step 2 of the creation
  method below. Needs an ADR amending 0019.
- **A/B ephemeral span ("not saved").** A transient A↔B selection the musician
  sets on the fly to rehearse **several consecutive saved loops together as
  one**, without persisting a new loop. Distinct from saved region loops
  (ADR 0006); think scratch/rehearsal span. Net-new.
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
