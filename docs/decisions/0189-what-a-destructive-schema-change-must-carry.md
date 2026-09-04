# ADR 0189 — what a destructive schema change must carry

- **Status:** Proposed — this ends a rule that has protected the store for a year, so it is the
  owner's to accept. Written because ADR 0188 said ending the freeze *"is a separate decision and
  should be written as one"*.
- **Date:** 2026-09-04
- **Relates to:** ADR 0181 (the export that started this), ADR 0188 (the restore that finished it —
  its Consequences are the argument this answers), ADR 0036 (the field audit, and the enum-attribute
  crash that is the only migration this project has ever actually broken), ADR 0012 (the
  migration-exempt shape), ADR 0090 (stable `uid`s), ADR 0152 (relinking, which is what a restored
  song needs)
- **Schema:** none. This ADR is about how a future schema change is allowed to happen.

## Context

**The schema freeze has never been written down.** It has governed every `@Model` change since
2026-08-07 and lives in an assistant's memory file plus a handful of parenthetical asides in
`docs/backlog.md`. That is the first problem, independent of whether the rule is right: a
constraint on all future data modelling with no written home cannot be argued with, cannot be
scoped, and cannot be lifted — because there is nothing to lift.

**What it actually says, once reconstructed.** It began as a submission-window rule: 1.1 was in App
Store review, and a destructive `@Model` change that mis-migrates on a real device is unrecoverable.
The audit of 2026-08-07 then narrowed it considerably, and that narrowing is the part worth keeping:

- **Adding** an optional or defaulted primitive is safe, before or after the freeze. This is the
  migration-exempt shape (CoreData 134110), and it is what `RoutineItem.orphanLabel` used in ADR 0188
  S2 while the freeze was fully in force.
- **Retyping, renaming or removing** an existing column is the unsafe kind.
- The ADR 0036 crash was **not** "a new field broke migration" — it was a new **custom enum**
  attribute, which has no value to decode for old rows. Additive primitives were never the failure
  class.

So what the freeze governs today is narrow: retypes, renames, removals. The audit also found that
the only genuinely now-or-never item in the whole backlog (`Song.bpm`/`preciseBPM`, `Int` → `Double`)
had **already been rejected on its own merits**. A year on, the freeze has not blocked one thing
anybody wanted to do.

**What ADR 0188 changed, stated precisely.** 0188's Consequences claim the freeze "rests on *a bad
migration is unrecoverable*", which 0181 made false for anyone holding an archive and 0188 S3 made
false for anyone who can read one back. Building S3 turned up three facts that make the real
statement narrower than that:

1. **The restore door is unreachable when it is most needed.** `PocketApp` uses
   `.modelContainer(for:)`, the SwiftUI convenience, which **traps** if the container cannot be
   created. A migration that fails does not present an error — the app fails to launch, every launch.
   No screen is reachable, Restore included.
2. **The recovery path is therefore delete-and-reinstall**, then restore into the empty library. That
   works, and it is exactly the two-step path ADR 0188 D6 already described for a player who wants to
   replace their library. But it is not "open Settings and put it back".
3. **A restore is not lossless.** Song audio is not in an archive at all, so every song comes back
   needing a relink (ADR 0152); take audio comes back only if the export was taken with *Include
   recordings* on.

And a fourth fact, which is the one that matters most:

4. **There is no automatic backup.** Export is a manual, opt-in action a player must have thought to
   perform. So the recovery 0181 and 0188 built exists only for players who used it — and the failure
   this freeze guards against would fall hardest on exactly the players who never did.

**One more thing the code says.** There is no `VersionedSchema`, no `SchemaMigrationPlan` and no
`MigrationStage` anywhere in `Pocket/`. Every schema change this app has ever shipped has ridden on
SwiftData's implicit lightweight migration. A destructive change would not merely be risky — it would
be the first time this project wrote a migration at all.

## Decision

**Replace the freeze with criteria.** The prohibition ends; what replaces it is not permission but a
list of things a destructive change must carry. Adding an optional or defaulted primitive stays what
it has always been: ordinary work, needing none of this.

### D1 — say why additive cannot do it

A destructive change is a retype, a rename, or a removal. Every one of them has an additive
alternative — a new column beside the old one, written by both and read by preference — and the
additive version is migration-exempt. So the first thing a destructive change must carry is the
argument that the additive shape is genuinely worse, not merely less tidy.

The evidence that this bar is high: the 2026-08-07 audit walked every parked item implying a stored
field and found exactly one that needed a destructive change. It was rejected for "zero user
benefit", and is still rejected.

### D2 — ship a migration, tested against a store the *previous build* wrote

A `VersionedSchema` and a `SchemaMigrationPlan`, and a test that opens a store **written by the
build before**, not a fresh one. A migration test that seeds its own store in the new shape passes
without ever exercising the upgrade path, which is the one thing it exists to exercise.

This project has never written one. That is a cost of the first destructive change, and it belongs
to that change rather than being amortised in advance.

### D3 — verify the upgrade on a device

The ADR 0036 crash was device-only: in-memory tests missed it entirely, because a fresh in-memory
container has no old rows to fail to decode. A destructive change is verified by installing the
*previous* build, using it enough to write the affected rows, then installing the new one over it.

### D4 — never a raw custom enum attribute

The actual failure class, named so it is not rediscovered. Enum-backed columns are stored raw and
resolved on read — which is also why both of ADR 0188's doors assign raw columns rather than typed
setters.

### D5 — the release must be one a player could have exported from

Satisfied from 1.2 onward, since 0181 shipped export and 0188 S3 shipped restore. Recorded because it
is the precondition the whole argument rests on, and it was **not** true for 1.0 or 1.1.

## Alternatives considered

**Keep the freeze.** It has cost nothing in a year, which is an argument for keeping it — but that is
because destructive changes are rare, not because the rule is doing work. Meanwhile an unwritten
prohibition with no criteria is the kind of rule that gets ignored the first time somebody really
wants something, with none of D1–D4 in place. Criteria that are followed beat a ban that is
eventually stepped over.

**Lift it outright, on the strength of ADR 0188.** Rejected: that reads 0188's Consequences as
stronger than the code supports. A restore that requires a delete-and-reinstall, loses song audio,
and only exists for players who exported is not the same as "a bad migration is now recoverable", and
a decision resting on the stronger sentence would be resting on something untrue.

**Make the restore door reachable after a failed migration** — build the container by hand with
`do`/`catch` and, on failure, boot a bare screen that offers *Restore from a copy* into a fresh
store. **This is the change that would actually justify lifting the freeze rather than replacing it**,
because it converts delete-reinstall into one tap and turns the trap into a recoverable state. It is
deliberately not decided here: it touches app startup, it wants its own ADR, and it should be
measured against how often the state it handles actually occurs (which, so far, is never). Logged in
`docs/backlog.md`.

**Automatic periodic export.** The real fix for fact 4, and the one that would make this whole ADR
uninteresting — a player who always has a recent archive is a player for whom a bad migration is an
inconvenience. Not decided here: it raises storage, iCloud and privacy questions that are each larger
than this decision. Also logged.

## Consequences

- **The freeze now has a written home**, which it never had. If it is later reinstated, it is
  reinstated by superseding this.
- **The first destructive change pays for the migration machinery**, and should expect to. D2 and D3
  are most of a day's work on top of whatever the change itself costs — which is the correct price
  and is the reason D1 asks whether the change is needed at all.
- **`analytics: archive_exported` and `archive_restored` (ADR 0188 S3) are the evidence this decision
  is missing.** Both were added in the same slice as this review. Until they report, "how many players
  hold an archive" is a guess, and D5's precondition is unmeasured. **If exports turn out to be rare,
  the honest response is to reinstate something like the freeze** — not to keep these criteria and
  hope.
- **Nothing about the app's current schema changes.** ADR 0188 S3 touches no `@Model` at all.
