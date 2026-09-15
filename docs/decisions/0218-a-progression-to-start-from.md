# ADR 0218 — a progression to start from

- **Status:** Accepted — **built** (2026-09-15, `pocket-322-use-a-progression`)
- **Date:** 2026-09-15
- **Amends:** ADR 0086 — C1 stands: a chord drill still opens empty, and nothing here seeds it. C2's
  numerals come back in **one place only** — inside the *Use a progression* sheet and its builder,
  where they explain what the player is choosing (D1, D10). The editor, the run screen and the
  template previews still name chords by name alone, and C3's model is untouched.
- **Builds on:** ADR 0065 (`ChordProgression` / `ChordChange`), ADR 0084 (`ChordGrip`, the movable
  vocabulary every step resolves through), ADR 0095 (`SavedChord`, the pattern `SavedProgression`
  copies), ADR 0164 (`BassChordShape`)
- **Relates to:** ADR 0103 D3/D5 (the player's own first; manage in the Toolkit, insert from the sheet),
  ADR 0123 (spelling — taken one step further, D3), ADR 0070 (no counter, D11), ADR 0090 (identity by
  `uid`), ADR 0188 D1/D6 (what a restore lands and skips), ADR 0189 (why the schema change is additive)
- **Schema:** one new entity, `SavedProgression` (`uid`, `name`, `createdAt`, `stepsData` — every
  non-optional attribute declaration-defaulted, content in a blob); additive, so ADR 0189's D1–D3 do
  not engage. On the wire, `PracticeArchive.savedProgressions` — `Optional`, so an archive written
  before this ADR still decodes.

---

## Context

A chord drill is built one chord at a time. That suits a player drilling their own changes and it is
slow for everyone else: the four-chord loop is eight taps and four trips through the picker, and a
player who only wants to drill Am to E has to know to build two rows and set each hold.

The app has had a version of this before. ADR 0086 removed the seeded G–D–Em–C starter because players
**deleted it first** — it was a default standing between them and their own chords. What went wrong
was that it was a default, not that it was a progression. Two things have changed since: the movable
vocabulary (ADR 0084) can play any chord at any root, and spelling is key-aware (ADR 0123). Together
they make a progression something that can be **written once and placed in any key**, which the old
fixed-shape starter never could be.

Design settled over a mockup the user approved, then two revisions in conversation (2026-09-12):
saved progressions were first imagined as *a list of the player's existing drills*, transposed by
re-fitting each chord's shape. That was dropped — the list grows with every drill, and a re-fit custom
voicing is a guess the player has to audit. **Writing the progression as numerals makes transposition
exact**, and that is what this ADR builds.

## Decision

### D1 — a second way in, beside *Add chord*

The chord editor (`ChordProgressionEditor`, both the Chords and the Strum & Chords templates, on the
create form and the shape sheet) gains **Use a progression** under **Add chord**. It opens a sheet with
two tabs — **Progressions** and **Two chords** — a shared **Hold each chord** control, and an **Add N
chords** button. Nothing is added until the player taps it; the drill still opens empty (0086 C1).

The built-in progressions are eight standard ones — I – IV – V, I – V – vi – IV, vi – IV – I – V,
I – vi – IV – V, ii – V7 – I, the 12-bar blues, i – ♭VII – ♭VI – V and I – ♭VII – IV — named by their
numerals or a plain description, **never after a song**. A progression is common property; a title is
not (T8).

### D2 — a progression is steps in a key, not shapes

`ProgressionStep` is the chord's distance above the tonic in semitones, its quality, and how many bars
it is held. Nothing about a shape is stored. That is the whole reason moving a progression to another
key is exact: there is no fingering to carry across, only a distance to add.

### D3 — a root is spelled from its degree

ADR 0123 decides *sharps or flats* from the key signature. A progression's chords have degrees, so here
the **letter** comes from the degree and only the accidental from the pitch (`ProgressionKey`): ♭VII in
C is **B♭** whatever the preference, because the seventh letter above C is B — a sharps list would print
A♯, which no chord chart uses. The tonic itself still follows 0123 (`NoteSpelling.forKey`), preference
included for the two positions a signature leaves open. A degree whose letter would need a double
accidental (E𝄫 for ♭VI in G♭) falls back to the key's sharps-or-flats reading.

A progression that starts on a minor tonic chord **reads as minor**: its key chips say *Am*, and its
tonic is spelled from the relative major. Labels only — the steps sound the same either way.

### D4 — which shape each step gets

`ProgressionResolver`, in a fixed order that is the whole policy:

1. one of the player's saved chords, when they asked for that and one fits (D6);
2. an **open shape** from `ChordVoicing.library` — in G, the G chord is the open G;
3. the **lowest-sitting curated grip** of that quality (`ChordGrip.curated`).

On a bass drill the guitar shapes stand down (ADR 0164): a tenth states a major or minor chord, the
♭7-and-tenth shell a dominant, the power dyad a chord with no third. Every chord is renamed to its name
in the key; fingering is kept.

What counts as "the chord" (`ProgressionResolver.fits`) is deliberately looser than `ChordNamer`'s exact
note-set match: the root must be in the bass, the third and seventh must be **exactly** the quality's,
its defining tones must sound — but the fifth may be omitted and a 9th or 6th may colour anything but a
power chord. The open C7 has no fifth and is still a C7; a saved Cadd9 can play a I chord.

### D5 — every chord offered frets in every key

The builder offers only qualities with a curated grip — major, minor, 7, m7, maj7, 5, sus2, sus4, 6,
9, maj9, m9 — so there is always a shape (step 3 above) at every root. The diminished vii° is left out
of the in-key row for exactly that reason. `ProgressionResolverTests` holds it for every quality at
every root on both necks: break it and some progression somewhere inserts a silent row.

### D6 — *Use my chords where they fit*, off by default

A switch in the Progressions tab lets a saved chord (same neck, and it fits the step per D4) stand in
for the standard shape, marked **yours** in the preview. Off by default: it changes the shapes a
built-in progression adds, which a player should choose rather than meet.

### D7 — one hold for the whole insert

**1 bar**, **2 beats** or **1 beat** per chord. A bar is the **drill's** bar, so the editor now takes
the drill's `beatsPerBar` — a 3/4 drill holds a chord for three beats — and its row labels count bars in
it instead of assuming 4/4. The shorter holds scale by a step's length, so a two-bar chord stays twice
as long as its neighbours. A progression whose lengths *are* the form (the blues) ignores the setting.

### D8 — two-chord changes are exact shapes

The **Two chords** tab offers six curated changes — Am ↔ E, Em ↔ C, C ↔ G, G ↔ D, D ↔ A, C ↔ F — stored
as **two exact voicings**, never steps. A changes drill is hard because of the grips: Am to E is the
same grip moved one string over, and transposing it would make a different exercise. They are guitar
shapes and stand down on bass. **Pick your own two** takes any two chords from the chord picker,
the player's saved chords included, and lives in this tab rather than as a mode of the picker, which is
already dense and at its length limit.

### D9 — what an insert does to a drill

Each chord in the preview can be tapped to **swap** it through the ordinary chord picker; a swap keeps
the slot's place and length. **Add** writes ordinary `ChordChange`s: nothing downstream knows where a
chord came from. A drill that already has chords asks **Replace them** or **Add after them** first.

### D10 — progressions the player writes

**Your progressions** sits above the built-in list, with **New progression** opening the builder
(`ProgressionBuilderView`): a name, the key it is written in, and chords tapped in from the key's own
row (I ii iii IV V vi) or an *Any chord* row (a chord type, then a root). Chord **names** lead and
numerals sit beneath, so a player who doesn't read numerals taps G, C, D and has written I – IV – V.

The builder's key **corrects rather than transposes**: a player who wrote G · C · D against C and then
picks G wants the same chords read as I · IV · V, so every step is re-expressed from the new tonic
(`ProgressionDraft.setTonic`). Moving a progression is the sheet's key, not the builder's. The key it
was written in is saved, and the sheet opens the progression there.

Saved as `SavedProgression`, on `SavedChord`'s pattern (content in a blob, name in a column). Managed —
edited, deleted — in **Toolkit → My progressions**, beside My chords; the sheet only inserts (ADR 0103
D5's split). Exported and restored like saved chords: skipped when the uid is already present, skipped
when its steps can't be read, and listed on the restore summary as *Saved progressions*. They do not
cross the share doors, as saved chords don't.

### D11 — no change counter

"One-minute changes" traditionally means counting changes. Pocket never grades playing (ADR 0070); the
Two chords tab drills a change over the click and counts nothing.

## What building it settled

- **`ChordNamer` could not be reused for fitting.** Its exact match refuses the open C7 (no fifth) and
  any coloured voicing, which is precisely what a stand-in has to accept — hence `fits` (D4).
- **The selected key has to be scrolled into view.** Twelve key chips don't fit across a phone; the
  first screenshot opened in G with C to F♯ showing and nothing selected. The row now scrolls to the
  chosen key, in the sheet and the builder.
- **`ExerciseShapeSheet` is at exactly 400 lines.** Passing `beatsPerBar` at its call site cost a line,
  reclaimed by joining a `StrumPatternEditor` call onto one line in the same section.
- **The sheet opens on I – V – vi – IV in G**, so it shows what it does before anything is tapped.
- The editor's beat label said "1 beats"; a one-beat hold made that visible, so it now says "1 beat".

## Consequences

- A chord drill can be filled in one tap from a standard progression in any key, from a two-chord change,
  or from a progression the player wrote, and every chord stays an ordinary, swappable row.
- Numerals are back, in the one surface where they carry information.
- The Toolkit has a fifth section; `check-manual.py` C2 names it from `ToolkitView`, so the manual's
  Toolkit page names it too. Two figures show the old four-row hub — `toolkit/hub` and
  `reference/toolkit` — and are stale until the next shoot, which also takes the new
  `exercises/use-a-progression` (its capture is already in `ManualExerciseShots`).
- The restore summary gains a *Saved progressions* line; `RestoreExistingKeys` and `RestoredLibrary`
  carry the new kind.

## Alternatives considered

- **Seed a starter progression again.** Rejected for 0086's reason: a default is deleted first. The
  entry point is opt-in instead.
- **Reuse the player's drills as their saved progressions, transposed by re-fitting shapes.** Proposed
  and dropped (2026-09-12): the list grows with every drill, custom voicings have no exact equivalent in
  another key, and a fit the player must check chord by chord is work moved, not saved. Writing numerals
  makes transposition exact.
- **Transpose by sliding shapes.** Pitches stay right and playability doesn't — an open G slid two frets
  needs a barre and four fingers — and nothing slides below the nut.
- **Infer a drill's key from its chords.** Unreliable (vi – IV – I – V starts on Em and is in G), and
  unnecessary once progressions carry their own tonic.
- **Spell roots from ADR 0123 alone.** Prints A♯ for ♭VII in C (D3).
- **Transpose the two-chord changes.** Changes the exercise (D8).
- **Offer vii°.** No grip plays it, so it would break D5's invariant.
- **Put *Pick your own two* in the chord picker.** Closer to *Add chord*, but `ChordPickerSheet` is at
  396 of 400 lines and the one surface ADR 0103 worked to de-clutter.
- **Count changes in the Two chords tab.** ADR 0070.
