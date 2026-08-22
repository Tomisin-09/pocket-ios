# ADR 0177 — a routine that explains itself

- **Status:** Accepted
- **Date:** 2026-08-22 (`pocket-280-a-routine-that-explains-itself`)
- **Relates to:** ADR 0066 (the routine model and its sandboxed editor), ADR 0071 (the Edit
  gate this field sits behind), ADR 0112 (the seeded starter routine), ADR 0136 (the freeform
  block, where `Exercise.notes` stops being a note *about* the drill and becomes the drill —
  the precedent for how much weight this shape can carry), ADR 0167 (**Where you learned it**,
  the section this one sits directly above), ADR 0173 (the length-and-history section, the
  previous entry in the same backlog list)
- **Schema:** additive. One `String` with a declaration default on an existing `@Model`, under
  the freeze that permits exactly that (CoreData 134110 rule).

## Context

**A routine could say where it came from and still not say what it was for.**

`Routine` carried `uid`, `name`, `dateAdded`, `lastPracticed`, `isFavorite`, `presetSlug`,
`items` and — since ADR 0167 — `references`. No prose of its own. Every other practice unit
has had some since it shipped: `Exercise.notes` (surfaced as **Description** on the exercise
detail sheet) and `Song.comment` (surfaced as **Notes** on the song edit sheet).

ADR 0167 sharpened the gap rather than closing it, and said so in its own doc comment: a
reference link is a *pointer*, and pointers are not prose. After it landed, a routine's only
words about itself were its name and a list of link titles. `docs/backlog.md` (Routines, item
2) has held this open since 2026-08-16, out of the positioning work that found routines have
less surface than looping does.

The name is the wrong place to put it. A name is what you pick a routine by in a list, so it
is short by function — and everything that does not fit ("the bits of the week 3 sheet that
actually needed work", "shorter version for the days there isn't time", "warm up cold, don't
skip the rests") has had nowhere to go.

**Under the multiplier thesis this is not a nicety.** `docs/positioning.md` §1 puts the
routine at the centre: a session is what a teacher hands over, and a handed-over session that
cannot state its own purpose arrives as a list of drills in an order, with the reason left
behind in whatever conversation produced it.

## Decision

**`Routine` gains `notes: String = ""`, surfaced as a **Description** section on the routine
detail screen, above **Where you learned it** and behind the same Edit gate as everything else
on that screen.**

### D1 — a plain `String` with a declaration default, not an optional

`""` and `nil` express the same thing here — no prose — and `""` does it without an unwrap at
every reader. This is `Exercise.notes`' exact shape, and it is also what the CoreData 134110
rule asks for: a declaration default makes the add a lightweight migration that fills every
existing routine with `""`, so no store is wiped.

Rejected: `String?`. It would have bought a distinction between "never written" and "written,
then emptied" that nothing in the app has a use for, at the cost of being the one prose field
in the schema shaped differently from the other two.

### D2 — named `notes` in the model, called **Description** on screen

This looks like an inconsistency and is the opposite of one. `Exercise` already does exactly
this: the field is `notes`, the section header is **Description**. Matching the exercise means
the two practice units a player thinks of as siblings behave identically, and means a future
reader grepping `\.notes` finds both.

Song is the outlier (`comment`, shown as **Notes**), and it stays the outlier — renaming a
stored property to tidy a naming scheme is a migration paid for nothing.

### D3 — the Edit gate, exactly as the name and the blocks have it

Editable when `isEditing || !existsInStore`; read-only otherwise. That is the screen's
existing contract — **Cancel discards, Save keeps** — and the manual already states it for
this screen. A field that persisted immediately would break it in a specific and ugly way:
outside edit mode there is no Save, so the text would sit in the sandbox until the next Cancel
silently dropped it.

The `!existsInStore` half matters. A provisional generated session is a template the player
customises before the single Save commits it, and it is named inline on that review screen
(ADR 0066 R1b). Making them describe it only after keeping it would gate the field behind
nothing.

### D4 — no `@State` draft; it binds straight to the sandbox

`ExerciseDetailSheet` stages its notes in local state and writes them on Done. It has to: it
edits the live store, and a draft is its only way to be cancellable. `RoutineDetailView`
already has a better one — the routine is faulted into a private `ModelContext` with autosave
off — so typing here is provisional by construction. Layering a draft on top of a sandbox
would mean two undo stories for one field, differing at the edges.

### D5 — it is **not** gated on `existsInStore` the way the links beside it are

The one place this field's rules differ from ADR 0167's, and the reason is structural. A
`ReferenceLink` is a separate `@Model`: attaching one to a provisional session inserts a row
through a relationship, which quietly keeps a routine the player never chose to keep. A
description is a `String` on the routine itself and can persist nothing that the routine's own
Save does not.

### D6 — read-only and empty draws nothing

Not a "No description" row, not a greyed placeholder. Two reasons, and the second is the one
that decided it:

1. It is clutter on the many to advertise a field to the few — most routines will never have
   one, and the section would appear on all of them forever.
2. It is a standing note about a thing the player has not done, which is the register
   `docs/design-brief.md` §3.5 rules out. ADR 0173 turned the same corner three days earlier
   and for the same reason: it omits its count line entirely at zero rather than saying
   "Practised no times".

The field is found where every other change to a routine is found — behind **Edit**.

### D7 — the description counts as content when Save decides an empty routine is abandoned

`saveEdits()` dismisses a brand-new routine with no name and no blocks rather than leaving an
empty shell in the library. The description now joins that test. A routine with prose and
nothing else is thin, but it is something the player typed, and discarding it on **Save** —
the button that means keep — would be the screen throwing work away without saying so.

### D8 — trimmed at the commit sites, never on read

`trimDescription()` runs in `saveEdits()` and `commitProvisional()`. The field is a vertical
`TextField`, so a trailing newline is the common case, not an exotic one — and a description
of one stray newline would otherwise pass the `!notes.isEmpty` test in D6 and draw an empty
section on the read-only screen. Trimming on write means the stored value is the value every
reader sees.

The **name is deliberately left untrimmed**. It is committed through two paths with their own
trimming and de-duplication (`commitProvisional` → `QuickSessionNaming`), `RoutinePresets.slug(forName:)`
matches names exactly, and quietly rewriting a stored routine's name is a behaviour change
this feature has no business making.

### D9 — the seeded starter routine ships with one

`RoutinePresets.Spec` gains `notes`, and **Morning Routine** carries a description. The
starter routine is the demo shown whole (ADR 0112), so it demonstrates the field by having one
rather than by arriving blank — the same reason `PracticePresets` ships its exercises with
`notes` already written. The spec field is a `var` with a default, because Swift drops a
defaulted `let` from the memberwise initialiser.

Unlike `slug`, it is ordinary copy and may be reworded freely. It deliberately states **no
number of minutes**: the same screen computes an **Estimated length** from the blocks, and
prose that names a duration is prose that can contradict the row above it.

## Rejected

- **Showing the description on the Routines library row.** The row already carries two derived
  lines after ADR 0173 (*4 blocks · 2 rests* / *Practised 11 times · 3 days ago*). A third
  line of free text — unbounded, and the only user-authored one — would crowd out the two
  facts that are there to be compared at a glance. The description is read on the screen you
  open to decide, not on the list you scan.
- **Making it searchable now.** Backlog Routines item 3 (a routine cannot be found — no search,
  no sort) is a separate piece of work, and when it lands the description should be one of the
  fields it matches. Building half of a search here would mean a field that matches in one
  place and not another.
- **Showing it in the player, before or during a run.** Defensible, and not this ADR: the
  player is a screen with a strict attention budget (ADR 0071), and what a session is *for* is
  read while choosing it, not while playing it. Revisit on evidence.
- **A rich-text or markdown field.** Nothing else in the app has one, and a formatting layer on
  a note nobody has yet asked to format is the definition of premature.

## Consequences

- One additive field. Existing routines migrate to `""` and render exactly as before, because
  D6 draws nothing for them.
- `Routine` is no longer the practice unit without prose, which closes backlog Routines item 2.
  Items 3 (find), 4 (give away), 5 (hand-author every kind) and 6 (one seeded routine) stay
  open, and item 4 gets slightly easier: a routine that is handed over now has somewhere to
  carry its own explanation, so whatever `Codable` shape export eventually takes has one more
  field worth carrying and one less reason to lean on the name.
- `RoutineDetailView.swift` sits at the file-length cap, so the name section moved out with the
  new one into `RoutineDetailView+Prose.swift`. The two belong together: they answer the same
  question — *what is this session?* — at different lengths, and they share one edit gate.
- The manual gains a paragraph on the routines page. No new shot marker: the section renders in
  the same list as the history section already photographed, and Phase 5 is paused.
