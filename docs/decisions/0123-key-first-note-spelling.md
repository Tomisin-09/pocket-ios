# ADR 0123 — Note spelling is key-first; the sharp/flat preference is a tiebreaker

- **Status:** Accepted
- **Date:** 2026-07-29
- **Supersedes / amends:** replaces the app-wide "sharp-spelled fretboard" convention asserted in
  `GuitarScale.noteName`, ADR 0091 (root-anchor labels), ADR 0093 N6 (the namer's sharp spelling) and
  ADR 0115 (the tuner's). Consistent with ADR 0086 (chord surfaces carry no key) — that ADR is
  precisely why chord surfaces fall to the preference here.
- **Number note:** 0120 is reserved for the analytics/privacy ADR in `docs/backlog.md` Slice 8.

## Context

Everything in the app was spelled with sharps, because one table said so:

```swift
let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
```

That produces "A♯ Minor Pentatonic", "A♯ major" in the song key picker, and an "A♯" root anchor on a
scale box — none of which any player, chart or teacher would write. The note is B♭, and it is B♭ for
a reason that has nothing to do with taste: **the key says so.** The device pass of 2026-07-28 asked
for a sharps/flats preference in Settings, and the triage note attached the important qualifier:

> spell by key wherever a tonal centre exists (F major always reads B♭); the user's sharp/flat
> preference is a **tiebreaker only** where there is no key context (custom chords, the tuner,
> rootless drills). Not a global override.

That qualifier is the whole design. A plain global toggle would be worse than the sharp default it
replaces: it would let a player set "flats" and be shown "G♭ major" for a key the app itself stores
and sorts as F♯, or "D♭" for the third of B♭ minor. A preference that can make the app *wrong* is not
a preference, it's a bug with a switch.

Three inconsistencies surfaced while looking:

1. **Two glyph conventions.** `GuitarScale.noteName` printed ASCII `C#`; `ChordVoicing`'s note
   captions printed typographic `C♯`; degree labels have always printed `♭3`. The board and the
   placer disagreed with each other on the same screen.
2. **Two hand-rolled "friendly" root menus.** `ChordPickerSheet` and `MovableChordSheet` each carried
   a private list mixing both — `["C", "C♯", "D", "E♭", …]` — an unexplained per-note judgement
   duplicated in two files.
3. **`MusicalKey` already knew the answer and didn't use it.** It stores a canonical sharp `rawValue`
   (the ADR 0036 schema) and separately computes a human `displayName` from the same table, so the
   label was sharp for storage reasons rather than musical ones.

## Decision

**A single `NoteSpelling` (`sharps` | `flats`) names every pitch class, and callers resolve which one
applies before asking. Key-first, preference last.**

```
keySpelling(root:relativeMajorSemitones:) -> NoteSpelling?     // what the key demands, or nil
forKey(root:relativeMajorSemitones:preference:) -> NoteSpelling // …with the preference filling nil
```

- **The circle of fifths decides.** A tonal centre resolves through the parent major whose key
  signature governs it — exactly what `GuitarScale.relativeMajorSemitones` and
  `ArpeggioQuality.relativeMajorSemitones` already encode for the CAGED boxes, reused rather than
  restated. D♭ · E♭ · F · A♭ · B♭ major spell flats; C · G · D · A · E · B spell sharps.
- **Modes resolve through their parent, not their root.** G Dorian's parent is F, so it spells flats.
  Reading the root as its *own* major would get C♯ minor exactly backwards (parent E, a sharp key,
  but D♭ major is a flat one). This is the reason the API takes an offset rather than a root alone.
- **`nil` means "nothing here decides"** — and only two positions on the circle return it: **C**
  (no accidentals to follow at all) and **F♯/G♭** (six of each, genuinely a tie). `nil` is *not*
  "sharps". Making it a distinct value is what lets a key context and a **keyless** context share one
  fallback: the user's preference. The preference is a tiebreaker in the strict sense — it acts only
  where the music declines to answer.
- **Accidentals use the ♯ / ♭ glyphs**, never ASCII `#`, matching the degree labels the app already
  ships. `MusicalKey.rawValue` keeps its ASCII `"A#"` — that is schema, not display — and
  `MusicalKey.parse` already folded both glyphs, so a key label still round-trips to its own case.

### Which surfaces are key-spelled, and which take the preference

| Key decides | Preference decides |
|---|---|
| `ScaleRun` / `ArpeggioRun` root names, titles, position labels | The tuner's readout (a detected pitch has no key) |
| The **board's** note captions for a generated run | Note captions on a rootless drill (spider walk, picking pattern) |
| `MusicalKey.displayName` — a song's key names itself | The custom placer's captions and its `ChordNamer` suggestions (ADR 0086: chord surfaces carry no key) |
| Each candidate root in the scale/arpeggio root menus | The picker / movable-sheet root menus, and the tracing guide's key menu |
| — | Movable grip auto-naming (a grip is placed at a bare root) |

Open **tunings stay sharp outright** and are outside the preference: Open D's third string is F♯, the
raised third of D major, for everyone. That is the same key-first rule, not an exception to it.

**The board learns its key through a transient field.** `FretboardDrill` gains
`keySpelling: NoteSpelling?`, stamped by `ScaleRun`/`ArpeggioRun.expanded()`. It is **excluded from
`CodingKeys`**, exactly like `noteGroups` and `openMidi` (ADR 0116 S5) — a pure render artifact
re-derived on every expand, so there is no persisted-shape change and no store migration. A decoded
drill comes back `nil` and re-derives.

The rejected alternative was to resolve the spelling inside `FretboardGrid` from `drill.rootPitchClass`
alone, treating the root as a major key. It needs no new field and is wrong for the whole minor
family — a C♯-rooted minor drill would read as D♭ major and spell flats against a five-sharp key.

## Consequences

- The default is unchanged for anyone who never opens Settings, except where the *key* now overrides
  it: B♭ minor pentatonic, E♭ major, B♭7 and "B♭ major" in the song key picker all read correctly
  now, whatever the preference says. That is the point, and it is not configurable.
- **Generated names change for content created from now on.** A movable grip placed at pitch class 10
  by a flats player names itself "B♭7"; a scale run's auto-name reads "B♭ Minor Pentatonic". Nothing
  already stored is rewritten — a `ChordVoicing.name` and an `Exercise.title` are authored text, and
  `ChordVoicing.rootPitchClass` derives from the frets, never from the name, so no comparison or
  lookup depends on the spelling.
- `SavedChord`'s duplicate check matches on name **and** geometry, so a "B♭" and an "A♯" of the same
  shape would read as two chords. Harmless while the no-users window holds; worth remembering if the
  preference is ever exposed per-document.
- Views that spell by preference read `AppSettings.accidentalPreference` through `@AppStorage`, so
  flipping the picker redraws them live. `TunerEngine` re-reads it per buffer for the same reason.
- Everything under `Core/` stays pure: the resolvers take a preference **parameter** and default to
  sharps, so model code (titles, auto-names, property tests) is deterministic and Settings-free.
