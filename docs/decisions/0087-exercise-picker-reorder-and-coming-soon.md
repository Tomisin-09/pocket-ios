# 0087 — Reorder the create picker; retire Fingerstyle & Rhythm; mark Ear Training & Theory "Coming Soon"

- **Status:** Accepted (2026-07-13)
- **Date:** 2026-07-13
- **Builds on:** ADR 0068 (revised) — the `ExerciseTemplate` create picker as a first-class, immutable
  authoring choice. ADR 0065 — the template → renderer map.
- **Relates to:** ADR 0086 (Chords template presentation). Presentation-only for the *create* surface; no
  model, renderer, or persistence change.

## Context

The create picker (`ExerciseTemplatePicker`, fed by `ExerciseTemplate.creatable`) grew to list every
template case in a build-order that no longer matched how a player actually reaches for them. The
2026-07-13 review asked for a deliberate order and two removals:

- **Fingerstyle** is out of scope for the current release.
- **Rhythm** is redundant — a rhythmic figure is already captured by **Strumming** and **Chords**.

Two more templates (**Ear Training**, **Theory**) are planned but unbuilt: they have no renderer and no
authoring surface, so offering them as live create rows produces a dead "basic tempo drill" that
misrepresents the roadmap.

A subtlety: `creatable` was doing double duty. Besides driving the create picker it also ordered the
**grouping** of *existing* exercises in the routine-unit picker (`AddRoutineUnitSheet`). Dropping a
template from creation must not hide drills a player already made under it.

## Decision

- **P1 — Fixed create-picker order.** `ExerciseTemplate.creatable` becomes, in order: **Basic, Warm-up,
  Strumming, Picking, Scales, Chords, Chords & Strum, Arpeggios, Legato, Ear Training, Theory.**
- **P2 — Retire Fingerstyle and Rhythm from creation.** They leave `creatable` but **remain enum cases**
  (and keep their `displayName` / `renderer` / skill-map entries) so existing exercises decode, render,
  and group unchanged. No migration.
- **P3 — "Coming Soon" for Ear Training and Theory.** A new `ExerciseTemplate.isComingSoon` (true for
  `.earTraining` / `.theory`). The picker renders those rows **disabled** — dimmed, a "Coming Soon" badge
  in place of the "Editor" badge, no disclosure chevron, no tap — so the menu previews the roadmap without
  offering a dead drill.
- **P4 — Rename `.strumChords` display name** "Strum & Chords" → **"Chords & Strum"**. Display-only; the
  raw value (`strumChords`) and everything persisted are untouched.
- **P5 — Split the ordering concept.** A new `ExerciseTemplate.displayOrder` holds **every** case in
  canonical menu order (including the retired Fingerstyle / Rhythm) and drives *grouping* of existing
  exercises. `AddRoutineUnitSheet` groups by `displayOrder`, so retiring a template from creation never
  hides drills already made under it. `creatable` is the create-picker subset.

## Consequences

- The loop skill-tag recogniser (`SkillFamilyMap`) still round-trips through `displayName`, so the rename
  is self-consistent; a loop previously tagged the old string "Strum & Chords" would no longer resolve to
  `.strumChords`, but loop skill tags are an unshipped V2-planner affordance and the suggestion chips now
  offer the new string — acceptable, no migration.
- Adding Ear Training / Theory later is a matter of flipping `isComingSoon` off once each has a renderer
  and authoring surface — the row is already in place.
