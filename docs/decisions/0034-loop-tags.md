# 0034 — Loop tags: the loop-level annotation axis (`[String]`, normalize/suggest, filter gated on a consumer)

- **Status:** Accepted (design recorded; build sequenced — annotation slice now, the cross-song payoff lands with its first consumer)
- **Date:** 2026-06-22

## Context

Pocket has two scope-distinct annotation axes. ADR 0033 fixed the naming so the
question "is this a tag or a collection?" is never a judgment call: the word follows
**what you annotate**.

- **Collections = song-level** — curatorial groupings of whole songs ("gig setlist").
  Stored as `[String]` on `Song`; normalize/suggest/filter built per ADR 0033.
- **Tags = loop-level** — descriptive facets on a single loop ("solo", "needs-work",
  "chorus"). This ADR.

Loop tags were unblocked by ADR 0032, which made loops **addressable across the whole
library by `Loop.uid`** without a SwiftData relationship. 0032 names this exact feature
as a future user of its path: *"a future loop-tag feature (cross-song 'build a session
from my `needs-work` loops') reuses the same path — query loops by tag to assemble
candidates, resolve by uid to play."* So the deep-link/play mechanism a tag-driven
session needs already exists in decision form.

Relevant model facts:

- `Loop` is a cascade-delete child of `Song` and carries a stable `uid: UUID`
  (`Song.swift`). It already holds `[String]`-free scalars plus optional override fields
  (`colorIndex`, `customColorHex`) that use **declaration defaults** so SwiftData
  lightweight migration fills pre-existing rows without a store wipe (the CoreData 134110
  note, ADR 0012).
- A loop is edited in `LoopEditSheet` (`WaveformEditSheets.swift`) — opened by holding a
  loop row (ADR 0028). It has Name / Range / Colour / Delete sections. This is the
  loop-level edit surface, the analogue of `SongEditSheet` for songs.
- There is **no top-level loop browser** today (ADR 0032): the only `@Query` is
  `LibraryView` over `Song`; loops load via `song.loops`. A cross-song "loops filtered by
  tag" surface does not exist yet — it arrives with the Phase-3 planner (ADR 0014) or a
  dedicated loop browser.

The honest tension this ADR has to resolve: ADR 0033 criticised collections for being
**write-only decoration — "a grouping you can't filter by is just a note."** Loop tags
have the same failure mode, but worse: the surface that would filter by them
(cross-song loop browse / planner candidate assembly) **does not exist yet**, whereas
`LibraryView` already existed for collections. We must not ship tags that nothing reads.

## Decision

Adopt loop tags as a **`[String]` annotation on `Loop`**, mirroring `Song.collections`
exactly — same storage shape, same normalisation, same suggest-from-existing
convergence — and **reuse ADR 0033's machinery rather than reimplement it**. But
**sequence the build** so tags never ship as write-only decoration: land the annotation
+ normalise + suggest slice now (tags become real, clean, reusable data), and land the
**filter/browse payoff together with its first cross-song consumer**, not before.

### Stay `[String]` on `Loop`; do not promote to a `@Model`

Add `var tags: [String] = []` to `Loop`, with the **declaration default** (not init-only)
so SwiftData lightweight migration fills loops saved before this slice — same rule as
`colorIndex`/`automatorEnabled`/`Song.collections` (CoreData 134110 / ADR 0012). The same
volume reasoning as ADR 0032/0033 applies: filtering/aggregating over `[String]` is
trivial for a single-user library of hundreds-to-low-thousands of loops. No relationship,
no `Tag` `@Model`. The forward-compatible promotion path (to a `LoopTag` `@Model` with
per-tag metadata) stays open and explicitly out of scope, exactly as 0012/0033 keep it for
collections.

### Reuse ADR 0033's normaliser — do not write a second one

ADR 0033 slice 1 introduces a pure, SwiftData/SwiftUI-free canonicaliser
(trim → collapse internal whitespace → reject empty → case-insensitive de-dup, first-seen
display form preserved). That canonicaliser is **scope-agnostic** — it operates on a list
of strings, not on songs. Loop tags route their writes through the **same module**. This
is a build-ordering constraint on ADR 0033: implement the normaliser as a free
function/type over `[String]` (e.g. `TagNormalizer` / `CollectionNormalizer` in `Core`),
**not** bolted onto `Song`, so `Loop` reuses it with zero duplication. One canonicaliser,
two callers. (Recorded here so the collections build — done next — picks the reusable
shape up front rather than refactoring later.)

### Suggest from existing tags across the library (reuse over re-entry)

`LoopEditSheet` gains a **Tags** section that mirrors `SongEditSheet`'s collections UI:
an add field plus tappable suggestion chips offering tags **already used on any loop in
the library** (distinct, normalised, excluding ones already on this loop); tapping adds
the canonical form; swipe/✕ removes. This is the convergence mechanism — the whole point
of tags is many loops sharing the *same* one ("needs-work" across songs).

Aggregating "all tags across all loops" needs a loop-wide read, which 0032 notes the app
lacks. Get it the way 0032 prescribes: a `FetchDescriptor<Loop>` (all loops) reduced to a
distinct normalised tag set — the same top-level-loop-fetch capability 0032's
`loop(for: uid)` helper establishes. No relationship required.

### Filter / browse by tag — the payoff, gated on a consumer

Selecting a tag yields its loops **across songs** (intersection/AND for multi-select, like
0033's collection filter), each resolvable to playback by `uid` (ADR 0032). This is the
real value of loop tags, and it is **deferred until the surface that hosts it exists**:

- the **Phase-3 planner** (ADR 0014) assembling candidates — "build a session from my
  `needs-work` loops" — which is precisely the consumer ADR 0032 forecast; or
- a dedicated **cross-song loop browser**, if one is built before the planner.

Whichever lands first carries the tag filter (pure, unit-tested predicate, reusing 0033's
filter shape). We do **not** build a filter with no surface to put it on just to avoid the
"write-only" charge — instead we keep the annotation slice **small and cheap** so the data
is clean and converging by the time a consumer arrives, and the consumer ships the filter
as part of its own build. The anti-pattern 0033 warned about is avoided not by forcing a
premature filter but by not shipping the tag UI prominently until it pays off (see Build).

### Naming hygiene

User-facing label is **"Tags"** (loop scope), never "Collections". In code, the loop axis
is `tags` / `tag`; the song axis stays `collections` / `collection`. ADR 0033 already
renames the stray `tag` local in `SongEditSheet` → `collection` so the vocabularies don't
blur — that rename is a prerequisite, owned by the collections build.

## Build (sliced)

1. **Model + normaliser reuse.** Add `Loop.tags: [String] = []` (declaration default;
   migration-safe). Route tag writes through ADR 0033's scope-agnostic normaliser
   (built as a `Core` module over `[String]`, per the constraint above). Pure aggregation
   helper: distinct normalised tags across a loop set (+ tests: distinct, sorted, excludes
   current loop's tags, normalised). No prominent UI yet.
2. **Tags section in `LoopEditSheet`.** Add field + suggestion chips mirroring
   `SongEditSheet` collections; swipe/✕ remove; cross-loop suggestions via
   `FetchDescriptor<Loop>` aggregation. Tags become editable and converge.
3. **Filter/browse — deferred, ships with its consumer** (planner ADR 0014 or a loop
   browser). Pure tag-filter predicate (intersection semantics; + tests), resolve matches
   to playback by `uid` (ADR 0032). Not a standalone branch — folded into the consumer's
   build so tags arrive with a payoff.

Slices 1–2 are the "now" work and can follow the collections build (which proves the
shared normaliser). Slice 3 is gated, not scheduled.

## Alternatives considered

- **One shared axis named "Tags" for both songs and loops.** Rejected by ADR 0033 — it
  reintroduces the song/loop ambiguity that scope-based naming removes. Two axes, two
  names, one shared `[String]` mechanism.
- **Promote to a `LoopTag` `@Model` now.** Rejected — same reasoning as 0032/0033:
  filtering/aggregating `[String]` is trivial at this volume; a relationship + per-tag
  metadata + CloudKit/migration surface isn't earned until a real per-tag-metadata or
  browsable-tag need exists. Promotion path stays open.
- **Ship the tag annotation UI prominently now, filter later.** Rejected — that is exactly
  the write-only-decoration failure ADR 0033 called out, just relocated to loops. Keep the
  annotation slice small and let the consumer surface the payoff.
- **Build a standalone cross-song loop browser now to host the filter.** Rejected for this
  ADR — that is a substantial feature (a second top-level `@Query` surface, navigation,
  empty states) whose scope and shape belong to the planner work or its own ADR, not to the
  tag decision. Sequencing tags behind it keeps this ADR about the annotation axis.
- **Separate normaliser for tags vs collections.** Rejected — duplicated logic drifts.
  One scope-agnostic canonicaliser over `[String]`, two callers. This is why ADR 0033's
  slice 1 must build it free-standing in `Core`.
- **Denormalized tag snapshot copied into routine items (Phase 3).** Rejected for the same
  reason ADR 0032 rejected denormalised loop snapshots — the routine must point at the
  *live* loop (resolve by `uid`), so it reads the loop's current tags, never a stale copy.

## Consequences

- Loop tags are the **loop-level half** of the annotation model; with ADR 0033's
  collections, Pocket has a clean two-axis system (Collections = songs, Tags = loops) that
  never blurs.
- The annotation slice reuses ADR 0033's normaliser and suggestion pattern wholesale — the
  collections build, done next, must produce the normaliser as a **scope-agnostic `Core`
  module** so this reuse is free. (Cross-ADR build constraint recorded.)
- Tags are stored as `[String]` on `Loop` with a declaration default — additive,
  migration-safe, no store wipe, CloudKit-clean (a scalar array syncs intact, like
  `collections`).
- The cross-song payoff resolves loops by `uid` (ADR 0032), needing **no schema
  relationship** — the planner's "session from my `needs-work` loops" is the forecast
  consumer and carries the filter.
- We deliberately **avoid shipping write-only tags**: the annotation slice is cheap and the
  filter is sequenced with the surface that reads it, rather than built into a vacuum.
- When the slices build: update `CHANGELOG.md` (loop tags are user-visible), `PROJECT.md`
  (loop annotation axis), and note the shared normaliser/aggregation modules in
  `docs/architecture.md`. This ADR is design-only; no code or user-visible change ships
  with it.
```
