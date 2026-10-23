# ADR 0275 — References group by site, or by where they're used

- **Status:** Accepted. Built 2026-10-23 on `pocket-389-group-references`, and checked on a device by
  Tomisin the same day. See §Build notes.
- **Date:** 2026-10-23
- **Amends:** ADR 0264 — **D4**: the library's two sections, *Not filed* then *Everything*, become the
  default of three layouts, chosen from an ⋯ menu (D1). Slice 2's build note 2 left ⋯ off until it had
  something to hold, and this is that. The rest of D4 stands: the Toolkit row, the search, a row's
  lines (with D2's one exception) and ＋.
- **Relates to:** 0035 (the song library's grouping, the pattern this follows) · the v2 close-out's
  slice 5 (sections that fold, `CollapsibleLibrarySection`) · 0126 (⋯ before ＋) · 0167 (a link's site
  is read on the device from its address; D3 here folds three more spellings of it) · 0210 (folders for
  drills and routines, the other kind of grouping, not taken here)
- **Schema:** none. Two `UserDefaults` keys.

## Context

Tomisin: *"is there a way we could group references in the references feature?"*

The library lists every source newest first, in two sections: what isn't filed and everything else.
*Save to Red Moon* (0264 D8) keeps a share for later by default, so *Not filed* is where the pile
grows, and most of it comes from one or two sites.

There are two kinds of answer. The library can be grouped by **what it already knows**: a link's site,
or what a source is filed on. Or the player can **make groups**, as 0210's folders do for drills. The
first needs no new data. The second needs a field on every row of a source (0264 D3), a backup field,
a place in the share extension's picker, and an answer to whether a reference in a folder still counts
as *Not filed*. Tomisin chose the first.

## Decisions

### D1 — Three layouts, from ⋯

The library's toolbar gains 0126's ⋯, before ＋. It holds one choice:

- **Newest**: 0264 D4's *Not filed* then *Everything*, as before. The default, so a library opens as it
  always has.
- **Site** (D2).
- **Where it's used** (D4).

The choice is kept on the device (`AppSettings.Key.referencesGrouping`). ⋯ shows only when the library
holds something: a choice that changes nothing is a control that does nothing, the reason slice 2 left
it off.

### D2 — Site: every source under its site, filed or not

A section per site, A to Z as a person reads them (`localizedStandardCompare`). Then one per kind of
file, since a file has no site: *Pictures*, *PDFs*, *Text files*, *Markdown files*. Then *Other*, for a
link with no site to read, which only a row written by hand or by a newer build can be.

- **Not filed has no section of its own here.** The pile that most needs grouping is the one kept for
  later, so it's grouped too. A source filed nowhere sits with the rest of its site, and its row says
  *Not filed yet* where a filed row says where it's used. Those are the source screen's words for the
  same state.
- **A row drops its site.** The heading says it, and the same word on every row of a section says one
  fact twice. The row's second line is the day it was saved.

### D3 — A site is what the row already says, folded further

The heading is `ReferenceURL.displayHost`, the site every reference row in the app shows under its name.
It already dropped `www.` and folded case. It now also drops a phone's `m.` and `mobile.`, and reads
YouTube's short links, `youtu.be`, as `youtube.com`, since YouTube's own share sheet hands those out.
Without that, one channel's lessons would sit under three headings.

- **One function, so every screen agrees.** Folding only for the heading would make a row under
  *youtube.com* read *youtu.be*, and an exercise's References section disagree with the library.
- **Other subdomains are kept.** `tabs.ultimate-guitar.com` and `music.youtube.com` are parts of a
  site, not copies of it. A prefix is dropped only when a domain is left (`m.com` stays).
- **No brand names.** A table turning `youtube.com` into *YouTube* would need upkeep and would disagree
  with the row's own line.

### D4 — Where it's used: Not filed, then each kind of place

*Not filed*, then *Exercises*, *Routines*, *Songs* and *Loops*, in *Show everything*'s order (0264 slice
3, note 6). A source used on more than one kind of place is under each. On two drills, it's under
*Exercises* once. A filed source that also has a row kept for later is filed (0264 D3), so it isn't
under *Not filed*. Rows read as under *Newest*: the places line says which drill or song.

### D5 — The groups fold, as every library's do

Under *Site* and *Where it's used*, sections are `CollapsibleLibrarySection`, with the count always
shown, as the songs, exercises and loops libraries have them. What's folded is kept per layout
(`LibrarySectionExpansion`'s scope), and a search opens every section, so a match can't hide in a
folded one. *Newest*'s two sections stay as 0264 D4 drew them and don't fold: folding *Not filed* would
hide what the Toolkit row counts.

### D6 — Search first, then group

A search keeps the sources it finds, under any layout. A section it empties goes, and nothing found
reads as it did.

## Not decided here

**Groups the player makes**, such as folders on references. This isn't rejected. If the layouts above
don't answer it, it needs its own ADR, which would start from the four questions in the Context.
Tomisin, having used the three on a device: *"it's a good start, maybe further down the line we could
expand."* Nothing about what that expansion is was decided here.

## Build notes (2026-10-23, `pocket-389-group-references`)

- **Built:** `ReferenceGrouping` and `ReferenceLibrary.groups(_:by:matching:)`, both pure;
  `ReferenceURL.displayHost`'s folding; `ReferenceLinkKind.pluralTitle`; the ⋯ menu and the folding
  sections on `ReferencesLibraryView`; `ReferenceSourceRow`'s `showsOrigin` and `marksNotFiled`. The
  two keys are in `AppSettings+References`, and both are cleared at launch under `-uiTesting`, beside
  the other list preferences, so a test that groups by site leaves no later test or figure grouped.
- **Tests:** `ReferenceGroupingTests` (12), three new `ReferenceURLTests` and one renamed and widened, and
  `ReferenceFilingUITests.testTheOptionsMenuGroupsTheLibraryBySiteAndByWhereItsUsed`, which picks all
  three from ⋯ and folds and reopens a site's section. It finds headings by their accessibility
  label, never their text, which iOS 18 draws in capitals. Its screenshots of *Site* and *Where it's
  used* were looked at.
- **Mutants:** 15, in three batches with no two on one line, each with a witness test no other mutant
  in its batch could fail. Every one failed its witness. The first plan put dropping `m.` beside
  dropping the guard that keeps `m.com` whole. With `m.` gone, `m.com` never reaches the guard, so
  its test couldn't tell whether the guard was there. Found by reading, before the run; the two ran
  apart.
- **On a device** (Tomisin's iPhone, a `run-device.sh` build), Tomisin tried all three layouts: *"I'm
  happy with this"*, and *"it's a good start, maybe further down the line we could expand."*
- **The manual's library figure** (`references/library`) now lacks the ⋯ beside ＋. It is left for the
  next reshoot.

## Alternatives rejected

- **Keeping *Not filed* on top under *Site*, and grouping only the rest.** The kept-for-later pile, the
  one that grows, would never be grouped. D2.
- **A section per place, not per kind.** Most drills hold one or two references, so it would be a list
  of one-row sections: 0210 D7's lesson, a list drawn as folders.
- **Brand names for sites.** D3.
