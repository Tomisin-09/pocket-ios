# 0101 — Movable 9th-chord grips (dom9 / maj9 / min9)

- **Status:** Accepted (2026-07-21)
- **Date:** 2026-07-21
- **Builds on:** ADR 0084 (movable chord shapes — the `ChordGrip` primitive, tiered curated
  ceiling, and the `MovableChordSheet`), ADR 0093 (the chord-naming engine that drives the
  sheet's identity caption).
- **Amends:** ADR 0084 — this **reverses the note** (then encoded in `ChordGrip.swift`) that
  "basic 9ths stay with the placer": they become curated Tier-2 movable grips.

## Context

ADR 0084 modelled a movable chord as a `ChordGrip` — a relative fingering (`offsets` per
string, relative to the root fret) that slides up the neck and auto-names itself as a
`ChordVoicing`. It curated Tier 1 (triads + 7ths) and Tier 2 (sus / 6th), and **deferred the
9ths to the custom placer**, with this reasoning baked into the source:

> the movable dom-9 needs a string *below* the root fret, so it can't sit in open position
> and jumps an octave — an honest fit for the per-string placer, not a clean grip.

That observation is correct but the conclusion was too cautious. The 9th (a 2nd above the
root) idiomatically sits on an inner string at a fret *below* the root fret — every standard
movable 9th (the funk "9 chord" `x-3-2-3-3-3`, `Cmaj9` `x-3-2-4-3-x`, `Cm9` `x-3-1-3-3-3`)
carries a **sub-root offset** on the D string. Those are among the most-played movable shapes
on the instrument; sending them to the per-string placer makes the player rebuild a famous
grip by hand. The Wave-2 plan calls for them as first-class grips.

## Decision

**Teach `ChordGrip` the sub-root offset, and add dom9 / maj9 / min9 as curated Tier-2 grips
on both the A-shape and E-shape families.** Six grips, additive over ADR 0084; no new
persisted type, renderer untouched (ADR 0084 M5 still holds — a grip emits a plain
`ChordVoicing`).

- **N1 — Sub-root offsets + an octave-bump.** `offsets` may now be negative (a string fretted
  below the root fret). Placement is unchanged *except*: after the naive lowest-fret
  placement, if any resulting fret is `< 0` (the shape would fall off the nut at a low root),
  the whole grip is bumped up an octave (`rootFret += 12`). The movable idea holds — every
  root stays selectable — the voicing just lands higher up the neck, which is exactly how
  these shapes are played (they have no open-position form). Grips with only non-negative
  offsets never trigger the bump, so every ADR-0084 grip places byte-for-byte as before.

- **N2 — Voicings are the standard chart forms.**
  - *A-shape* (root on A) is the idiomatic home. `dom9`/`min9` voice the top 5th on the high e
    (the iconic barre); `maj9` mutes the high e for the clean R-3-7-9 shell. All mute the low E.
  - *E-shape* (root on low E) is barre-derived, so every offset is ≥ 0 (no bump). `dom9` is
    the 6-string F9 barre `1-3-1-2-1-3`; `maj9` mutes the A string like its maj7 kin (the full
    barre is unplayable, ADR 0084) and moves the 9 to the high e; `min9` moves the 9 to the
    high e off the m7 barre.

- **N3 — The namer learns the 9ths in both forms.** `ChordNamer.catalog` gains `9`, `m9`,
  `maj9` in their full 5-note interval sets *and* the drop-5 4-note sets guitar actually
  voices (e.g. A-shape `maj9` sounds only R-3-7-9). Match is exact-set (ADR 0093), so both
  forms are required for the sheet's identity caption to name a slid grip correctly. They rank
  below the common-practice triads/7ths.

## Consequences

- The `MovableChordSheet` needs **no structural change** — the new qualities flow through its
  existing family→quality filter. The "fret n" caption already communicates that a low root
  lands the shape high up the neck.
- `ChordGrip.offsets` is no longer implicitly non-negative. The invariant is now: a grip is
  valid at every root because the octave-bump guarantees non-negative frets.
- The E-shape 9ths are the fingering risk (as the maj7 E-shape was in ADR 0084) — voiced from
  the standard chart and **verified on device**; if any prove unplayable they shell down the
  same way, recorded here.

## Alternatives considered

- **Keep 9ths in the placer (status quo).** Rejected: they are among the most-played movable
  shapes; hand-building them defeats the grip system for exactly the chords that most benefit
  from it.
- **Disable roots that would fall off the nut** instead of the octave-bump. Rejected: it makes
  the root menu quietly incomplete and surprises the player. The octave-bump keeps every root
  available and matches how the shapes are actually fingered.
- **Curate 11ths / 13ths / altered dominants too.** Rejected as before (ADR 0084 M3): those
  multiply and get context-specific — they stay behind the custom placer.
