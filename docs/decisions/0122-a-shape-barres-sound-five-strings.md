# ADR 0122 — A-shape barres sound five strings; Insert carries the whole movable vocabulary

- **Status:** Accepted
- **Date:** 2026-07-29
- **Supersedes / amends:** amends ADR 0084 (M3's A-shape geometry, and the 4-string decision recorded
  in the 2026-07-13 device review); amends ADR 0103 D4 and ADR 0106 (which set the Insert grid's
  movable set at six) and **ADR 0103 D2** (the two-card Build pane); retires `MovableChordSheet`, the
  authoring surface ADR 0084 M4 introduced. ADR 0109's collapsible Insert sections are what make the
  wider grid affordable.
- **Number note:** 0120 is reserved for the analytics/privacy ADR in `docs/backlog.md` Slice 8.

## Context

Two findings from the on-device pass of 2026-07-28, both about the *chord vocabulary* rather than
about how chords are drawn or stored. They land in one ADR because they share a cause: a curation
made on paper that read as a **gap** in the hand.

**1. The A-shape barres were missing their top string.** ADR 0084 shipped the A-shape family as the
four-string A-D-G-B barre — low E *and* high e muted — on the reasoning recorded in the 2026-07-13
review: "barring cleanly under the high e is awkward, and it only doubles a tone already sounding."
Both halves are weaker than they looked. The high e sits on the **root fret**, the fret the index
finger is already barring — there is no extra stretch, and no separate finger. And it does not double
a doubled tone in the way that phrasing implied: it sounds the **5th**, the note printed as the top
of every A-shape chart a player has ever seen. On device, a Bm that stopped one string short read as
a mistake rather than as a choice, and the player had no way to tell which.

This ran deeper than the grips, because `ChordGrip.aShapeMinor` reproduces `ChordVoicing.bMinorBarre`
byte-for-byte — an equivalence ADR 0084 M5 deliberately introduced so the hand-written library barre
and the generated one could never drift. Fixing the grip without the library voicing would have
broken exactly the invariant that equivalence exists to protect.

**2. The Insert grid showed six of the twelve Tier-1 grips.** ADR 0103 D4 chose a small browsable set
(major/minor/dom7, both families); ADR 0106 swapped dom7 out for the power chord. The intent was
curation — "the ones worth a one-tap-to-root browse" — with the rest reachable through
**Build → Movable shape**. In use it reads as absence: all twelve shapes already exist and are
already generated, so a player looking for a movable **m7** is sent out of Insert to a different
sheet to reach a shape that was sitting one row away. Curation earns its cost when it hides
something *marginal*; a minor 7 barre is not marginal.

Widening the grid then undermined the **Build** pane, which is why this ADR ends up covering the
picker's structure too. `MovableChordSheet` existed to reach shapes Insert didn't carry; once Insert
carried all of Tier 1, the only thing left behind that door was Tier 2 — and Tier 2 is browsable by
exactly the same chip the other twelve use. A second, slower route to shapes the faster route could
also show is not a choice worth offering.

## Decision

**1. The five Tier-1 A-shapes sound the high e, on the root fret, as the 5th.** `aShapeMajor`,
`aShapeMinor`, `aShapeDom7`, `aShapeMin7` and `aShapeMaj7` set `offsets[0] = 0`. The low E stays
muted — that part of the A-shape was never in question. `ChordVoicing.bMinorBarre` moves with them to
`[2, 3, 4, 4, 2, nil]`, fingers `[1, 2, 4, 3, 1, nil]` (the barre finger already covers fret 2), so
the M5 equivalence holds unchanged.

**2. `ChordPicker.insertMovableGrips` *is* `ChordGrip.tier1`** — an identity, not a copied list, so
the two can't drift and a future Tier-1 addition appears in Insert for free.

**3. Tier 2 joins Insert as its own section, and `MovableChordSheet` is retired.** Once every Tier-1
shape was browsable, the sheet's only remaining reason to exist was the ten Tier-2 shapes — sus2,
sus4, 6ths and the four 9ths (ADR 0101) — which it reached in **four** steps (family → quality → root
→ confirm) against the chip grid's **two** (chip → root). Keeping it would have left two doors to the
same shapes, the slower one holding a vocabulary the faster one couldn't see. So
`ChordPicker.insertTier2Grips` (`= ChordGrip.tier2`) becomes a fifth section, placed **last** and
seeded into `collapsedSections` so it starts folded: it is the advanced end of the vocabulary, and a
live search force-expands every section, so nothing can hide behind the chevron. The sheet's file is
deleted rather than left unreachable.

**4. Build is an action, not a tab.** With one card left, the Build pane was a menu of one. The
segmented control keeps both labels, but **Build a chord** is spring-loaded: `modeSelection`'s getter
always returns `.insert`, and its setter opens `CustomChordSheet` directly. Nothing stores a `Mode`,
so dismissing the placer returns to the grid rather than to an empty second pane — the bug the old
two-pane arrangement made possible.

### What we deliberately did **not** widen

- **A-shape sus2 / sus4 keep their muted high e — settled on device, 2026-07-29.** Their standard
  five-string barres would take the same treatment on the same argument, and decision 3 put the
  question under a microscope: the suspensions are now chips in the same grid, in the same picture
  style, a couple of sections below the widened five, so the four-string/five-string difference is
  directly comparable in a way it never was inside the Movable sheet. Looked at that way on device,
  it reads fine. **This is closed, not parked** — a suspension is a colour chord whose voice is the
  2nd or 4th, and the four-string form keeps that voice on top instead of burying it under a doubled
  5th. `testAShapeSuspensionsAndPowerChordsStayNarrow` holds it, so reopening it means editing a
  named test on purpose.
- **The power chords stay three strings.** A "5" is root + 5th + octave root by definition; adding a
  string would make it a different chord, not a fuller voicing of the same one.
- **The 9ths are untouched.** ADR 0101 already decided each of those individually (`dom9`/`min9`
  sound the high e; `maj9` mutes it for the R-3-7-9 shell), on the shapes' own merits.

## Consequences

- Every A-shape major/minor/7th generated from now on is a five-string barre, at every root, in every
  surface that draws one — the picker's browse pictures, the progression editor, Strum & Chords,
  saved chords made after this change.
- **No migration is owed and none is written.** v1.0 is approved with distribution deliberately held,
  so there are no users and no stored chords to reconcile. A `SavedChord` is a *snapshot* of a
  voicing, not a reference to a grip, so anything saved before this change would keep its four-string
  shape by design — correct behaviour, and moot while the window holds.
- The Insert grid's movable section is four rows rather than two, and there is a fifth section below
  Open shapes. Both are collapsible (ADR 0109) and a live search force-expands them, so the added
  height costs nothing when it isn't wanted.
- **`MovableChordSheet.swift` is deleted** (161 lines). Its live preview + `ChordIdentityCaption`
  confirmation go with it; the chip grid's `browseVoicing` picture plus the caption the progression
  editor already shows cover the same ground with fewer taps. `ChordPickerTests` pins the replacement
  claim directly — Insert's two movable sets must together equal `ChordGrip.curated`, so a grip added
  to the curated vocabulary without a home in the picker fails a test rather than going unreachable.
- `ChordGripTests` now pins both directions: the five widened shapes assert the high e sits on the
  root fret *and* sounds the 5th; the suspensions and power chords assert they stayed narrow, so a
  future widening is a deliberate edit to a named test rather than a silent drift.
