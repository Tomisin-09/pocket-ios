# 0039 — Glanceable loop row + unset states for the judgment fields

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

The loops panel row shows only a loop's **name** and **time range** (ADR 0013
moved speed/repeats into the automator). The whole progress story — how cleanly
you own the loop (`mastery`) and the fastest tempo you command it at
(`commandTempo`) — is buried behind a hold-to-edit sheet. A loops list is the
closest thing the app has to a practice dashboard, and today it tells you
nothing about practice state at a glance.

Surfacing those fields on the row exposed a latent data-quality bug. The three
"judgment" fields added in ADR 0036 carry **declaration defaults that read as
real ratings**:

- `commandTempo: Double = 1.0` — `1.0` means *"you command this at full
  tempo."* For an untouched loop that's an outright lie: the row would badge a
  brand-new loop **100%**.
- `mastery: Int = 0` — in a 0–5 scale, `0` reads as *"can't play it at all,"*
  which is a claim, not the absence of one.
- `focus: Int = 1` — `1` (Backburner) is at least a *truthful* resting default
  ("not actively working it"), but for the planner (V2) "never triaged" and
  "explicitly parked" are different inputs.

A default that masquerades as a rating is worse than no rating: it pollutes the
glanceable row and the `MasteryRollup` song summary with confident-looking
fiction. The fix is to give each field an explicit **unset** state.

This ADR pairs the glanceable row (the feature) with the unset states (what the
feature needs to be truthful) — they ship together because the row can't be
honest without them. (Decided in the 2026-06-24 loop-UX sense-check; see
`docs/backlog.md`, items #2 + #4.)

## Decision

### Unset states via Optional

`Loop.mastery`, `Loop.focus`, and `Loop.commandTempo` become **Optional**
(`Int?`, `Int?`, `Double?`). `nil` = *never set* (the honest default for a new
or migrated loop). The journal's context snapshot follows suit:
`JournalEntry.masteryAtEntry` and `commandTempoAtEntry` become Optional too, so
an entry written against an unrated loop records "unrated" rather than a
defaulted `0` / `1.0`.

**Migration is safe and free.** Optional attributes are *exempt* from the
SwiftData lightweight-migration "mandatory attribute" rule (CoreData 134110)
that forces declaration defaults on non-optional fields — existing rows migrate
to `nil` with no store wipe. So every loop saved before this ADR becomes
"never touched," which is exactly the truth. (Existing journal entries keep
their already-stored `0` / `1.0`; they were genuinely written under the old
defaulted semantics, so freezing them is correct — the snapshot is immutable by
ADR 0038.)

### Glanceable loop row

The loop row's second line gains the practice state, **shown only when set**:

- **Mastery** → up to five small dots (the shared `MasteryDots`). Omitted when
  `nil`.
- **Command tempo** → a compact percent badge (e.g. `85%`) — *the achievement*,
  the headline of the row per the sense-check. Omitted when `nil`.

Absence is the unrated signal: an untouched loop shows just name + range (the
status quo), so **nothing fake ever renders**. Last-practiced `speed` is *not*
shown — it's a transient practice setting, not an achievement (it becomes
last-practiced memory in a later ADR; backlog #3).

### Setting / clearing in the edit sheet

A slider and a segmented control can't natively express `nil`, so each control
gains an explicit unset path:

- **Mastery dots** — tapping the lowest filled dot again walks the value down
  to `nil`; an "Unrated" hint shows when unset. (Extends the existing
  walk-down-to-clear gesture.)
- **Command tempo** — when unset, the row reads "Not measured" with a **Set**
  button that seeds the slider from the loop's current practice `speed` (a
  tempo you're demonstrably at), clamped to range; when set, the slider shows
  with a **Clear** control back to `nil`. The slider never silently implies a
  value.
- **Focus** — converted from a 3-segment control to a **menu picker** ("Not
  set / Backburner / Active / Sharpening"). A 4th "unset" segment is too
  cramped on a phone, and a menu handles `nil` cleanly while matching the
  `Type` menu directly above it.

### Rollup skips unrated loops

`MasteryRollup.rollup` takes `[Int?]` and filters `nil` before averaging. A
song's derived `mastery` is now the average of its **rated** loops, or `nil`
when none are rated — so one unrated loop no longer drags the song summary down
with a phantom `0`. This is strictly more correct than the old behaviour, which
averaged the `0` defaults.

### Percent formatting centralised

The repeated `Int((tempo * 100).rounded())%` (five sites: edit sheet, journal
composer preview, journal row, journal editor, glanceable row) moves to a pure,
unit-tested `LoopProgressFormat` helper that also owns the `nil → "—"`
fallback, per the AGENTS.md rule that tempo math stays pure and tested.

## Consequences

- The loops list reads as an at-a-glance practice dashboard, and every value on
  it is real — there are no defaulted ratings to mistrust.
- Migration is a no-op store-wise; existing loops correctly become "never
  touched," and the song mastery rollup gets *more* accurate for free.
- Optional fields ripple through five read sites (rollup, edit sheet, two
  journal views, the new row) — each handled explicitly, with `MasteryReadout`
  / `LoopProgressFormat` giving consistent `nil` presentation.
- The planner (V2) gains a genuine "never triaged" signal on `focus` instead of
  an ambiguous `1`.
- Command tempo and mastery now require a deliberate gesture to set — the right
  friction, since a rating you didn't make shouldn't exist.

## Alternatives considered

- **Keep the declaration defaults, special-case the row** (e.g. treat `1.0` /
  `0` as "unset" on display) — rejected: sentinel values are the bug. `1.0` is a
  *legitimate* command tempo (you really can own a loop at full speed); a loop
  rated 0 is different from one never rated. Only a true `nil` distinguishes
  them without ambiguity.
- **Leave `focus` non-optional** (its `1` default is at least truthful) —
  rejected for model consistency and planner correctness: making all three
  judgment fields nullable keeps the "unset" concept uniform, and "never
  triaged" is a real planner input. The cost is one control change (segmented →
  menu), which also improves consistency with the `Type` picker.
- **Show "—" on the row for unset fields** instead of omitting them — rejected:
  a dash is noise on a compact row. Absence already reads as "not yet rated";
  the dash belongs only where a *labelled* field needs a value (edit sheet,
  journal snapshot), which is where it's used.
