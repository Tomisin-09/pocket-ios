# 0086 — Chord drills start empty; drop the key selector and Roman numerals

- **Status:** Accepted (2026-07-13)
- **Date:** 2026-07-13
- **Builds on:** ADR 0065 (the Chords template — `ChordProgression` / `ChordChange` / `ChordDiagramView`).
- **Relates to:** ADR 0084 (movable + custom chords). Once a player can place any chord — including a
  bespoke custom voicing — the key/numeral scaffolding reads as more cost than benefit (see below).

## Context

The Chords template shipped two pieces of "key" scaffolding on top of the raw progression:

1. A **default starter progression** (`gMajorPop` — the I–V–vi–IV pop turnaround in G) seeded into every
   freshly-created Chords exercise "so the surface is never empty."
2. A **Key selector** (root + major/minor) driving **Roman-numeral badges** (I, V, vi, ♭VII …) on each
   chord, in the editor, the live run screen, and the template-preview cards.

Two signals from the 2026-07-13 device review pushed against both. The default turnaround is something the
player **deletes first** every time they want their own changes — friction, not a head start. And the key
selector earns little: its only visible payoff is the numeral badges, which (a) become dubious the moment a
**custom voicing** is placed (ADR 0084 — a bespoke "D7♭13" as "I" is noise, not insight), and (b) cost a
whole editor row plus per-chord chrome for a label most players don't read. The chord **name** already
identifies each chord.

## Decision

- **C1 — A new Chords (and Strum & Chords) exercise starts empty.** `ExerciseTemplate.defaultChordProgression`
  for `.chords` is `ChordProgression.empty` (no changes), so the editor opens on just **Add chord**.
  `defaultStrumChordSheet` for `.strumChords` is `StrumChordSheet.empty` — a **rest-only groove**
  (`StrumPattern.empty`) over an empty progression — so both surfaces open blank and the player builds each
  from scratch. **Create** is gated on at least one chord placed (an empty progression has nothing to change
  through; the groove may stay empty — it still runs over the click), matching the existing non-empty-name
  gate. The seeded starters (`gMajorPop`, `popGroove`) keep their content.
- **C2 — Remove the key selector and every Roman-numeral badge from the presentation.** The Key picker
  leaves `ChordProgressionEditor`; the numeral badge leaves the editor rows, the live `ChordChangeView` /
  `StrumChordsView`, and the `ExerciseTemplatePreview` cards. `ChordDiagramView` loses its now-unused
  `degreeLabel` parameter. A chord is identified by its **name** alone.
- **C3 — Keep the key/numeral *model* intact.** `ChordProgression.keyRoot` / `keyIsMinor`, `resolvedKeyRoot`,
  `numeral(for:)`, and `RomanNumeral` stay — they are pure, unit-tested, and (crucially) `keyRoot` must keep
  decoding so **existing saved progressions still load** (the seeded `gMajorPop` preset carries a key). This
  is a **presentation** change, not a schema change: no store migration, no lost payloads. If a keyed reading
  ever earns its place back, the logic is already there.

## Consequences

- **Cleaner authoring.** The editor is a bare list of chord diagrams + an Add button — nothing to clear, no
  key row. The empty-start + Create gate keep a half-made drill from being saved.
- **Fully additive-in-reverse.** Removing only the *rendering* of numerals (not the model) means the 938-test
  suite stays green with no churn beyond the one default-value assertion, and `gMajorPop` (preset) plus all
  saved progressions decode unchanged (C3).
- **Consistent with custom chords.** A progression can now freely mix open shapes, slid grips, and bespoke
  custom voicings (ADR 0084) with no key concept to mislabel any of them.
- **Strum & Chords starts empty too.** Both the standalone **Chords** default and the **Strum & Chords**
  default go empty (2026-07-13 follow-up) — the latter a rest-only groove over no chords — so neither
  template greets the player with content to delete. The seeded `popGroove` preset (and `gMajorPop`) still
  ship real content; only the *create* default is blank.

## Alternatives considered

- **Keep numerals, auto-inferred, just drop the picker.** Rejected — a numeral with no player-set key still
  guesses (and mis-guesses custom voicings); half the feature for the same clutter.
- **Remove the key/numeral model entirely (delete `RomanNumeral`).** Rejected — it's tested pure logic, and
  `keyRoot` must stay for back-compat decode; deleting it buys nothing and burns the option to bring a keyed
  view back.
- **Keep the default turnaround.** Rejected (C1) — it's deleted-first friction, not a head start, now that
  authoring a progression from scratch is quick.
