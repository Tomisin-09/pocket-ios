# 0077 — Exercise editing boundaries: library edits, routines tune, ⓘ informs

- **Status:** Accepted (Slices 1–3 shipped 2026-07-11; Slice 4 — post-run promote — not started. See
  `docs/plans/exercise-vs-routine-presentation.md`)
- **Date:** 2026-07-11
- **Extends:** ADR 0057 (single write path per model), ADR 0058 (journal authoring on the run
  screen), ADR 0075's override *model* (stored optionals, effective accessors, auto-clear — all
  retained).
- **Reverses / supersedes in part:** ADR 0071 R4 (command/reach editing *added* to
  `ExerciseDetailSheet`) and ADR 0071's reuse of the *full* standalone editor for exercise blocks
  mid-session; ADR 0075 §3 (the reach editor *on the detail sheet*); ADR 0065's Watch rule
  (always-visible, motion-agnostic) and its "Sound soon" `SoundPreviewButton` (removed; the
  `ExerciseAudioEngine` seam is kept). R4b pre-start block previews are **extended**, not reversed.
- **Scope:** **exercises only.** Loops keep their current presentation (see §6).

## Context

The same exercise renders through three surfaces, and they don't read as distinct:

1. **Library** — tap an exercise: `ExerciseRunView` (`routineContext == nil`). Full editor: Practice
   Settings, staircase, promote, Save, Journal, Start training, ⓘ.
2. **Routine block preview** (pre-start) — `ExerciseBlockPreview` (ADR 0071 R4b). Read-only content
   + tempo readout + staircase + "Hear command tempo" + ⓘ.
3. **Routine live session** — `ExerciseRunView` with `routineContext != nil` (via
   `RoutinePlayerView`). The *same full editor* as #1 plus routine chrome (progress strip, ✕), with
   the Journal hidden.

The reported problem (design review, 2026-07-11): *"I'm getting confused differentiating between the
exercises in the exercise library vs the exercises within a specific routine … they present
themselves differently but I can't find a way to know that for sure."* The cause is structural: #2 is
genuinely restrained, but #3 is a near-clone of #1 (identical editor, only a strip bolted on top), so
"the routine version" means two different things. Compounding it, ADR 0071 R4 made **ⓘ a second
editing surface** for tempo — so tempo is editable in three places and ⓘ stops being a place you just
*read*.

## Decision

### 1. One rule: the editor lives in the library; routines only tune tempo; ⓘ only informs

- **Library (#1)** is the **only** full editor — Practice Settings, promote, Start, journal,
  content-shape editing.
- **In a routine (#2 and #3)** the only editable knob is **tempo**. Everything else is read-only.
- **ⓘ (`ExerciseDetailSheet`)** is **informational in every context** — a reference sheet, not an
  editor of tempo or content.

The single write path (ADR 0057) is preserved: tempo still routes through `promoteCommand`; this ADR
relocates *where* that mutation is exposed, it does not add a second path.

### 2. ⓘ reverts to a read-only reference sheet (reverses ADR 0071 R4)

Remove `ExerciseTempoSection` from `ExerciseDetailSheet`. The sheet becomes, in order:
**Description → Progress (mastery, last practised) → Feel → read-only routine staircase**, with
tightened spacing matching `NewExerciseSheet`. Only `commitNotes` / `commitMastery` remain. The
per-template **content editors** (`FretboardRunEditor`, `StrumPatternEditor`, `ChordProgressionEditor`,
…) also leave ⓘ, but **not in the same step** — they relocate to the board (§4) in one move so shape
editing is never homeless (build sequencing in the plan doc).

### 3. In a routine, an exercise is tempo-only — live too (narrows ADR 0071)

- **#2** gains the tempo nudger *on the preview itself* (today it hides one layer down under ⓘ), so
  "routine = only tempo editable" is literally true; all else stays read-only.
- **#3** stops reusing the full editor. When `routineContext != nil` the exercise block renders
  read-only content + the tempo nudger + "Hear command tempo" — **no** Practice Settings, promote, or
  "Start training" — while keeping the routine chrome (progress strip, ✕, chevrons, auto-advance,
  count-in). #2 and #3 collapse to one behaviour (pre-start vs live), unmistakably *not* the library
  screen. This is the direct fix for the confusion.

### 4. Watch flips its gating (reverses ADR 0065)

`FretboardPlayOnceButton` ("Watch") today is always shown and deliberately ignores the
animate/Reduce-Motion preference. New rule, on the **library** editing board:

- **Hide Watch when `exerciseAnimates` is ON** — the board already walks continuously, so the
  one-shot is redundant.
- **Show Watch when animate is OFF / Reduce Motion** — there it is the only way to see the shape
  move; the escape hatch stays for exactly the users who need it.

`exerciseAnimates` defaults to `false`, so the naïve "hide when animate is off" rule would have hidden
Watch for the default user and stranded motion-averse users — this is the inversion of that. The
persistent walking-highlight preference already lives only in Settings (unchanged).

### 5. Remove the "Sound soon" scaffold button; keep the seam; defer real pitch audio

`SoundPreviewButton` is a **disabled placeholder**, not a working audition: there is no backend
(`SilentExerciseAudio.isAvailable == false`), so it renders greyed-out "Sound soon" and does nothing.
Remove it from its three editors (`ScaleRunEditor`, `ArpeggioRunEditor`, `FretboardDrillEditor`).

- **Keep the `ExerciseAudioEngine` seam** (protocol, `EnvironmentKey`, `AccompanimentSettings`) — ADR
  0065's un-plumbed boundary stays so a real engine slots in with no call-site changes; it simply has
  no UI consumer for now.
- The routine surfaces' **"Hear command tempo"** (`CommandTempoPreviewPlayer`) is a different,
  genuinely-working metronome click and **stays.**
- A **real pitch audition is deferred to a future ADR**, gated on audio resources (samples vs synth)
  and a chosen home. Scope when it lands: the **pitched/harmonic** templates where hearing the notes
  teaches the shape — **Scale, Arpeggio, Chords, Strum & Chords** — and likely *not* the mechanical
  ones (chromatic warm-up, custom fretboard grid), where a click suffices.

### 6. Promote moves after the run and reframes (direction; trigger deferred)

The in-setup "I own 106 now — promote" is mistimed — mid-drill the player is playing, not tapping —
and re-treads the confusing "do you own the reach?" framing. Direction: surface promotion **after a
run completes** as an opportunity to **bump command** ("you just held 100 — move command up?").
Terminology is already half-done (target → **reach** app-wide); only the button carries the old
framing. The exact **trigger** (every run, or only when the top plateau was actually held) and copy
are an open decision, recorded in a **short follow-up ADR** with the implementation. Exercises only.

### 7. Loops are out of scope

None of the above touches loops: the ⓘ reformat (`ExerciseDetailSheet` is exercise-only), the
in-routine collapse, the board toggles (a fretboard concept loops lack), the Sound removal, and the
promote rethink all apply to **exercises**. Loop in-session consistency is a separate future call.

## Consequences

- The three surfaces become legible: **one** full editor (library), **one** restrained behaviour in
  routines (tempo-only, pre-start and live are the same), and ⓘ is purely reference everywhere.
- ⓘ is no longer a third tempo-editing surface — fewer places the same value can be changed, one
  write path (ADR 0057) unchanged.
- Motion-averse users keep the one-shot Watch precisely when it matters (animation off); the animated
  common case is decluttered.
- A dead "coming soon" button stops advertising a feature that doesn't exist, while the audio
  boundary is preserved for when it does.
- Reversing three prior ADRs is deliberate: 0071 R4 and 0071's session reuse *created* the
  library/routine ambiguity; 0065's Watch rule predates the board-declutter goal.

## Alternatives considered

- **Keep ⓘ as an editor (status quo / ADR 0071 R4).** Rejected — it is the second/third editing
  surface that makes "where do I change tempo?" ambiguous and stops ⓘ being a read surface.
- **Leave #3 as the full editor + strip.** Rejected — a near-clone of the library screen is the
  actual source of the reported confusion.
- **The naïve Watch rule (hide when animate is OFF).** Rejected — hides Watch for the default user
  (`exerciseAnimates` defaults false) and removes the Reduce-Motion escape hatch.
- **Remove the `ExerciseAudioEngine` seam too.** Rejected — keep the pre-carved boundary (ADR 0065);
  only the dead button goes.
- **Extend the routine/tempo-only rule to loops now.** Deferred — loops are a different interaction
  (audio, no shape); a separate call.
- **Fold the post-run promote copy/trigger into this ADR.** Deferred to a short follow-up ADR with
  the implementation, so this one stays about the editing boundaries.
