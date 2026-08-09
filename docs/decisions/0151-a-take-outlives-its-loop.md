# 0151 — A take outlives its loop

- **Status:** Accepted (2026-08-09) — targeted at **1.2**, not the in-review 1.1.
- **Date:** 2026-08-09

## Context

Deleting a loop today deletes every take recorded against it, and every note
written about it. `Loop.recordings`, `Exercise.recordings`, `Song.recordings`,
`Loop.journal` and `Exercise.journal` are all
`@Relationship(deleteRule: .cascade, …)`, so the child rows go with the parent
and `RecordingStore`'s orphan sweep then reaps the now-unreferenced audio. The
loop delete is deferred behind an Undo toast (ADR 0019 /
`WaveformPracticeModel+Delete.swift`), so the loss lands when the toast expires,
with no warning that anything beyond the loop is going.

**This contradicts a principle the codebase has already stated three times.**

- `PracticeRun.unitUID` — "a **loose copy**, deliberately not a relationship:
  the row outlives the unit."
- `PracticeRun.routineUID` — "deleting a routine must not erase the practice
  done in it."
- `JournalEntry.routineUID` + `routineNameAtEntry` (ADR 0143) — "deleting a
  routine must not delete the reflection written about it," with the routine's
  name snapshotted at write time so a deleted routine still labels its entries
  truthfully.

`JournalTabView+Deletion.swift` states the reasoning outright: "a deleted
exercise or routine can be rebuilt from the same idea, but a note about how a
session actually went — and a take of someone playing — has no way back." That
sentence is the argument for this ADR. It was applied to the *hold-to-delete
gesture* (making it deliberate) but never to the *cascade*, which destroys the
same irreplaceable rows without asking.

Two things made the inconsistency easy to miss and now make it worse:

1. **Takes present as top-level.** Journal ▸ Takes is an unfiltered
   `@Query` over every `Recording` — one flat list, Voice-Memos-shaped. A list
   like that promises "these are mine, they live here." Underneath, each row is
   still a cascade-owned child of a loop or exercise. The list makes a promise
   the delete rule does not keep.
2. **A take is the one artifact with no way back.** A loop is a start/end pair
   over a file; an exercise is a recipe. Both can be recreated in a minute. A
   recording of someone playing on a particular evening cannot be recreated at
   all.

## Decision

1. **A take outlives what it was recorded against.** `Loop.recordings`,
   `Exercise.recordings` and `Song.recordings` change from `.cascade` to
   `.nullify`. Deleting the owner clears the link and leaves the take.
2. **A unit-owned note does too.** `Loop.journal` and `Exercise.journal` change
   the same way, for the same reason and by the same sentence already written in
   `JournalTabView+Deletion.swift`. Session notes already behave this way; this
   removes the split where a reflection on a routine survives but a note on a
   loop does not.
3. **The caption is snapshotted at write time.** `Recording` gains
   `ownerLabelAtTake: String?` and `JournalEntry` gains
   `ownerLabelAtEntry: String?`, set when the row is created, mirroring
   `routineNameAtEntry`. `JournalTimeline.ownerLabel` prefers the live owner and
   falls back to the snapshot. Without this the change is a regression: once the
   relationships nullify, `label(loop:exercise:song:)` returns `nil` and a
   surviving take renders as a bare "Take 0:11" with no clue what it was.
4. **An orphaned caption is plain text, not a dead link.** When the owner is
   gone there is nowhere to navigate, so the caption renders untappable — the
   ADR 0142 honesty rule, already implemented (`JournalTakeRow` takes an
   optional `onOpenOwner`, and `SessionUnitChips` established the pattern).
5. **Nullify, not full decoupling.** The purist version — drop the
   relationships, store `ownerUID` + kind + label, exactly as sessions do — is
   the better design on a blank page and is **explicitly rejected here** on
   migration cost. Dropping relationships changes the store shape; changing a
   delete rule does not. Both produce the same user-visible behaviour, so the
   cheaper migration wins. The relationships stay and remain the fast path for
   the per-owner `TakesSheet` and `JournalSheet`.
6. **Deleting a take stays the user's decision.** The existing hold-to-delete on
   the Journal rows removes the row *and* its audio file, so takes surviving
   their owners does not mean unbounded storage — it means storage the user
   controls, which is the Voice Memos contract this whole change is honouring.

## Consequences

- **The delete toast becomes truthful.** "Deleted Chords" currently understates
  what happened; after this it is exactly what happened. No confirmation dialog
  or "this will also delete N takes" warning is needed, because the destructive
  part is gone. That is the reason for preferring this over warning-on-delete.
- **Files outlive their owners.** A take's audio is only reaped when its row
  goes, and the sweep already keys on surviving rows
  (`orphanedFiles(onDisk:referenced:)`), so nullified takes are safe by
  construction. The retention story shifts from automatic to user-driven.
- **The search index loses template text for orphaned takes.**
  `JournalTimeline.templateLabel` reads `take.exercise?.template`, which is
  `nil` once nullified. The snapshot label carries the owner's name into the
  haystack instead, so a take stays findable by what it was recorded against.
- **Migration must be verified on device, with real data.** Changing a delete
  rule is expected to be a lightweight/no-op migration since no entity,
  attribute or relationship shape changes, and the two new fields are additive
  optionals with **no declaration default** (exempt from the CoreData 134110
  mandatory-attribute rule). "Expected" is not "verified": SwiftData migration
  failures pass in-memory tests and trap on device
  (`docs/swiftdata-gotchas.md`), so this ships only after a real 1.1-install
  upgrade test.
- **Rows written before this change carry no snapshot, and are deliberately not
  backfilled.** There are no pre-existing orphans — the old cascade destroyed
  them rather than orphaning them — but a take *captured* before this shipped
  whose loop is deleted after it has no label to fall back on and reads as a bare
  "Take". That is accepted, on two grounds. The caption was never the only way to
  identify a take: the ADR 0069 amendment gave takes their own **names**, and a
  named take is identifiable with no owner at all — which is the same
  independence from a parent that this whole ADR is establishing. And the
  population is one device: 1.0 shipped with zero downloads and is off sale, 1.1
  is unapproved, so nobody else holds a pre-0151 take. A launch-time backfill was
  costed at roughly twenty lines and judged not worth carrying for a caption a
  rename already solves.
- **1.1 is untouched.** This needs a new build and is scoped to **1.2**, so the
  in-review 1.1 — whose outstanding fix is metadata-only — is not disturbed.

## Related

- ADR 0069 — practice-take recording (the cascade this revises, §5)
- ADR 0143 — session journal (`routineUID` + `routineNameAtEntry`, the pattern)
- ADR 0142 — journal reach (the owner caption and its honesty rule)
- ADR 0019 — instant loop create / undo toast (the deferred delete)
- ADR 0150 — a take is yours to send (the sibling question, parked)
