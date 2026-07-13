# 0091 — Label scale/arpeggio boxes by their root anchor, and default to the flagship box

- **Status:** Accepted (2026-07-13)
- **Date:** 2026-07-13
- **Relates to:** ADR 0065 (CAGED-box scale/arpeggio generation), ADR 0083 (position-shifting runs +
  CAGED-shape position labels — the labelling this ADR revises for the box layout), ADR 0085 (12-scale
  catalog: modes + bebop). Touches `CAGEDShape`, `ScaleRun`, `ArpeggioRun`, and their editors.

## Context

Scale and arpeggio drills pick a **box** (one of five CAGED positions) filtered from a reference-key
geometry (ADR 0065). ADR 0083 surfaced each box in the editors as a **CAGED letter** — "E shape",
"D shape", … — mapped to a fixed index (E = 1 … G = 5).

Two problems, both raised in a design review:

1. **The letter is relative to the *reference/relative-major* key, not the scale's own tonic.**
   Minor-family and modal scales borrow the boxes via their relative major (`relativeMajorSemitones`), so
   the letter shown for, say, A-minor-pentatonic position 1 is the *C-major* E-shape. It is not the letter
   a player would name relative to A, so the label misinforms exactly the players who read CAGED.

2. **The default, and the CAGED numbering, don't point at the box players actually know.** A new drill
   opened on **position 1**, which for the minor pentatonic is the E-shape box at frets 7–10 (its lowest
   root sits on the *D* string). The famous "box 1 at the 5th fret" — root on the low E — is **position 5**
   (the G-shape of the relative C major), as the generation tests already documented. So the default and
   the "1" label pointed at a shape most players would not call first.

The reviewer's own instinct ("for the minor pentatonic, the G shape is the most widely known") was
correct, and is itself evidence that the CAGED letter is the wrong primary label.

## Decision

- **D1 — The box's primary label is its *root anchor*, not a CAGED letter or box number.** A box is named
  by where its lowest root note sits — **"root on low E · fret 5"** (`CAGEDShape.rootAnchor(in:root:)`,
  read from the generated notes so it's honest for every scale, quality and key). `ScaleRun.positionLabel`
  / `ArpeggioRun.positionLabel` return this for the box layout. An open-string root reads "root: open
  low E"; a box with no root in a one-octave trim falls back to "from fret N".

- **D2 — The CAGED letter is demoted to a caption**, not removed. It stays in the editor subtitle
  ("CAGED G shape · from fret 5") and remains available as `shapeLetter` for anyone who reads CAGED. The
  model keeps it — no data change.

- **D3 — A new drill opens on the *flagship* box, and that box is badged "Most common."** The flagship is
  the **root-position 6th-string box a player learns first**, computed per scale by
  `CAGEDShape.flagshipPosition(root:relativeMajorSemitones:degrees:)`: the box whose ascending run
  **begins on the tonic on the low E string** (tie-broken to the lowest starting fret), falling back to
  the lowest low-E root, then position 1. "Begins on" — the first note played — is load-bearing: a box can
  *pass through* a low-E root without opening on it (position 4's A-shape tops out on the root at fret 5
  but opens on the ♭7 below), and only the box that opens on the root is the shape a player recognises.
  For the minor pentatonic this resolves to **position 5** (the famous 5th-fret box); for the major scale,
  whose 6th-string box opens on the leading tone, it falls back to **position 1**.

- **D4 — Badge + default only; all five positions stay reachable.** The flagship is flagged and made the
  default, but the stepper still walks every position 1…5 (per the design decision to draw attention to
  the common shape without hiding the others). The editor position row stacks the label + badge over a
  full-width stepper so the longer anchor label has room.

- **D5 — Scope: the box layout only.** The **extended** diagonal keeps its two-fingering mnemonics and
  **3-notes-per-string** keeps "Pattern N" (ADR 0083) — neither is a single CAGED box anchored on one
  root, so the root-anchor framing doesn't apply. Chord shapes (ADR 0084) are unaffected.

## Consequences

- The curated seeds `ScaleRun.aMinorPentatonic` / `ArpeggioRun.aMinorSeventh` now open on the flagship
  position (5 for the minor pentatonic) rather than a hard-coded position 1. They stay `static let`s by
  computing the flagship at initialisation. Presets and template defaults reference these seeds
  symbolically, so they follow automatically; only tests that asserted `position == 1` were updated.

- **Closed off:** the CAGED letter as the *primary* box label; and a fixed "position 1" default
  irrespective of scale. Both are the alternatives this ADR rejects. Renumbering the boxes (e.g. by neck
  position so the famous box becomes "Box 1") was considered and set aside in favour of dropping the
  number entirely — the root anchor is more concrete and carries no index that could mismatch the fame.

- The flagship rule is pure and unit-tested (`CAGEDShape.flagshipPosition`, `rootAnchor`), so it stays
  SwiftUI-free and correct by construction across all 12 scales and 5 arpeggio qualities.
