# Exercise-vs-routine presentation cleanup

From a design-board review 2026-07-11 (Chromatic Warm-up screenshots + notes). Origin problem, in
the user's words: *"I'm getting confused differentiating between the exercises in the exercise
library vs the exercises within a specific routine. I feel like they present themselves differently
but I can't find a way to know that for sure."*

**Not yet branched. Plan only — decisions locked below, no code written.**

---

## Why the confusion is real: there are three surfaces, not two

| # | Entry point | View today | Behaviour today |
|---|---|---|---|
| 1 | Tap exercise in the **library** | `ExerciseRunView` (`routineContext == nil`) | Full editor: editable Practice Settings, staircase, **promote**, Save, **Journal**, **Start training**, ‹ back, ⓘ |
| 2 | Tap a **block in a routine** (pre-start) | `ExerciseBlockPreview` (`RoutineBlockPreview.swift`) | **Read-only**: content, `working → command · reach`, staircase, **"Hear command tempo"**, ⓘ. No promote/Start/journal/edit |
| 3 | **Mid live session** (after Start) | `ExerciseRunView` (`routineContext != nil`, via `RoutinePlayerView:169`) | Same full editor as #1, **plus** progress strip + ✕ close; Journal hidden (`ExerciseRunView.swift:98`) |

The confusion isn't imaginary and it isn't "they look the same":
- **#2 is clearly distinct** — read-only, "Hear command tempo." (Already shipped, ADR 0071 R4b.)
- **#3 is nearly identical to #1** — same `ExerciseRunView`, same editable settings, promote, Start.
  The only deltas are the top progress strip and ✕-vs-‹.

So the user is mentally merging #2 and #3 into "the routine version," but they behave completely
differently. #3 being a near-clone of the library screen is the actual source of the unease.

---

## North star (decided 2026-07-11)

**One rule that makes the surfaces legible:** *the exercise editor lives in the library. Inside a
routine, tempo is the only knob, and ⓘ is purely informational — everywhere.*

Concretely:
- **Library (#1)** = the **only** full editor (settings, promote, Start, journal). Unchanged in
  spirit; ⓘ becomes info-only (see Slice 1).
- **Routine (#2 and #3)** collapse to the **same restrained behaviour**: read-only content + the
  tempo nudger, nothing else editable. #2 already is read-only; #3 loses its full editor. This is
  the user's explicit call ("mid-session → tempo-only, like the preview").
- **ⓘ detail sheet** becomes **informational only** in every context: description → progress →
  feel, tempo removed, shape/content editing removed. It stops being a second editing surface.

### Decision record → **ADR 0077** (drafted: `docs/decisions/0077-exercise-vs-routine-editing-boundaries.md`)
This **reverses part of ADR 0071 R4**, which deliberately added command/reach editing to
`ExerciseDetailSheet` for a single canonical write path (`promoteCommand`). We're keeping the single
write path but relocating *where* it's exposed:
- tempo editable on the **library run screen** and on the **in-routine surface**, never in ⓘ;
- ⓘ reverts to read-only (its pre-R4 role) as a pure reference sheet.

It also **narrows ADR 0071**: the live session no longer reuses the full standalone editor for
exercise blocks — mid-session an exercise is tempo-only. And it **reverses ADR 0065's Watch rule**
(Slice 3): Watch flips from always-visible/motion-agnostic to hidden-when-animation-is-on. ADR 0077
records all three reversals and the "library = only full editor" rule.

**Scope: exercises only (decided 2026-07-11).** Everything below applies to **exercise** blocks.
**Loops keep their current presentation as-is** — the in-routine collapse (Slice 2), the ⓘ reformat
(Slice 1, which is `ExerciseDetailSheet`), the board toggles (Slice 3, a fretboard concept loops
don't have), and the promote rethink (Slice 4) do **not** touch loops. Loop in-session consistency
is a separate future call, not part of this batch.

---

## Slices (one branch each, sequential, off `main`)

### Slice 1 — ⓘ becomes informational only + reformat *(keystone, cheap)*
The change that makes everything else coherent; do it first.
- `ExerciseDetailSheet`: **remove `ExerciseTempoSection` (tempo edit) only.** Sheet becomes:
  **Description → Progress (mastery, last practised) → Feel → read-only routine staircase**. Reorder
  to description-first, progress-second; tighten vertical spacing to match `NewExerciseSheet`'s field
  rhythm. Only the `commitCommand` / `commitReach` helpers drop here.
- **Do NOT remove the content editors in this slice.** `FretboardRunEditor`, `StrumPatternEditor`,
  `ChordProgressionEditor`, etc. today live *only* in ⓘ. Deleting them before Slice 3 has built their
  new board home would leave shape editing **homeless** (no way to edit an exercise's content
  anywhere). So they stay in ⓘ through Slice 1 and are relocated-and-removed in a single Slice 3
  commit. Tempo is safe to remove now — the library run screen already hosts Practice Settings.

### Slice 2 — in-routine surface is tempo-only (#2 and #3 unified) *(the actual fix)* — **SHIPPED (branch `pocket-126-in-routine-tempo-only`)**
Built 2026-07-11. Resolved the two open questions below: **#3 keeps its ramp running** (only the
*editor* is stripped, not the metronome), and **tempo is nudged pre-start only** (read-only live BPM
once running). Architecture: a shared `RoutineTempoNudger` (command + reach editable, working +
meter read-only) hosted by both surfaces — `ExerciseRunView` is gated on `routineContext != nil`
rather than forking into a second view, so #1 and #3 are no longer near-clones. #2's nudge writes
straight to the model; #3's commits on Start. The redundant pre-start "Hear command tempo" audition
was **omitted from #3** (Start plays the real click a tap away); #2 keeps its audition.

**Device-test refinement (2026-07-11).** Feedback on the first cut: the bespoke tempo-only nudger was
too restrictive. Revised so both routine surfaces use the shared collapsible **`PracticeSettingsPanel`**
(tempos + step granularity, collapsed by default) instead — the library-only affordances (promote,
Save, journal, meter) still drop out, but the ramp *shape* is tunable. `RoutineTempoNudger` was
removed. This also surfaced that **dwell** (the command-plateau hold) was never user-controllable →
**ADR 0078**: a Dwell count added to the Steps panel for **both exercises and loops**, everywhere the
panel appears (standalone + in-routine). Needed one additive `Loop.rampDwellIntervals` field
(lightweight migration) — verify on device.
- **#2 (block preview):** promote the tempo nudger onto the preview surface itself so
  "routine = only tempo editable" is literally true (today tempo edit hides one layer down under
  ⓘ). Everything else stays read-only.
- **#3 (live session run):** stop reusing the full `ExerciseRunView` editor. When
  `routineContext != nil`, the exercise block renders the **read-only content + tempo nudger + "Hear
  command tempo"**, not Practice Settings / promote / "Start training." Keep the routine chrome
  (progress strip, ✕, chevrons, auto-advance, count-in). Options: a `routineContext`-gated variant
  of `ExerciseRunView`, or route #3 through the same restrained view #2 uses plus the session
  engine. Pick during implementation — favour a single shared in-routine view over two near-clones.
- **Net effect:** #2 and #3 become the same thing (pre-start vs live), and both are unmistakably
  *not* the library screen. Confusion resolved.
- **Exercises only.** Loop blocks keep their current in-session behaviour (`LoopRunView` with
  `routineContext`) untouched — do not gate loop editing on this slice.

### Slice 3 — board-level toggles + relocate the shape editor *(library editor, exercises only)*
Moves fretboard-run shape authoring off ⓘ and onto the board where the effect is visible live, and
thins the toolbar. **This slice removes the content editors from ⓘ** (the deferred half of Slice 1)
so shape editing is never homeless.
- **Add a shape-settings toggle** on the board that opens the run editor (finger pattern, starts on
  fret, across, up/back, advanced) — the panel currently living in `FretboardRunEditor` inside ⓘ.
  Same commit: remove those editors from `ExerciseDetailSheet`, dropping `commitFretboard` /
  `commitStrum` / `commitChords` / `commitStrumChords`.
- **Watch (`FretboardPlayOnceButton`) — flip its gating (reverses ADR 0065, decided 2026-07-11).**
  Today Watch is always shown and deliberately ignores the animate/reduce-motion preference. New
  rule: **hide Watch when `exerciseAnimates` is ON** (the board already walks continuously, so the
  one-shot is redundant); **show Watch when animate is OFF / Reduce Motion** (there it's the only way
  to see the shape move — the escape hatch stays for the users who need it). This declutters the
  common animated case without stranding motion-averse users. Record the ADR 0065 reversal.
- **Sound — remove the "Sound soon" button (decided 2026-07-11).** Correction to an earlier note:
  `SoundPreviewButton` is **not** a working pitch audition — it's a *disabled scaffold*. There is no
  audio backend (`SilentExerciseAudio.isAvailable == false` always), so the button renders greyed-out
  `speaker.slash` "Sound soon" and does nothing. Remove it from its three editors
  (`ScaleRunEditor:55`, `ArpeggioRunEditor:53`, `FretboardDrillEditor:69`) as part of this slice — a
  dead button advertising a feature that doesn't exist.
  - **Keep the `ExerciseAudioEngine` seam** (protocol, `EnvironmentKey`, `AccompanimentSettings`)
    intact — ADR 0065's un-plumbed boundary stays so a real engine slots in later with no call-site
    changes. It just has no UI consumer for now; that's fine.
  - The routine surfaces' **"Hear command tempo"** (`CommandTempoPreviewPlayer`) is a *different*,
    genuinely-working metronome click — **it stays.**
- **`Display`** (label mode) stays.
- **Exercises only** — loops have no fretboard toolbar, so nothing here touches them.

### Slice 4 — rethink promote timing + framing *(own slice, real behaviour change)*
Independent; can ship anytime after Slice 1.
- **Problem (user):** mid-drill nobody taps "I own 106 now — promote"; they're playing. And "target
  tempo" reads as confusing.
- **Half-done already:** the term was renamed **target → reach** app-wide (footers say "summit at
  the reach"); only the promote button still carries the old framing.
- **Change:** surface the promote *after* a run completes as an opportunity to **bump the command
  tempo** ("You just held 100 — move command up?"), rather than an in-setup "do you own the reach?"
  prompt. Weightlifting analogy the user cited: command = working weight, reach = 1-rep-max.
  Applies to the **exercise** "I own X now — promote" affordance. **Loops keep as-is.**
- Needs its own micro-decision (post-run prompt copy + when it triggers); note in ADR 0077 or a
  short follow-up ADR.

---

## Sequencing
`ADR 0077` → **Slice 1** (keystone) → **Slice 2** (the fix) → **Slice 3** (board toggles) →
**Slice 4** (promote). Slices 3 and 4 are independent of each other; 1 and 2 are the ordered core.

### Resolved (2026-07-11)
- **Content-editor homeless constraint** → editors stay in ⓘ through Slice 1; relocated + removed in
  the single Slice 3 commit. No gap where shape editing has no home.
- **Watch gating** → flip it: hide when animate ON, show when animate OFF / Reduce Motion.
- **The board "Sound" button** → it was a disabled "Sound soon" scaffold, not real pitch audio.
  Remove it (folded into Slice 3); keep the `ExerciseAudioEngine` seam for the future engine.
- **Loop scope** → out of scope entirely; loops keep current presentation.

## Deferred — real pitch audition (needs audio resources)
When an audio backend + samples exist, reintroduce a pitch audition, scoped to the **pitched /
harmonic** templates where hearing the notes teaches the shape:
- **Scale, Arpeggio** — hear the intervals; **Chords, Strum & Chords** — hear the voicing.
- **Chromatic warm-up / custom fretboard grid** — mechanical; a click likely suffices, so probably
  *no* pitch audition even later.
Open when we get there: sample set vs synth voice; exact home (per-template, only on the pitched
ones). The `ExerciseAudioEngine.preview(_:tempoBPM:)` / `sound(_:)` hooks are already the slot.

## Open questions
- ~~Slice 2: one shared in-routine view for #2 and #3, or keep them separate?~~ **Resolved: shared
  component (`RoutineTempoNudger`), distinct hosts.** #3 = gated `ExerciseRunView`, keeps its ramp;
  tempo pre-start only.
- Slice 4: exact trigger for the post-run promote (every run? only when the top plateau was held?).

## Not in scope
- **Loops** — no changes to loop presentation in this batch (in-session consistency is a separate
  future call).
- No planner/scoring changes (ADR 0070 stands — the app never grades).
