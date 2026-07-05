# 0068 — Exercise templates (technique = renderer = library section)

- **Status:** Accepted (2026-07-05), **revised same day** before merge (see "Revision" below)
- **Date:** 2026-07-05

## Context

After the strumming content template shipped (ADR 0065), the Exercises library was a flat,
undifferentiated list. We wanted to classify drills by **technique** (Strumming, Scales, Chords, …)
and **group** the library by it.

The **first cut** of this ADR added a *third* classification axis — a single free-text
`Exercise.category`, orthogonal to `kind` (the ADR 0065 renderer) and `tags` — with curated
suggestions, a `Labels` convergence canonicaliser, and custom user-named categories. On device that
felt wrong: the axes aren't actually independent. The user's mental model is that a drill's
**technique picks its UI** — a strumming drill *is* the arrow-lane surface — so three orthogonal
axes over-modelled it. Two follow-on asks made this concrete: *present the type as a first-class
choice at creation, not a buried setting; and lock it so a drill's type can't drift.*

## Decision (revised)

Collapse the technique axis and the renderer into **one user-facing concept: `ExerciseTemplate`** —
the single answer to "what kind of drill is this." `kind`/`category`/`tags` do **not** stay
orthogonal; the template *is* the technique, *picks* the renderer, and *is* the library section.

- **T1 — One closed, curated template axis, chosen at creation.** `ExerciseTemplate` is a closed
  enum (basic, strumming, scales, chords, picking, legato, fingerstyle, rhythm, warm-up, ear
  training, theory). Stored on `Exercise` as `templateRaw: String` (declaration default `.basic`
  ⇒ additive migration, the CoreData 134110 rule; the enum-attribute rule, ADR 0036). Unknown raw
  ⇒ `.basic` (forward compatibility). **No free-text / custom template yet** — deferred; a new
  template is a deliberate, ADR-worthy addition with code behind it, not an open extension point.

- **T2 — The renderer is *derived*, never stored.** `ExerciseKind` is trimmed to the renderer
  role (`metronome`, `strumming`) and computed as `template.renderer`. Only `.strumming` has a
  bespoke surface today; every other template renders on the shared metronome underlay until its
  own editor/renderer ships. The `kind`/`kindRaw` field is gone — one persisted discriminator, not
  two. The strum payload accessor gates on `kind == .strumming` exactly as before.

- **T3 — Template is immutable after creation.** Creation is **template-first**: pick a template
  card (`ExerciseTemplatePicker`), then configure name/tempo/meter and (for a bespoke template) its
  content. The detail sheet shows the template **read-only**; only its own settings are editable.
  Changing type means delete + recreate — which sidesteps the "what happens to the payload on a
  strumming→scales conversion" mess entirely.

- **T4 — The library groups by template.** `PracticeLibrarySort.exerciseSections` buckets by the
  template's display name, sections ordered **alphabetically** (Basic is an ordinary section, not a
  leftover "Uncategorized" bucket — every exercise resolves to exactly one template). Search filters
  before sectioning. Pure and unit-tested (mirrors `LibrarySectioning` for songs).

- **T5 — Full technique menu now; honest about what differs.** All curated templates are offered at
  creation immediately (the user's call), not just the one with a bespoke UI. Strumming carries a
  small "Editor" badge; the rest are real, section-distinct, template-locked drills that share the
  metronome settings until their editors land. We don't pad the menu with duplicates *or* hide
  techniques that lack a UI — each is a committed slot for a future renderer.

## Consequences

- Additive schema (`templateRaw` default `.basic`); every existing exercise migrates into the
  **Basic** section and reads as before until edited. Device-verify the migration before merge.
  (Dev caveat: a device carrying the pre-revision build persisted the old `kindRaw`/`category`;
  those drop on this build and a previously-seeded strumming preset loses its renderer until a clean
  reinstall re-seeds — a dev-only wrinkle, nothing shipped.)
- Deletes the free-text machinery from the first cut: `ExerciseCategory`, `CategoryField`, and the
  category convergence at the write sites all go. One persisted axis replaces two.
- Creation grows a two-step flow (`ExerciseTemplatePicker` → configure); the automator "Save as
  exercise" seam passes a `fixedTemplate: .basic` to skip the picker (a metronome breakdown is
  always a plain tempo drill). Seeded presets each carry a template, so a fresh library reads as
  grouped sections.
- A future template with its own renderer (fretboard "Scales", chord-diagram "Chords") slots in by
  adding a case + its surface — the picker, sectioning, and immutability already hold. Custom/
  free-text templates remain a deliberate V2 question (they'd need a renderer picker), left out here.

## Alternatives considered

- **Keep three orthogonal axes (the first cut): free-text `category` ⟂ `kind` ⟂ `tags`.** Rejected
  on device — the technique and the renderer aren't independent in practice, and a free-text
  category made "type" a soft, driftable label instead of a first-class, locked choice. The
  convergence canonicaliser was solving fragmentation the closed set doesn't have.
- **Closed `category` enum kept *separate* from `kind`.** Rejected — two closed discriminators that
  co-vary (Scales-category always wants the fretboard renderer) is redundant; one template that
  *maps* to a renderer is simpler and can't get out of sync.
- **Custom/free-text templates now.** Deferred — a user-named template with no renderer behind it
  can't offer a distinct UI, which is the whole point ("the UI differs by template"). Revisit in V2
  with a renderer-picker for custom types.
- **A child `@Model` template entity.** Rejected — a template is a single string discriminator
  that's never relationally queried (the ADR 0058/0065 "no relational machinery for data you never
  query relationally" reasoning), same as the earlier genre group key.

## Revision note

The rules above **supersede** the first-cut decision (single free-text `category` axis, curated
suggestions C2, `Labels` convergence C3, orthogonality C5). Nothing from the first cut shipped —
it was reworked within the same unmerged branch (`pocket-101`), so this is a revision of an
un-released decision rather than a new ADR superseding a live one.
