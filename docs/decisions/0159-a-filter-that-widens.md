# ADR 0159 — a filter that widens

- **Status:** **Accepted — built 2026-08-12** (branch `pocket-252`)
- **Date:** 2026-08-12
- **Supersedes:** ADR 0033's *"Filter the library by collection"* clause, narrowly — the relation
  only. Normalisation, suggestion and the `[String]` storage decision all stand untouched.
- **Relates to:** ADR 0118 (`CollectionSessionBuilder`, the one caller that cares how many
  collections are selected) · the parked *filter on the list screens* backlog item, which inherits
  the rule this sets

## Context

A device-testing note, with a screenshot: tick **Covers**, tick **Ocean's Trilogy**, and the Songs
library says *"No songs in this collection"*.

Nothing is broken in the sense of a crash or a lost row. The filter is doing exactly what ADR 0033
told it to do:

> Selecting collections narrows the song list by **intersection (AND)** — a song matches if it
> contains **all** selected collections.

`LibraryView` calls `Labels.matches(_:allOf:)`, which is an `allSatisfy` over the selection. Two
collections ticked means "songs filed in both at once". In a personal library that is almost always
none, so the control's second tap reliably empties the screen.

### The decision was made, but the case was never argued

ADR 0033 states the relation outright, so this is not an oversight being discovered. What is worth
looking at is the justification it offers, in full:

> the common single-select case is AND-of-one (tap a collection → its songs, playlist-like).

That is the entire argument, and **it is about the one case where AND and OR are identical**. Ticking
one collection returns the same songs under either relation. So ADR 0033 chose a multi-select
behaviour while reasoning only about single-select, and the multi-select semantics fell out of
whichever Swift method got written — `allSatisfy` rather than `contains`.

The ADR's own chosen word points the other way. **"Playlist-like"** is exactly right, and a player
who ticks two playlists is asking to see both of them. Nobody has ever opened two playlists hoping
for the tracks that appear on both.

## Decision

### 1. Multi-select within one facet is a **union**

`Labels` gains `matches(_:anyOf:)`, and `LibraryView`'s collection filter calls it. A song shows when
it carries **any** of the ticked collections.

The general rule this instantiates, which the wider filter work will need anyway:

> **OR within a facet, AND across facets.**

Every list UI a player has priors from works this way — Finder tags, Photos albums, Music playlists,
every faceted sidebar on the web. Within one axis, adding a tick **widens**; across axes, adding a
constraint **narrows**. The current implementation had adding a tick within one axis narrowing, which
is why the control felt broken rather than merely surprising.

### 2. `allOf` is kept, and is not deprecated

It stays for two reasons, both live:

- **It is the right relation across facets.** When collection, instrument and favourite compose into
  one filter, the relation *between* them is AND. That work is parked (the *filter on the list
  screens* backlog item), and this decision is the rule it should be built on rather than a hint.
- **`CollectionSessionBuilder` asks it of a single label** (`allOf: [collection]`). AND-of-one, where
  the two relations agree, so it is unaffected either way and was deliberately left alone rather than
  churned for uniformity.

Both take an empty selection as "no filter", identically. That symmetry matters more than it looks:
clearing a filter must not behave differently from never having set one.

### 3. Two strings that were true only while one collection could be ticked

- **The empty state** read *"No songs in this collection"* — singular, and written when the plural
  case could not arise. It now reads *"these collections"* above one. Under a union an empty result
  is also much rarer, and means something a player can act on: *none* of these has a song in it.
- **The filter's accessibility label** read *"Filtering by 2 collection(s)"*, which states the count
  and hides the relation. A sighted user could at least infer the relation from the list; a VoiceOver
  user had nothing. It now says *"Filtering by any of 2 collections"*.

### 4. `collectionSessionBar` keeps its `count == 1` gate

Re-read rather than assumed, since it is the only caller that branches on how many collections are
selected. ADR 0118's generated session needs a **single** collection in focus to have something to
build from and to name the button after, and that is still true under a union — two ticked
collections is still not one collection in focus. Unchanged.

## Consequences

- The change is one method, one call site and two strings. The predicate was already pure and
  isolated in `Labels`, which is what makes this small — ADR 0033's decision to unit-test the filter
  predicate paid off at exactly the moment the decision it encoded turned out to be wrong.
- **Two existing tests flipped meaning but not correctness.** `testMultiSelectRequiresAllSelected`
  was renamed to `testMultiSelectAllOfRequiresEverySelected` and kept: intersection did not become
  wrong, the library filter simply stopped using it. Deleting them would have thrown away the
  coverage `allOf` still needs for its remaining callers.
- **An empty result is now genuinely informative.** Before, an empty library was the *expected*
  outcome of an ordinary two-tap gesture, so the empty state carried no signal. Now it means none of
  the selected collections has anything in it.
- The parked filter project inherits a stated rule instead of a fourth idiom. That backlog item's own
  advice — converge the matchers before designing the affordance — is unchanged and still the right
  order; this just fixes the one that was returning wrong answers today.

## Alternatives considered

**Leave it as AND and explain it in the UI.** A footer, or a "matching all" label. Rejected: it
documents a behaviour nobody wants rather than fixing it, and it spends the scarcest thing on the
screen — the player's attention — on justifying a relation they did not choose.

**An AND/OR toggle in the filter menu.** Honest, and genuinely more powerful. Rejected as the wrong
trade for this app: it makes every player answer a set-theory question to use a filter, to serve a
case (songs in two collections at once) that a personal library rarely has and that search already
handles. If cross-facet filtering later makes the relation genuinely ambiguous, revisit — but a
toggle is a poor substitute for a sensible default.

**Promote collections to a `SongCollection` `@Model` and browse them as real playlists.** The
long-standing forward path ADR 0012 and 0033 both describe, and it would dissolve the question by
making a collection something you *open* rather than something you filter by. Rejected here as
disproportionate: it is a schema change and a new browse surface to fix a one-line predicate, and
ADR 0033's promotion triggers (per-collection metadata, rename-across-library, pinned order) still
have not fired.
