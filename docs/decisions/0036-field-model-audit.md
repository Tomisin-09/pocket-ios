# 0036 — Song/Loop field-model audit: a four-bucket taxonomy, field calls, and the structured-vs-tag boundary

- **Status:** Accepted (design recorded; schema changes sliced — lands before loop tags ADR 0034 builds)
- **Date:** 2026-06-23

## Context

Planning loop tags (ADR 0034) surfaced a recurring confusion: which annotations should be
**free-text tags** (`[String]` with normalise/suggest, ADR 0033/0034) versus **structured
fields** (typed scalars/enums the app reasons about). The confusion ran deeper than loops —
it implicated song-level fields too (`collections` had been *implemented* with the tag
machinery but is conceptually a grouping, not a tag; `key`/`genre` are stored as free text
but behave like closed/controlled vocabularies).

Rather than decide each field ad hoc, this ADR fixes a **taxonomy** and runs every existing
and proposed `Song`/`Loop` field through it. Doing the audit *now* — before ADR 0034's
annotation slice and before the Phase-3 planner (ADR 0014/0015) — means tags, the library
(ADR 0035), and the planner all build against a settled model instead of ahead of one.

### The four buckets

Every field is one of:

1. **Intrinsic fact** — structural data the entity *is* (not an annotation): `duration`,
   `amplitudes`, `start`/`end`, `uid`, import identity, `downbeatSeconds`. Left alone.
2. **Scalar / enum** — a typed value the app **reasons about** (sorts, scores, derives,
   validates). UI: stars, pickers, segmented controls.
3. **Descriptive tag** — open, user-defined vocabulary whose point is *convergence* (many
   entities sharing the same one). `[String]` + normalise/suggest (ADR 0033/0034).
4. **Named grouping** — a thing entities *belong to*, with potential identity/lifecycle of
   its own. `collections`.

**Litmus test 1 (field vs tag):** *Does the app reason about the value (sort/score/derive),
or just describe it?* Reasoned-about → bucket 2. Purely descriptive, open vocabulary →
bucket 3.

**Litmus test 2 (tag vs grouping):** *Does the grouping need a life of its own — ordering,
its own metadata, or existence while empty?* If yes it is a grouping (bucket 4) that may
graduate to a `@Model`; if no, the `[String]` tag machinery suffices.

## Decision

### Song

- **`key`: `String` → closed enum `MusicalKey`** (12 chromatic roots × {major, minor} +
  `.unknown` for the current empty default). Bucket 2. Free text allowed `"Am"`/`"A minor"`
  drift, couldn't validate or sort harmonically, and blocked future transposition/capo
  logic. Enharmonic spelling (C♯ vs D♭) is an implementation detail of the enum's display,
  not a modelling decision.
- **`genre`: stays single `String`, normalised on write** through the shared canonicaliser
  (ADR 0033). Bucket 3-adjacent (a controlled vocabulary used as a group key by ADR 0035),
  but kept single-valued so group-by-genre stays a clean partition. Multi-value `[String]`
  genre was rejected — it turns grouping into overlapping membership and reworks 0035 for a
  marginal case.
- **`bpm` / `preciseBPM`: unchanged.** The pair is a redundant store (rounded mirror of the
  precise value; `tempoBPM` already computes `preciseBPM ?? bpm`), but consolidation needs a
  *custom* data migration (move `Int` → `Double`, not lightweight) and touches every display
  reader, for zero user benefit. Deliberate per ADR 0024; left as-is.
- **`progression`: removed.** It was free text used as a feel descriptor, but the intent is
  to capture *chord structure* — which is per-section, not per-song. `key` covers the
  song-level harmonic summary. A per-loop chord field (`Loop.chords`) is **deferred** until
  the need is concrete.
- **`proficiency`: removed as a stored field → computed `mastery: Int?`.** Bucket 2, but
  **derived**: the rounded average of the song's loops' `mastery`, or `nil` when the song has
  no loops (shown as "unrated"). A loop-centric practice app tracks mastery where practice
  happens — on loops — and rolls it up. Pure-derived (no manual override): see migration note.
- **`lastPracticed: Date?`: new.** Bucket 2. The model only had `dateAdded`; this enables
  "recently practised" sorting and is a direct planner input (ADR 0014's `PlannerCandidate`
  forecasts `lastPracticed?`).
- **`collections`: unchanged `[String]`.** Bucket 4, but the grouping does not yet need
  order/metadata/empty existence, so the tag machinery still suffices. **Promotion trigger
  recorded:** collections graduate to a `LoopTag`-style `@Model` (per the 0012/0033 open
  path) when a setlist needs **ordering**, **per-collection metadata** (e.g. gig date/venue),
  or **empty existence** (a setlist you start before adding songs — which `[String]` cannot
  represent).

### Loop

All additions. Bucket 2 unless noted.

- **`mastery: Int` (0–5).** How cleanly you own the loop. Source for the derived `Song.mastery`.
- **`focus: Int` (1–3).** Deliberate practice intent, distinct from mastery: `1 Backburner`
  (not actively working it) · `2 Active` (in current rotation) · `3 Sharpening` (pushing it
  now / gig prep). Kept separate from `mastery` because a well-played loop can still be high
  intent (gig) and a poorly-played one low intent (backburner) — the planner reads mastery as
  *need* and focus as *intent*.
- **`commandTempo: Double`.** The fastest tempo the player owns the loop at, as a fraction of
  original (distinct from `speed`, which is the *current practice playback rate*). Named to
  echo the Mastery framing ("you command this at 85%").
- **`loopType`: closed enum, single-select** — `lick` (melodic) · `riff` (melodic + rhythm) ·
  `chords` (rhythmic). A loop is exactly one; free text would lose the mutual exclusivity.
- **`tags: [String]`.** Bucket 3. The open descriptive axis — **owned by ADR 0034**, listed
  here only for completeness of the loop model.
- **`techniques`: deferred.** A semi-open set (slides, hammer-on, pull-off, vibrato, bends,
  and more — tapping, palm-mute, legato, sweep…). The field-vs-tag call is genuinely
  balanced; decided at build time as either a `tags`-style `[String]` or a curated
  multi-select. Not added by this ADR.

### Naming hygiene

Per-loop and (derived) per-song mastery share the name **`mastery`** — the song value is just
the rollup of the loop values, so there is no collision to disambiguate (this is why the old
"song proficiency vs loop proficiency" naming worry dissolved once the loop axis was named
Mastery). User-facing labels: **Mastery**, **Focus**, **Command Tempo**, **Type**, **Tags**.

## Migration notes (build-time)

1. **`proficiency` removal is lossy.** Songs rated manually but with **no loops** lose their
   stars (they become `nil`/unrated, since `mastery` derives from loops). Accepted as a
   trade for the loop-centric model in an early-stage app. The forward-compatible escape, if
   regretted, is the *derived-with-override* variant (`masteryOverride: Int?` seeded from the
   old value) — explicitly **not** adopted here.
2. **`key` String→enum is not lightweight.** Existing free-text keys won't map to enum cases
   automatically. The slice that lands the enum must run a mapping pass (parse common forms →
   case; unrecognised → `.unknown`), not rely on SwiftData lightweight migration.
3. **New Loop scalars use declaration defaults** (`mastery = 0`, `focus = 1`,
   `commandTempo = 1.0`, `loopType = .riff` or a `.unset` case) so lightweight migration fills
   pre-existing loops without a store wipe — the ADR 0012 / CoreData 134110 rule.

## Relationship to other ADRs

A targeted grep of `docs/decisions/` for every changed field name is the complete clash
sweep (anything that clashes must name a changed field). It found three real touch-points;
all others (`progression` in 0009/0013 = automator tempo-*progression*; `key` in 0002 = API
key) are false positives.

- **Amends ADR 0012** (song metadata / edit sheet): the edit sheet loses the `proficiency`
  star *input* (mastery is now derived/read-only at song level) and the `progression` field.
- **Amends ADR 0035** (library): `proficiency`→`mastery`, now **optional** — the proficiency
  dots, the colour-accent strip ("proficiency tier"), and the group-by-proficiency key all
  need an **"unrated"** bucket for `nil`; the key display reads the enum.
- **Feeds ADR 0014/0015** (planner): convergent, not conflicting — `PlannerCandidate`'s
  forecast `priority`/`proficiency`/`lastPracticed?` are now real fields. Sourcing shifts to
  the loop level (Focus + Mastery) plus the new `Song.lastPracticed`.
- **Sequenced before ADR 0034** (loop tags): tags are confirmed bucket 3 and unaffected;
  0034 slices 1–2 build against this settled model.

## Build (sliced)

1. **Song scalars + derivation.** ✅ **Done** (pocket-045). Add `lastPracticed: Date?`; replace stored
   `proficiency` with computed `mastery: Int?` (rounded loop average, `nil` when no loops). Update ADR 0035
   library reads (unrated bucket) and ADR 0012 edit sheet (drop the star input). Remove
   `progression` (drop the field + its three display sites + edit row). Tests: rollup average,
   rounding, empty-loops → nil. (Pure-logic rollup is unit-tested per AGENTS.md — `MasteryRollup`.)
   **Sequencing note:** the derived `Song.mastery` reads `Loop.mastery`, so the *stored*
   `Loop.mastery` field (declaration default `0`) was pulled forward into this slice as its
   source. Its **edit controls** still land in slice 3 with the other loop structured fields.
   The grouping enum case `proficiency` was renamed to `mastery` (its `@AppStorage` raw value
   no longer matches, so an existing "group by proficiency" preference falls back to the Title
   default — acceptable for a view preference). SwiftLint's `inclusive_language` rule flags the
   substring "master"; `mastery` is added to `override_allowed_terms` in `.swiftlint.yml`.
2. **`key` enum.** ✅ **Done** (pocket-046). Introduce `MusicalKey` (12 roots × major/minor +
   `.unknown`); edit-sheet picker; display string. Tests: parse/round-trip, flats fold to sharps,
   unrecognised → `.unknown`. **Storage call:** the stored attribute stays `Song.key: String`;
   `Song.musicalKey` parses it on read and rewrites the canonical `rawValue` on save. This keeps
   the mapping pass (`MusicalKey.parse`, parse-on-read + normalise-on-write) without a SwiftData
   schema change — chosen over storing the enum directly, which would fail to decode legacy
   free-text values and risk a store wipe (migration note 2 / CoreData 134110). Effect is the
   same as a one-time pass: legacy strings read as their case and converge to canonical on next save.
3. **Loop structured fields.** ✅ **Done** (pocket-047). Add `focus` (`Int`, default `1`),
   `commandTempo` (`Double`, default `1.0`), `loopType` (`LoopType` enum, default `.unset`) —
   all declaration defaults — `mastery` already landed in slice 1 as the rollup source. A
   "Practice" section in `LoopEditSheet` adds the controls (mastery dot-rating, focus segmented,
   type picker, command-tempo slider), including the now-editable `mastery`. **Storage call:**
   `loopType` stores a backing `String` (`loopTypeRaw`, default `""`) with a computed
   `loopType: LoopType` over it — **not** the enum directly. A custom enum `@Model` attribute
   does *not* survive lightweight migration: pre-0036 loop rows have no value to decode and
   fault → crash on first read (found on-device — in-memory test stores never migrate, so the
   crash was invisible to the suite). The `String` backing lets migration fill old rows with
   `""` without a store wipe, mirroring `Song.key`/`MusicalKey` and `SongRef.sourceRaw` (the
   ADR 0012 / CoreData 134110 rule). The migration-note-3 assumption that a declaration default
   suffices holds only for **primitive** scalars (`Int`/`Double`/`Bool`), not custom enums.
   `focus` (`Int`) and `commandTempo` (`Double`) are primitives, so their declaration defaults
   migrate cleanly. Tests: defaults present on migrated loops; `LoopType` raw-value
   stability/round-trip/picker order.
4. **`genre` normalisation.** ✅ **Done** (pocket-048). Route writes through the shared
   canonicaliser (no type change). `Labels.canonicalSingle(_:against:)` whitespace-canonicalises
   the entered genre and folds it onto an existing library genre's first-seen display form when one
   matches case-insensitively — so group-by-genre (ADR 0035) doesn't splinter into `Blues`/`blues`.
   Applied in `SongEditSheet.save()` (the sole user write site — genre is manual-only per ADR 0035),
   passing the *other* songs' genres as the pool so a deliberate case change of the only holder isn't
   folded back. Empty ⇒ `""` (the "Unknown Genre" bucket), unlike a tag which is dropped. The stored
   attribute stays `Song.genre: String`; no migration. Tests: whitespace canonicalisation, empty→`""`,
   case-fold onto pool, new-genre passthrough.
5. **Loop tags.** ✅ **Done** (pocket-049). ADR 0034 slices 1–2, against the now-settled model.
   Add `Loop.tags: [String] = []` (declaration default — migration-safe, like `collections`; a
   `[String]` array is **not** a custom-enum attribute so it survives lightweight migration without
   the slice-3 backing-string dance). A **Tags** section in `LoopEditSheet` mirrors `SongEditSheet`'s
   collections UI (add field, swipe-remove, tappable suggestion chips), routing writes through the
   shared `Labels` canonicaliser. Cross-loop suggestions come from a top-level `@Query private var
   allLoops: [Loop]` reduced via `Labels.suggestions(from: allLoops.flatMap(\.tags), excluding: tags)`
   — the loop-set aggregation is the flat-map; `Labels.suggestions` (shared with collections, already
   tested) does the distinct/normalise/exclude/sort, so no second helper. Tags filter/browse stays
   ADR 0034 slice 3, gated on its consumer (planner). Tests: `tags` default `[]`.

`techniques` and `Loop.chords` are deferred (no slice). Collections promotion is trigger-gated
(no slice).

## Alternatives considered

- **Decide each field ad hoc as features need it.** Rejected — produced the tag/field
  confusion this ADR resolves; a shared taxonomy prevents re-litigating the same call.
- **Multi-value `genre` (`[String]`).** Rejected — overlapping group membership reworks ADR
  0035 for a marginal multi-genre case; single + normalise is the cheap correct fix.
- **Consolidate `bpm`/`preciseBPM` now.** Rejected — custom migration risk, zero user benefit.
- **Keep `progression` at song level / move to loop now.** Rejected/deferred — it's really
  per-section chord structure; `key` covers the song summary, and a loop chord field waits for
  a concrete need.
- **Derived-with-override song mastery.** Rejected for now — extra stored field + override
  state for a case (rate a loop-less song) that a loop-centric app rarely hits; pure-derived
  is simpler. Path stays open.
- **`focus` and `mastery` merged into one scale.** Rejected — conflates *need* (how well you
  play it) with *intent* (how much you want to focus on it); the planner needs both.
- **Promote `collections` to a `@Model` now.** Rejected — no order/metadata/empty-existence
  need yet; trigger recorded so the call isn't re-debated.

## Consequences

- Pocket has one explicit field taxonomy (intrinsic / scalar-enum / tag / grouping) and a
  two-question litmus test, so "is this a field or a tag?" is no longer a judgment call.
- The schema gains structured practice signal at the loop level (Mastery, Focus, Command
  Tempo, Type) and a derived song rollup — the exact inputs the planner (ADR 0014/0015)
  forecast, delivered before the planner needs them.
- Two non-lightweight migrations are introduced (lossy `proficiency` removal; `key` enum
  mapping) and called out for their build slices.
- Loop tags (ADR 0034) and the library (ADR 0035) build/operate against a settled model.
- Docs to update when slices land: `CHANGELOG.md` (user-visible field changes), `PROJECT.md`
  (data model), `docs/architecture.md` (the taxonomy + derived-mastery rollup), and `README.md`
  if the "How it works" summary names song/loop metadata. This ADR is design-only; no code or
  user-visible change ships with it.
