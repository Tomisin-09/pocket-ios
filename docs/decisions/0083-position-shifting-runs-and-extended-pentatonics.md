# 0083 — Position-shifting runs (fret-shift + slide seams; extended pentatonics)

- **Status:** Accepted (2026-07-12)
- **Date:** 2026-07-12
- **Builds on:** ADR 0065 (exercise content templates; the `FretboardRun` / `ScaleRun`
  generative-authoring model and the `.fretboard` renderer).

## Context

The fretboard template (ADR 0065 build 2) generates a run from a *shape*, not
placed notes. Two of its recipes are relevant here:

- **`FretboardRun`** (warm-up / picking / legato) — a movable finger pattern
  (`1-3-2-4`) laid on **one `baseFret`**, travelling a **string span**,
  optionally up-and-back. Expansion (`FretboardRun.expanded()`) lays the *same
  pattern at the same fret on every string* in the path, so the block only ever
  moves **vertically** (across strings). It never climbs the neck, and it can't
  make a diagonal shape.
- **`ScaleRun`** — a scale placed in **one CAGED box** (`position` 1…5, ~2 notes
  per string). It never crosses boxes.

Two player asks land on the same gap:

1. **Flexible picking/warm-up runs** (notes session, 2026-07-11; refined
   2026-07-12). Make the picking pattern shift, not just duplicate: a *horizontal*
   climb — "shift the frets by *x* after each run" (chromatic-climb-up-the-neck) —
   and a *vertical* diagonal — the pattern lands on a different fret per string.
   Plus a **come-back fingering** choice: today's `roundTrip` does a strict path
   *retrace* (the note sequence reversed), so each string is played **4-3-2-1** on
   the way down; a player often wants instead to **restate** the ascending
   **1-2-3-4** pattern on each string while walking the strings back high→low. The
   "keep the pattern on the descent" shape is not expressible today.
2. **Extended pentatonic shapes.** The player supplied two reference diagrams —
   an A-minor pentatonic connecting **Positions 5 → 1 → 2** as one continuous
   diagonal, and a "Gm Pentatonic — Pattern #4, Extended Structure" that links
   two boxes (frets ~8–10 and ~13–15) with an explicit **slide** arrow between
   them. Both climb the neck diagonally and are stitched together by *same-string
   slides*.

**The unifying observation this ADR rests on:** those are not three unrelated
features. A neck-climbing picking run, a diagonal warm-up, and an extended
pentatonic are all **one run whose anchor fret shifts mid-sequence** — a
`fret-shift + a slide at the seam`. Build the shift once and it produces all of
them; the pentatonic is that primitive pointed at a scale instead of a chromatic
finger pattern. This ADR decides how the shift is modelled, articulated, and
displayed — **additively**, without disturbing any existing run, scale, or the
timing engine.

The animation is essentially free here: `FretboardDrill.activeNoteIndex(atBeat:)`
walks **one expanded cycle** and wraps it forever (`absolute % noteCount`), and
the renderer draws whatever list the expansion hands it. Bake the climb into the
expanded cycle and the walker needs no change. The one real cost is the *fret
window*, addressed in S5.

## Decision

A run may **shift its anchor fret mid-sequence**. The shift is the single new
primitive; everything below is how it is exposed, articulated, generated, and
drawn. Ten rules govern it.

- **S1 — Two shift axes, both additive, both defaulting to today's behaviour.**
  - *Horizontal (climb):* after each completed pass the anchor moves by a fixed
    amount, for a set number of passes, then the whole multi-pass run becomes the
    one wrapping cycle. On `FretboardRun`: `fretShiftPerPass: Int = 0`,
    `passCount: Int = 1`.
  - *Vertical (diagonal):* the anchor gains a per-string offset as the run
    crosses strings, so the pattern lands higher (or lower) on each successive
    string. On `FretboardRun`: `fretShiftPerString: Int = 0`.
  - **A "pass" is one complete `sequence()` at the current anchor** — its
    up-and-back *included* when `roundTrip` is on (do the shape, then climb, then
    do it again). Passes stack upward; the concatenation of all passes is the one
    wrapping cycle. The two axes compose — a climbing run may also stagger per
    string — and either axis alone or both together is valid.
  - Defaults `0 / 1 / 0` reproduce today's run exactly. New optional fields ⇒
    decode-time default, **no store migration** (the ADR 0065 T4 rule); the
    `FretboardRun.version` bumps with a decode-time upgrade only if an older blob
    must be reinterpreted (it need not — absent fields decode to the defaults).

- **S2 — A slide articulates a *same-string* shift, and only that.** When a shift
  keeps the hand on one string and walks it up (or down) the neck — a genuine
  slide, and the "arrow" in the reference diagrams — the note slid *into* carries
  `FretTechnique.slide` (the enum already exists; no new technique). When a shift
  is realised by **crossing to a new string** (the diagonal per-string case,
  where you simply fret the next note in a new position), it is an ordinary
  repositioned note, **not** a slide. This keeps the articulation, and the
  accessibility read, honest — a slide is only drawn where the finger actually
  travels the string.

- **S3 — `FretboardRun` exposes the shift as player-authored controls.** The
  picking/warm-up/legato editor (`FretboardRunEditor`) gains, below the existing
  base-fret/span/up-and-back controls:
  - a **"shift up after each run"** stepper (`fretShiftPerPass`, e.g. +1, +2) with
    a **passes** count (`passCount`) — the "shift-frets-by-x-after-a-run" toggle
    the player asked for, off (0 / 1 pass) by default;
  - a **"stagger per string"** stepper (`fretShiftPerString`) for the diagonal.
  Expansion bakes `passCount` passes — each anchored at `baseFret + pass ×
  fretShiftPerPass`, each string offset by `string-step × fretShiftPerString` —
  into one wrapping sequence, emitting the S2 slide at each same-string seam. The
  live preview and the run screen are unchanged (they read `run.expanded()`).
  **Progressive disclosure keeps the surface calm:** pattern / base fret / span /
  up-and-back stay the primary face; `returnStyle` (S9) and both shift steppers sit
  under a **"Movement"** disclosure beside the existing Advanced/subdivision one, so
  a plain warm-up is still four taps and the power controls are one tap away (the
  ADR 0065 over-busy-editor caution).

- **S4 — `ScaleRun` gains a `layout` axis (the scale side).** A
  `layout: ScaleLayout` axis with three note-placement rules that share one
  generator/property-test/editor/viewport substrate:
  - *`.box`* (today's single CAGED position, the **default**);
  - *`.extended`* — **generates** the diagonal position-connecting shape: start in
    a chosen position and climb through adjacent CAGED boxes, linking them with the
    S2 same-string slides — reproducing the two reference diagrams by construction
    (a shape is picked, never hand-drawn — the ADR 0065 "generated, not placed"
    rule). The "which extended shape" choice is an anchor position, not new
    geometry; the two diagrams are two anchors of the one generator. Pentatonics
    first (where the extended vocabulary lives).
  - *`.threePerString`* — three scale tones per string across the neck; its own
    regular placement rule (not a CAGED box). Ships **plain** (ascend/descend,
    up-and-back) — a legitimate drill on its own; **sequencing** is *not* part of
    it (see below).
  - **Reconciling with the existing `position` / `octaves` fields:** `.extended`
    and `.threePerString` read `position` as the **starting anchor** and define
    their own intrinsic neck reach; `octaves` is **ignored and hidden** in those
    editors (an extended/neck-spanning shape is not octave-bounded). Only `.box`
    uses `octaves`.
  - **Sequencing is a separate, orthogonal, deferred axis — not a `.threePerString`
    feature.** Grouping the notes (3s / 4s / 6s for legato and picking speed)
    applies to *any* layout (you can sequence a box scale too), so it is modelled
    later as its own axis over all layouts, never bolted onto 3-NPS. Named in
    "Open questions"; not built here.

- **S5 — The board follows the hand for climbing runs (the one real cost).**
  Today `FretboardDrill.displayLowestFret` / `displayFretSpan` compute a **single
  static window** spanning every note in the drill. A run that climbs fret 1→12
  would render a cramped whole-neck board. For a run whose fret span exceeds a
  comfortable window (~5–6 frets), the visible window must **track the active
  note** (scroll/anchor to the current pass or the sounding note's neighbourhood)
  rather than show the whole span at once. This is shared work — every climbing
  run and both extended pentatonics need it — and it is the only piece that is
  not free. Non-climbing runs (today's, and modest ≤5-fret diagonals) keep the
  static window unchanged.

- **S6 — Expansion and generation stay pure and unit-tested.** All of it —
  `FretboardRun.expanded()` with shifts, `ScaleRun.extended` generation — stays
  SwiftUI-free and Foundation-only (AGENTS.md: pure logic stays pure), extending
  the existing test nets: for runs, that a shifted cycle has the expected length
  (`passCount` × single-pass length) and carries `.slide` only at same-string
  seams; for extended scales, the ADR 0065 property net (every note in-scale,
  strictly ascending across the climb, slides only where the box changes on one
  string). Generation is the safety net that lets S4 ship curated content
  correctly by construction.

- **S7 — Extended shapes are common-practice vocabulary, authored in-house (T8
  carryover).** Extended pentatonic geometry and chromatic climbs are generic
  pedagogy, not anyone's protected expression — safe to encode. All copy, labels,
  and the curated seeded set stay ours; no third-party diagrams, tab, or prose
  enter the payloads (the content strategy, ADR 0065 T8).

- **S8 — The slide/shift animation must *teach*, shared with the movable-chord
  work.** The slide is the *point* of these shapes — the reference diagrams draw
  it as an arrow, not a dot. So a shift may not render as a note that merely
  blinks on at the new fret; the walking highlight must convey the *motion* along
  the string (a brief travelling/leading cue between the two frets). This is the
  **same open question** logged for the movable-chord "slide-to-fret" slice
  (`docs/backlog.md`): how to present a slide so it instructs rather than just
  displays. Solve it once here and reuse it for chords. Gated by the existing
  animate / Reduce-Motion preferences like every other walking cue (ADR 0065
  T5/0077) — the teaching cue is motion, so it degrades to a static "slide"
  articulation badge when motion is off.

- **S9 — Come-back fingering is a choice (`returnStyle`; refines S1/S3).** When
  `roundTrip` is on, a `returnStyle` picks how the descent is built:
  - *`.retrace`* (default — preserves today's expansion, so the shipped
    chromatic-warmup preset stays byte-identical) — the strict palindrome: the
    ascent note-path reversed, each string played **4-3-2-1** on the way down.
  - *`.restate`* — the ascending finger pattern **restated** per string while the
    strings are walked back high→low: each string still **1-2-3-4**, string order
    reversed.
  Applies only when `roundTrip` is true; `.retrace` when it is off is a no-op.
  Additive optional field, decode-time default (S1). **Seam handling is the build
  detail to unit-test:** `.restate` must skip the peak string (just played on the
  ascent) and de-duplicate the home note at the loop seam the way `.retrace`
  already drops the shared peak and start — otherwise the descent's last string
  double-hits the ascent's first at the wrap. The editor surfaces `.restate` as an
  easily-picked option (it is the more common physical habit) without changing the
  default. Composes with the S1 shifts — a climbing run can retrace *or* restate
  each pass.

- **S10 — Shifts stay on a real neck (bounds & caps).** A climb (`passCount ×
  fretShiftPerPass`) or a downward diagonal can run a note off the fretboard
  (fret > 24 or below 0). Generation clamps every note to a real neck, and the
  **editor caps `passCount`** so the top pass still fits — it will not let a player
  add a pass that falls off the board (friendlier than silently clamping a run into
  a wall). An open string (fret 0) produced by a downward shift is left as a valid
  open note. The same cap logic guards `.extended` / `.threePerString` reach in S4.

## Build order (slices)

1. **Shift primitive + come-back fingering on `FretboardRun` (S1–S3, S9) + the
   slide-seam cue (S8).** The cheapest, theory-free start — chromatic climbs,
   diagonals, and the retrace/restate descent only. It proves the whole idea
   end-to-end and makes the shift *visible* (the player sees the climb walk) before
   any scale generation is committed. Recommended first because it de-risks S8's
   "teach the slide" question on the simplest content. (`returnStyle` is small and
   independent — it could ship on its own even ahead of the shift work if the
   spider-descent choice is wanted sooner.)
2. **Following viewport (S5).** Once a run can climb, the board must follow. Shared
   substrate for everything after.
3. **`ScaleRun` layout axis — `.extended` + `.threePerString` (S4, S6, S10).** The
   theory-heavy piece: the `layout` axis with both new placement rules generated
   over the now-proven shift + slide + follow substrate, each guarded by the ADR
   0065 property test. `.extended` reproduces the two reference diagrams; a plain
   `.threePerString` ships alongside it (same axis, viewport, and test net — its
   note-placement function is the one genuinely new bit, and it's regular). Seeded
   presets land here (e.g. "A Minor Pentatonic — Extended"). If this slice starts
   feeling heavy, `.threePerString` cleanly splits into a fast-follow 3b with no
   rework — but it is planned *in* this slice. **Sequencing is not in scope** (its
   own future orthogonal axis, S4).

Slices 1–2 are buildable now with no scale theory; slice 3 depends on both.

## Consequences

- **One primitive, three features.** Flexible picking runs, diagonal warm-ups, and
  extended pentatonics all fall out of `fret-shift + slide seam`. No parallel
  models; `ScaleRun.extended` reuses the run-side shift rather than inventing
  box-crossing logic of its own.
- **Fully additive.** Defaults reproduce every existing run and scale; no store
  migration, no touched exercise, the timing engine untouched (S1, ADR 0065 T4).
- **The viewport is the real work.** S5 is the only non-free piece and the only
  renderer change; it is deliberately isolated to its own slice so slices 1 and 3
  don't each re-solve it.
- **`FretTechnique.slide` finally gets a producer.** The enum has existed since
  ADR 0065 with no generator emitting it; S2 makes it earn its place.
- **Editor surface grows.** `FretboardRunEditor` gains two shift controls; the ADR
  0065 caution about an over-busy authoring surface applies — the shift controls
  default off and stay out of the common path (a disclosure or a compact row),
  so a plain warm-up is still four taps.

## Alternatives considered

- **Deferring 3-NPS entirely (an earlier draft's position).** An earlier draft
  parked 3-notes-per-string as a future case, on the reasoning that a plain 3-NPS
  run "hides the point" without sequencing. That over-stated it — a straight
  ascending/descending 3-NPS run is a legitimate, valuable drill on its own. So the
  **layout** folds into slice 3 (S4); it rides the same generator/viewport/test-net
  substrate, its only new work being a regular note-placement function. What is
  genuinely deferred is **sequencing** — and the key realisation is that sequencing
  is *orthogonal to layout* (you can sequence a box or extended scale too), so it is
  modelled as its own future axis over all layouts, **not** a 3-NPS appendage. Both
  reference diagrams the player supplied are still the **diagonal** kind, which
  `.extended` models; 3-NPS is the complementary vertical layout.
- **A bespoke "extended pentatonic" recipe separate from the run shift.** Rejected
  — it would duplicate the shift/slide logic the picking runs already need, and
  miss that the two features are one primitive (the whole point of this ADR).
- **Hand-placed extended shapes via the `.custom` grid escape hatch.** Works today
  but makes the player do the teacher's job (ADR 0065's rejected placement model)
  and can't be transposed or re-keyed; generation (S4) is picked, correct by
  construction, and one line per anchor.
- **A single free "climb per note" field instead of per-pass + per-string.**
  Rejected as too abstract to author — a player thinks in "after each run, go up
  X" and "stagger across strings," which S1's two named axes map to directly.

## Open questions (to settle at build time)

- **S8 slide-teaching cue** — the exact travelling-highlight treatment (shared
  with movable chords); the deciding factor for slice 1's feel.
- **S5 follow behaviour** — hard scroll vs. anchored window vs. per-pass jump;
  which reads best on a phone-width board for a diagonal that also moves
  vertically.
- **`.extended` anchor vocabulary** — how many curated extended anchors to seed
  and how to name them (the reference diagrams' "Pattern #4" numbering vs. the
  CAGED shape-letter labels ADR 0065 slice 5 already surfaces).
- **Sequencing axis (future, out of scope here)** — the orthogonal grouping layer
  (3s / 4s / 6s over any layout): its own model, editor, and how the grouping reads
  in the walking animation. To be its own ADR when scheduled.
