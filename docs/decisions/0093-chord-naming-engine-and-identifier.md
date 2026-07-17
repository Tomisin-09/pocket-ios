# 0093 — Chord-naming engine + reverse-lookup identifier

- **Status:** Proposed (2026-07-17)
- **Date:** 2026-07-17
- **Builds on:** ADR 0065 (the Chords template — `ChordVoicing` / `ChordProgression` / `ChordDiagramView`),
  ADR 0084 (movable grips + the custom-chord placer).
- **Relates to:** ADR 0070 (Pocket never grades the player), ADR 0086 (chord surfaces carry no key /
  Roman numerals), ADR 0092 (AI strategy — an AI "coach" is a separate, deferred lever).

## Context

The custom-chord placer (ADR 0084 slice 3) lets a player compose *any* voicing by tapping the board.
Today the player must **name it themselves** — an arbitrary voicing has no derivable name, and the placer
only offers the honest *chromatic* degree read-out (`ChordVoicing.degreeLabels`: R / ♭3 / 5 / ♭7 …),
deliberately **not** a chord name, because naming was out of scope and a wrong guess is worse than none.

But most shapes a player builds *do* have a common name, and not knowing it is precisely the gap a
practice tool should close. "I fingered this — what is it?" is a factual question with a factual answer.
The backlog (2026-07-17, "Chords & theory") parks this as the **chord identifier**: reverse lookup from
the sounded pitch classes to a chord name, shown live under the board as the shape is built.

Critically, this is not a one-off UI feature — it is the **first consumer of a shared theory core**. The
same pitch-class → name logic underpins an interval/scale-degree reader, an ear-training "name what you
hear" reference, and any future harmonic analysis. The backlog is explicit: *"build it once and let the
identifier be its first consumer."* So the engine must land as **pure, SwiftUI-free, exhaustively
unit-tested** logic (AGENTS.md: identity/theory math MUST be unit-tested), independent of where it renders.

The existing substrate already does the arithmetic half: `ChordVoicing` exposes `pitchClasses`,
`midiNotes`, `rootPitchClass` (lowest sounding pitch), `isMinorQuality`, `isDiminishedQuality`, and
`degreeName(semitonesAboveRoot:)`. What's missing is the **naming** step — matching an interval set
against a vocabulary of chord qualities, choosing a root, detecting inversions, and spelling the result.

## Decision

- **N1 — A new pure theory core: `Pocket/Core/Theory/`.** The naming engine lands as SwiftUI- and
  AVFoundation-free value types in a new `Core/Theory/` folder (parallel to `Core/Planner/`), so the
  identifier, a future interval reader, and ear-training reference all import the same source of truth.
  `ChordVoicing` stays in `Core/Models/` (it's the geometry); the *analysis* of a voicing lives in Theory.

- **N2 — `ChordNamer` takes pitch classes (+ optional bass) → ranked `[ChordCandidate]`.** The engine's
  input is intentionally **pitch-class-set + bass pitch class**, not a `ChordVoicing`, so it is reusable
  by anything that can produce notes (a placer, an audio analysis, a typed note list). A thin
  `ChordNamer.candidates(for: ChordVoicing)` adapter feeds it `voicing.pitchClasses` and the bass PC of
  `voicing.midiNotes.min()`. Each `ChordCandidate` carries: `rootPitchClass`, the matched `ChordQuality`,
  the resulting **display name** (e.g. `"Cmaj7"`, `"Am7"`, `"Dsus4"`), an optional **slash bass** for
  inversions (`"C/E"`), and a `confidence`/rank score.

- **N3 — Vocabulary = the common-practice set (v1 ceiling).** A curated `ChordQuality` table keyed by a
  **normalised interval set above the root** (semitone offsets, root = 0):
  - **Triads:** maj `{0,4,7}`, min `{0,3,7}`, dim `{0,3,6}`, aug `{0,4,8}`, sus2 `{0,2,7}`, sus4 `{0,5,7}`.
  - **Sixths:** 6 `{0,4,7,9}`, m6 `{0,3,7,9}`, 6/9 `{0,4,7,9,2}`.
  - **Sevenths:** maj7 `{0,4,7,11}`, 7 `{0,4,7,10}`, m7 `{0,3,7,10}`, m7♭5 `{0,3,6,10}`, dim7 `{0,3,6,9}`,
    mMaj7 `{0,3,7,11}`.
  - **Added tone:** add9 `{0,4,7,2}`, madd9 `{0,3,7,2}`.
  This covers everything the curated grips (ADR 0084 tiers 1–2) and the placer can idiomatically produce.
  Jazz extensions (9/11/13, altered dominants, upper-structure guesses) are **explicitly deferred** — they
  need a much larger table and ambiguity model; see Alternatives. The table is data, not code paths, so
  extending it later is additive.

- **N4 — Root selection tries every sounded pitch class, ranked; no key assumed.** Consistent with ADR
  0086 (chord surfaces are keyless), the namer does **not** take a key. It evaluates each sounded pitch
  class as a candidate root, computes the interval set relative to it, and matches N3. A **partial match**
  (the voicing contains all of a quality's intervals, possibly plus a doubled octave) names it; extra
  non-chord tones disqualify that root/quality pair for v1 (honest over clever). Ranking, best first:
  1. **root = bass note** (root position) beats an inversion;
  2. **fewer notes / simpler quality** beats a more exotic reading of the same set (a bare `{0,4,7}` is
     "C", never "Am♭6");
  3. **more common quality** (maj/min/7 ahead of aug/m7♭5) as the tiebreak, via a fixed rarity rank.

- **N5 — Inversions are named with a slash, not reranked away.** When the best-scoring root is **not** the
  bass note, the name gets a slash bass: root-position C major voiced E–G–C is `"C/E"`. The engine returns
  the root-position reading as the primary candidate *and* the slash reading; the identifier shows the
  slash form when the bass ≠ root (that's what the player fingered), with the plain name available as a
  secondary candidate. `dim7` and `aug` (symmetric chords) legitimately have several equal roots — the
  engine returns all, ranked by bass, and the UI may show "= B°7 / D°7 / F°7 / A♭°7".

- **N6 — Enharmonic spelling: sharps by default, honest and unambiguous.** With no key (ADR 0086), the
  engine spells roots with the same sharp table `ChordVoicing.noteLabels` already uses (`C♯` not `D♭`),
  so the identifier agrees with the board's Note display. A future key-aware consumer can pass a preferred
  spelling; v1 does not. This is the same "plain, unambiguous reading" stance the degree labels took.

- **N7 — The identifier is a read-out, never a gate or a grade (ADR 0070).** The panel under the placer
  shows candidate name(s) as **information**: "This looks like **Cmaj7**" (+ alternates). It is **additive
  and factual** — chord *identity* is objective, not a judgement of playing (the ADR 0070 line is about the
  subjective act of performance; naming a fingered shape assesses no performance). It never blocks Insert,
  never says a shape is "wrong," and an unrecognised shape simply reads "No common name" — the honest
  fallback, with the chromatic degree read-out (already present) still doing its job. Tapping a candidate
  **fills the name field** (convenience), but the player can always override; the name remains theirs (N2
  of ADR 0084 kept the player as the namer of record).

- **N8 — Slices.** (1) **Pure engine + tests** — `ChordQuality` table, `ChordCandidate`, `ChordNamer`,
  the `ChordVoicing` adapter, and an exhaustive unit suite (this ADR's build; no UI). (2) **Identifier
  panel** — surface ranked candidates live under the custom-chord board in `CustomChordSheet`, with
  tap-to-fill-name; extend to the movable sheet and (optionally) the progression editor rows. (3, later)
  broaden the vocabulary / add a standalone interval reader once ear-training (ADR 0094) is scoped.

## Consequences

- **A reusable theory core exists.** `Core/Theory/` is now the home for objective harmonic analysis; the
  ear-training/theory space (ADR 0094) and any interval reader consume `ChordNamer` rather than
  re-deriving it. The engine is pure, so it's fully unit-tested and can't drift with UI churn.
- **The placer stops being a naming dead-end.** The player builds a shape and *learns what it is*, closing
  the exact gap ADR 0084 left open (it deferred name analysis as "guessing"; a ranked, partial-match
  engine with an honest "No common name" fallback is not a guess).
- **No schema change, no migration.** The engine derives names from geometry already stored; nothing new
  persists. The player's typed name still wins and is what's saved (`ChordVoicing.name`), so existing and
  future saved voicings are unaffected. Additive in the ADR-0086 sense.
- **Bounded ambiguity, honestly surfaced.** Symmetric chords (dim7, aug) and inversions have multiple true
  readings; the engine returns them ranked rather than pretending there's one answer — matching how a
  teacher would answer "it depends on the bass."
- **A clear extension seam.** New qualities are new table rows; a key-aware spelling is a new optional
  parameter. v1's common-practice ceiling is a data boundary, not an architectural one.

## Alternatives considered

- **Ship full jazz vocabulary in v1 (9/11/13, altered dominants, poly-chords).** Rejected for now — the
  match table balloons, and extended/altered chords are deeply **context- and voicing-dependent** (is that
  `{0,4,10,2,6}` a `9♯11` or a slash chord?), which drags in a ranking/ambiguity model the placer's users
  don't yet need. Deferred to slice 3 / a later ADR; N3's table extends additively when it's earned.
- **Assume a key and name diatonically (bring back numerals).** Rejected — contradicts ADR 0086 (chord
  surfaces are keyless by decision) and mis-names the bespoke voicings the placer exists to create, the
  same failure that removed the numeral badges.
- **Only ever show the root-position name, drop inversions.** Rejected — the bass note is *what the player
  fingered*; calling an E–G–C shape "C" with no `/E` hides the very thing that makes it an inversion. N5
  keeps both readings.
- **Put the analysis on `ChordVoicing` itself (a `.chordName` computed property).** Rejected — it would
  drag a growing quality table into `Core/Models` and couple naming to the six-string geometry, when the
  engine should take a bare pitch-class set so audio/typed-note consumers can reuse it (N2). The thin
  adapter gives voicings a name without owning the vocabulary.
- **Let an AI name the chord.** Rejected as the mechanism — naming a pitch-class set is deterministic music
  theory; sending it to a model is slower, offline-fragile, costs money, and is *less* trustworthy than a
  transparent table. An AI "explain *why* / suggest a substitution" layer is a genuinely different feature
  and lives in ADR 0092 (deferred/paid), on top of this engine.
