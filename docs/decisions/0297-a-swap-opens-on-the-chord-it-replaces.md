# ADR 0297 — A swap opens on the chord it replaces

- **Status:** Accepted — built (2026-11-14, `pocket-427-swap-opens-on-the-chord`), for 1.4.1
- **Date:** 2026-11-14 (`pocket-427-swap-opens-on-the-chord`)
- **Amends:** ADR 0103 — **D4**: a movable chip is a root-agnostic picture over a root menu only while
  the new root row (D3 here) is on **Any**. With a root chosen, the chip is the chord the shape makes at
  that root, and a tap inserts it (D4 here). The rest of D4 stands: the browse picture, the menu, and
  "a grip is not a chord until it has a root". D1–D3 and D5 stand.
- **Amends:** ADR 0122 — **§3**: the *Sus, 6ths & 9ths* section still starts folded, except when the
  chord being swapped is one of its shapes. Then it opens expanded, so the marked chip isn't hidden
  (D7 here). The rest of §3 stands.
- **Relates to:** 0084 M2 (a grip placed at a root is deterministic, which is what lets D2 read it back)
  · 0093 (`ChordNamer`, the fallback root) · 0164 (bass shapes, which get the same treatment) · 0218
  (*Use a progression*, whose key row the root row copies, and whose preview swaps get D1 too)
- **Schema:** none. No `@Model` is touched and `ChordVoicing` gains no field (D2).

## Context

Tomisin, building a Chords drill: *"when you select from a chord template and you want to change the
shape, it feels like you're going back to square one where you have to identify that particular shape
in the midst of so many, then select the note/key."*

It was square one. Tapping a row's chord name opened the same `ChordPickerSheet` as *Add chord*. Only
the title differed. The picker didn't know which chord it was replacing, so a swap meant finding the
shape again among about sixty chips, with movable shapes drawn at fret 5 and labelled
"Minor 7 / A-shape barre", and then choosing the root again from a twelve-item menu.

A swap is nearly always one of two moves:

- **Same root, another shape:** C to Cm7, or the A-shape C to the E-shape C.
- **Same shape, another root:** slide it.

Both need only two facts the picker didn't have: the chord's root, and the shape it was placed from.

## Decision

**D1 — A swap hands the picker the chord it replaces.** `ChordPickerSheet` takes `current: ChordVoicing?`.
Every swap entry point passes it: a row in `ChordProgressionEditor`, a chord in *Use a progression*'s
preview, and a filled *Pick your own two* slot. *Add* passes nothing.

**D2 — What the chord is gets read off its frets, never stored.** `ChordPickerCurrent` derives it:

- **The grip:** for each grip the Insert grid places, read the root from the fret on the grip's root
  string, place the grip there, and compare every string. Placement is deterministic (0084 M2), so equal
  frets mean that grip. Names are ignored, so A♯ and B♭, or a chord saved under the player's own name,
  read back the same.
- **The bass shape:** a four-string voicing that matches any placement of a `BassChordShape`.
- **The root:** the grip's root if there is one. Otherwise the bass note for a bass chord (root in the
  bass by construction). Otherwise `ChordNamer`'s best reading, so *D/F♯* opens on D, not F♯. As a last
  resort, the lowest note.

A chord that matches no grip, such as a custom chord or one placed under the old four-string A-shape
(0122), still opens on its root and simply has no shape to mark. A unit test places every grip at every
root and reads it back, which also proves that no two grips ever draw the same frets.

**D3 — A root row sits over the grid: Any, then C … B.** A swap opens on the chord's root, and *Add*
opens on **Any**. The row looks and scrolls like *Use a progression*'s key row, so the two read as one
control. VoiceOver reads each chip as "Root C", and the bare letter stays free for the root menu.

**D4 — With a root chosen, a movable chip is the chord it makes there.** Movable shapes, triads,
*Sus, 6ths & 9ths* and bass shapes are drawn at that root with their real name and frets ("Cm7",
3rd fret), and a tap inserts exactly that. The subtitle keeps the shape family ("E-shape barre",
"G-B-e · 1st inv"). Search reads the chord name too, so a chip you can read is one you can type. On
**Any** a chip is the 0103 D4 browse picture over a root menu, as before.

**D5 — Fixed chips narrow to the chosen root.** My chords and Open shapes show only chords of that root
(read as in D2), so under C the picker is *the ways to play C*. **Any** shows them all.

**D6 — The swapped chord is marked and scrolled to.** Its chip gets a heavier border and a check, and
VoiceOver reads "Current shape" or "Current chord". A grip or bass shape is marked at **every** root,
because sliding it is one of the two moves. A fixed chip is marked only where its frets match, since it
can't move. The sheet opens scrolled to the marked chip and keeps it in view as the root changes. When
a chord is both a grip and an open shape (open E is the E-shape at the nut), both are marked and the
grip is the one scrolled to.

So *same root, another shape* is one tap, and *same shape, another root* is two: the root, then the
marked chip.

**D7 — The folded section opens for its own shape.** *Sus, 6ths & 9ths* starts expanded when the chord
being swapped is in it (amending 0122 §3).

## Consequences

- **Pure and tested:** `ChordPicker+Current.swift` (`ChordPickerCurrentTests`). A UI test,
  `ChordSwapUITests`, drives both moves and a chord far down the grid. `ExerciseInstrumentUITests`
  covers a bass swap.
- **No schema, no migration.** Every chord ever saved can be read back, because frets are all D2 needs.
- `ChordPickerSheet` splits its chips into `ChordPickerSheet+Chips.swift` to stay under the file limit.
- **Found while building, not changed here:** a bass 10th spans seven frets, and `ChordDiagramView`
  draws a four-fret window, so its upper note isn't drawn on any surface. This was already true of the
  fret-5 browse picture and of an inserted 10th's editor row. Logged in `docs/backlog.md`.

## Alternatives considered

- **Store the grip on `ChordVoicing`.** Rejected: it adds a field to a `Codable` blob that syncs, for a
  fact the frets already determine.
- **A *Change root* menu on the row's chord name.** It covers sliding but not reshaping, and the row
  already holds five controls. It could still come later, since D2 is the part it would need.
- **Preselect the previous chord's root on Add.** Rejected: a progression moves, so the guess is usually
  wrong, and D5 would then hide the open shape the player came for. **Any** keeps Add as it was.
- **A *Same root* strip above the grid instead of a root row.** Rejected: it duplicates chips the grid
  already has, and it doesn't help the sliding move.
