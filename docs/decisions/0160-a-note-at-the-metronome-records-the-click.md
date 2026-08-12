# ADR 0160 — a note at the metronome records the click

- **Status:** **Accepted — built and device-verified 2026-08-12** (branch
  `pocket-254-a-note-at-the-metronome`, iPhone 16 Pro). The pass that mattered is the **migration**:
  the six additive columns opened against a store holding existing journal entries, which is the one
  thing in-memory tests structurally cannot prove — a custom-type attribute crashes on device only.
  The write seam, the feed caption and §5's mid-ramp case were checked by hand and all hold.
- **Date:** 2026-08-12
- **Supersedes:** ADR 0155 §8's two refusals — *"No `.metronome` owner kind"* and *"No snapshot of the
  tempo"*. Everything else in ADR 0155 stands, including §1's flag, §3a's owner-picker prohibition,
  and §8's decision to put the door on the metronome at all.
- **Extends:** ADR 0058 (polymorphic owner) · ADR 0143 (`ownerKind` is **the** discriminator) ·
  ADR 0038 (the snapshot is immutable and taken at write time)
- **Relates to:** ADR 0132 (click withdrawal — the metronome is its only host) · ADR 0043 (the
  standalone metronome, its meters and subdivisions)

## Context

From the device pass, in the player's words: when a journal entry is written on the metronome, it
should record the metronome — **time signature, subdivision, click withdrawal** — and be classified
as a metronome entry rather than a bare standalone note.

ADR 0155 §8 declined exactly this, two days ago, and the refusal is still sitting in
`MetronomeView.swift` as a comment:

> No `.metronome` owner kind, and no snapshot of the live BPM even though one is to hand … a
> standalone note records nothing, and half a snapshot — a tempo with no unit attached to it — is
> exactly the false context this decision exists to stop.

So this is a reversal of a stated decision, not the filling of a gap, and it needs to answer the
old reasoning rather than quietly overwrite it.

### What 0155 was actually protecting against

Read §8 next to the Context that ADR 0155 opens with and the objection is precise. That ADR exists
because a note attached to the wrong unit **corrupts the unit it lands on**: open the exercise's
journal three months later and "strings are dead" is filed under a picking drill, stamped with a
command BPM of 96. The lie is not the note. The lie is the *fragment of context* wrapped around it.

§8 then applied that rule to a BPM read off the metronome, and it was right to: a bare tempo is a
fragment of a **unit's** context with no unit behind it. It reads as though it were about a drill,
because in this app a command BPM always has been. Storing one on an ownerless note invites exactly
the false attachment the ADR was written to prevent.

### Why the reversal is nonetheless right

A metronome sitting is not a fragment. It has a **complete context of its own** — tempo, meter,
subdivision, withdrawal — and every one of those values is to hand at the write seam. Recording all
of them is a *full* snapshot of a real thing, which is precisely what `JournalEntry` already promises
to do ("snapshots its owner's context at the moment of writing") and what every other owner kind
already does.

The player's instinct to **classify** the note is what answers §8. Once the entry says *this was
written at the metronome*, "96 BPM · 4/4 · ♫" is no longer a unit-less tempo waiting to be
misattributed. It is a description of a click, on a note that says it is about a click. The reader
has nowhere wrong to attach it.

The 0155 test in §3a survives intact and is worth restating, because it is what this decision passes:
*does this surface have a unit whose snapshot would be honest?* The metronome has no unit — so no
unit-owned entry, and no owner picker, ever. What it has is **itself**, and that turns out to be
worth recording.

There is also a plainer reason. ADR 0155 §8 put the pencil on the metronome for **discoverability** —
so a player who never opens a run screen still meets the journal. A player who takes that door and
writes "finally clean at this tempo" gets an entry that does not say what tempo. That is the one
outcome most likely to teach them the journal is not worth using.

## Decision

### 1. A fifth owner kind, `.metronome`, with a positive flag of its own

```swift
var isMetronome: Bool?   // additive optional, NO declaration default (CoreData 134110)

var ownerKind: JournalEntryOwnerKind {
    if exercise != nil { return .exercise }
    if loop != nil { return .loop }
    if routineUID != nil { return .session }
    if isMetronome == true { return .metronome }
    if isStandalone == true { return .standalone }
    return .orphan
}
```

A stored flag, for the same reason ADR 0155 §1 gave `isStandalone` one and at greater cost here,
because there is now an obvious free alternative: this entry is the only kind that carries metronome
columns, so `metronomeBeatsAtEntry != nil` would classify it for nothing.

Rejected, and the distinction is worth being exact about. That test is not the *absence* mistake
§1 warns of — a non-nil column is a positive fact on the row — it is a worse relative of it: it makes
the entry's **kind** a function of its **payload**. A future column that is optional-within-the-kind,
a decode that fails, a bug that writes the flag columns in the wrong order, and the entry silently
stops being a metronome note and starts rendering as an orphan. The kind is the one fact the whole
render path branches on (ADR 0143); it gets its own byte.

**A metronome entry sets `isMetronome` and leaves `isStandalone` nil.** The two flags partition
rather than nest. A metronome note is *ownerless* in the sense that it holds no relationship, but it
is not a `.standalone` note — it has a context and that context renders — and two flags both saying
true would be two rows of truth about one entry, with `ownerKind`'s ordering silently deciding which
one counts. Nothing outside `ownerKind` may read either flag; that is the ADR 0143 rule, unchanged.

### 2. What it snapshots, and in what form

Five additive optional columns, **raw values only**:

| Column | Source | Type |
|---|---|---|
| `metronomeBpmAtEntry` | `engine.bpm` | `Int?` |
| `metronomeBeatsAtEntry` | `engine.timeSignature.beats` | `Int?` |
| `metronomeNoteValueAtEntry` | `engine.timeSignature.noteValue` | `Int?` |
| `metronomeSubdivisionRaw` | `engine.subdivision.rawValue` | `String?` |
| `metronomeWithdrawalRaw` | `engine.activeWithdrawal.rawValue` | `String?` |

**No `TimeSignature`, `Subdivision` or `ClickWithdrawal` ever reaches the `@Model`.** A custom type
stored as a SwiftData attribute crashes on migration **on device only** — in-memory tests miss it
completely, which is how this project met it the first time (`docs/swiftdata-gotchas.md`;
`Loop.loopTypeRaw` is the standing precedent). `Subdivision` and `ClickWithdrawal` are already
`String`-backed; `TimeSignature` is a struct, and its raw form is the pair of `Int`s it is built from
— `TimeSignature.forStored(beats:noteValue:accentBeats:)` already exists to rebuild one, so the
accent pattern is derived on read rather than stored. Accents are a property of the meter, not of the
sitting: a player cannot edit them, so storing them would record a fact that can only ever be
recomputed.

One trap the raw form carries: `Subdivision.none` has the raw value `""`, so **empty string is a
value, not a missing one**. `nil` means "not recorded" (every entry written before this) and `""`
means "no subdivision was running". The read path distinguishes them; a test pins it.

These five are typed columns rather than one JSON blob in the `practisedUnitsRaw` style. That
precedent is for a *list of things*, where a column count cannot be fixed. Here the shape is closed
and small, the two `Int`s stay predicate-visible (a "notes I wrote above 120" query needs no decode),
and a JSON decode failure would take the whole snapshot down at once.

### 3. The tempo comes too — this is the part of §8 being reversed most directly

The player listed three settings and not the BPM. Record it anyway.

Tempo is the metronome's headline value and the reason nearly every note gets written there; a
snapshot that carefully preserves the subdivision while dropping the number the sitting was *about*
would be a strange kind of thoroughness. §8's objection was never to the tempo as such — it was to a
tempo standing alone. Inside a classified metronome snapshot it no longer does, which is §1 and §2
doing their job.

The automator can move the BPM *during* a sitting, so "the tempo" is genuinely a moving target. §5
picks which moment is recorded.

### 4. The withdrawal recorded is the one in force, not the one configured

`ClickWithdrawal` has two readings on this screen: the stored tier (`AppSettings.clickWithdrawal`)
and `engine.activeWithdrawal`, which applies ADR 0132 §4's three exclusions — the host must offer
withdrawal, no ramp may be running, no strum schedule may be armed.

The snapshot takes **`activeWithdrawal`**, because the journal records what happened, not what was
configured. A player ramping with Deep selected heard a full click; an entry claiming "deep
withdrawal" would be false about the only thing the reader can no longer check. This also keeps the
column honest on every other host by construction: withdrawal is a metronome-only feature
(`allowsClickWithdrawal`, ADR 0132 §4), so no other owner kind has the field at all.

### 5. The snapshot is taken when the composer opens

Not when Save is tapped. The other owners cannot tell the difference — a loop's mastery does not
change while a sheet is up — but a metronome's tempo can, because the automator keeps ramping behind
the sheet (ADR 0142's rule that the composer touches no transport is what makes this possible, and it
stays).

The moment being described is the moment the player reached for the pencil. Recording where the ramp
had climbed to by the time they finished typing would attribute the note to a tempo they were not
reacting to, and would make the same note mean different things depending on how fast they type.

Mechanically this means the context is **pinned in `@State` at the tap** and presented with
`.sheet(item:)`, not rebuilt inside the sheet's content closure — that closure re-runs whenever
`MetronomeView`'s body does, and its body reads `engine.bpm`. A snapshot rebuilt there would be
whatever the last re-render saw, which is neither of the two defensible moments.

### 6. The feed says "Metronome", and the caption goes nowhere

- `JournalTimeline.ownerLabel` returns the constant **"Metronome"** for a `.metronome` entry. It is
  not snapshotted into `ownerLabelAtEntry` like a unit's caption is (ADR 0151), because it cannot be
  renamed and cannot be deleted — there is exactly one metronome and it is a screen, not a row.
- `JournalOwnerRoute.route` returns **`nil`**, so the caption is plain text. This is the ADR 0142
  honesty rule and not an oversight: the metronome is reachable from the Toolkit, but opening it
  would not restore the meter, subdivision, withdrawal or tempo the note was written at, so the tap
  would promise a return to a sitting it cannot deliver.
- `JournalEntryRow` gains a `.metronome` branch rendering the settings line, in the same mono caption
  style an exercise entry's BPM uses. It reads **`96 BPM · 4/4 · ♫ · gentle withdrawal`**, dropping
  the subdivision when none was running and the withdrawal when it was off — a caption that says
  "off" every time teaches nothing, and the great majority of entries will have both defaults.

A consequence worth having: `searchHaystack` already folds in `ownerLabel`, so **"metronome" becomes
a search term** in the Journal space the day this ships, with no extra wiring.

### 7. The narrowed tag vocabulary applies here too

`QuickJournalSheet` offers `[.goal, .breakthrough, .struggle, .note]` for a metronome owner, the same
four ADR 0155 §6 gave the standalone one. The three excluded tags — 👂 Ear, 🎸 Improv, 🎬 Session —
each assert the note was written *during* something with a unit behind it, and a click is not that.
The reasoning transfers unchanged, so the code path is shared rather than duplicated.

### 8. The Journal space still writes standalone notes

`JournalTabView`'s compose button is untouched: `.standalone`, no context, no owner picker. ADR 0155
§3 is not weakened by this decision — a new *surface* with a context of its own got a kind of its
own, which is exactly the shape §3a said a new write seam should take. What no surface may do is
offer to file a note against a unit the player is not currently in.

### 9. There is no backfill, and there cannot be

Standalone notes already written at the metronome are indistinguishable from ones written in the
Journal space; the distinction was never recorded. They stay `.standalone` and render as they do
today. This is the same conclusion ADR 0155 §2 reached about its own case, and the same reason it
gave for drawing the distinction at all rather than later: there is no backfill for a fact that was
never written down.

## Consequences

- **Five new optional columns and one new flag on `JournalEntry`, all additive with no declaration
  defaults.** Lightweight migration stays clean (CoreData 134110), and `nil` on every existing row is
  correct — no entry written before this was classified.
- **The compiler finds the render sites.** A fifth `JournalEntryOwnerKind` case breaks every
  exhaustive switch over it (`JournalEntryRow`, `JournalTimeline`, `JournalOwnerRoute`,
  `JournalSheet`, `RoutinePlayerView+Done`), which is precisely why ADR 0143 made the kind an enum.
- **`MetronomeJournalContext` is a pure value type** in `Core/Models` — Foundation only, no SwiftUI,
  no AVFoundation — holding the four typed values, converting to and from the raw columns, and
  formatting the settings line. The whole of this decision's logic is therefore unit-testable without
  a `ModelContainer` or an audio engine, which is the AGENTS.md rule for exactly this kind of code.
- **`QuickJournalButton` gains an `action:` initialiser** beside its `isPresented:` one, so the
  metronome can pin its snapshot at the tap (§5) without a second button type. The three existing
  call sites are unchanged.
- **A metronome note still cannot be edited after writing**, inheriting ADR 0155 §4 — there is no
  `JournalSheet` for an ownerless entry. Delete-and-rewrite via the feed's press-and-hold, as before.
- **Free**, like the rest of the Journal (ADR 0144). No gate, no `AccessPolicy` check.
- **ADR 0155 §8's comment in `MetronomeView.swift` is replaced, not deleted** — it points here, so the
  next reader finds the reversal rather than concluding the refusal was never made.
- **The Toolkit's metronome is now a journalling surface with a record**, which raises a question this
  ADR does not answer: whether the Journal space should be able to filter to metronome notes. Left
  unbuilt — one owner kind is not a filter, and ADR 0159's rule (OR within a facet) is the shape it
  would take if a second ownerless kind ever arrives.

## Alternatives considered

**Keep 0155 §8 and let the player type the tempo.** The status quo, and its argument — "then it means
what they meant by it" — is not wrong. Rejected because it is a workaround the player has to know to
perform, on the one screen where all four values are already in memory, and because the note that
most needs the tempo is the one written in a hurry by a player who will not type it.

**Snapshot the BPM only, without classifying the entry.** The smallest possible change, and exactly
what ADR 0155 §8 refused. Still refused, and by the same argument: an unclassified tempo on an
ownerless note is the false-context problem, and the classification is what dissolves it. This
alternative is what makes the reversal *conditional* rather than a change of mind.

**Reuse `commandBpmAtEntry` for the metronome's tempo.** One fewer column, and the value is an
absolute BPM in both cases. Rejected for the reason ADR 0058 created that column in the first place:
it is documented as an **exercise's measured command**, and a metronome's free-play tempo is not a
command — nothing was promoted, nothing was measured. Sharing the column would put two meanings in
one field and make `JournalSheet.bpmLabel`'s rhythm pairing (ADR 0121) wrong for half its rows.

**One JSON column instead of five typed ones.** Follows `practisedUnitsRaw`. Rejected in §2: closed
shape, predicate visibility, and a decode failure that would take the whole snapshot at once.

**Make the caption open the metronome.** Tempting, since the screen exists and is one tap from the
Toolkit. Rejected in §6: it would return the player to a metronome in whatever state they left it,
not the one the note describes, which is a link that lies about its destination — the exact thing
ADR 0142 made routes optional to avoid. If restoring a sitting from a note is ever wanted, it is a
*Restore these settings* action on the row, not a caption tap.

**Snapshot at Save rather than at open.** Defensible — it is what every other owner effectively does,
since their context cannot move. Rejected in §5: the ramp makes the two moments genuinely different
here, and only one of them is the moment the player was reacting to.
