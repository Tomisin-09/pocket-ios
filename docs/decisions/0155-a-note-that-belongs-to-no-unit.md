# ADR 0155 — a note that belongs to no unit

- **Status:** Proposed — to be refined before implementation (scheduled the week of 2026-08-10)
- **Date:** 2026-08-09
- **Amends:** ADR 0100 §1 (the read-only stance), narrowly
- **Extends:** ADR 0058 (polymorphic owner) · ADR 0143 (`ownerKind` is the discriminator) · ADR 0151 (the orphan state)

## Context

Every journal entry in this app is about *something*. ADR 0038 gave a note a loop, ADR 0058 gave it
an exercise, ADR 0143 gave it a routine sitting. Three owners, three write seams — and all three
seams are inside a run. There is no way to write a note that is not about a unit, because there is
no such note in the model.

That is a real gap, and it is the gap that swallows the most durable entries a practice journal
holds. "Strings are dead, restring before Thursday." "Wrist tightens when I practise after work —
stop practising after work." "Ten minutes tonight, that's all there was." "By September I want to
sit in on a blues jam without charts." None of these is about a drill. Several of them are worth
more, six months later, than any tempo any drill was ever run at.

What a player does with a thought like that today is attach it to whatever happens to be on screen.
That is not a neutral workaround — it **corrupts the unit it lands on**. Open that exercise's
`JournalSheet` in three months and it says "strings are dead," filed under a picking drill, stamped
with a command BPM of 96. The snapshot makes it worse rather than better: it lends the note a
context it never had, and the ADR 0038 promise that an entry "stays a truthful record of where
things stood" quietly becomes a lie about which *things*.

ADR 0100 §1 made the Journal space read-only on purpose — *"Reflection, not authoring — writing and
editing entries stays in the per-owner `JournalSheet`."* That was right, and it stays right, for
every entry that has an owner: the unit's own screen is always the better place to write about the
unit, because it is the only place the snapshot is honest. It is exactly wrong for an entry with no
owner. The rule makes the one surface that could host an ownerless note the one surface that cannot.

## Decision

### 1. An entry may belong to nothing, and it declares that rather than implying it

`JournalEntryOwnerKind` gains a fifth case, `.standalone`, backed by one additive column on
`JournalEntry`:

```swift
var isStandalone: Bool?   // additive optional, NO declaration default (CoreData 134110)

var ownerKind: JournalEntryOwnerKind {
    if exercise != nil { return .exercise }
    if loop != nil { return .loop }
    if routineUID != nil { return .session }
    if isStandalone == true { return .standalone }
    return .orphan
}
```

The stored flag is the whole point, and it is worth being clear about why it is not free. The
obvious implementation is no column at all: set no relationship and no `routineUID`, and the entry
is standalone by construction. That works, once. **Absence is already taken** — ADR 0151 spent it on
`.orphan`, the state of a note whose unit was deleted and whose relationship nullified. Shipping a
second meaning onto the same absent state is precisely the mistake ADR 0143 was written to correct:
owner identity derived from what happens *not* to be set, which is only ever right until the next
owner arrives.

`nil` on every existing row is correct — every entry written before this is owned or orphaned. The
ordering above preserves ADR 0143's rule that the relationships win, so a standalone note can never
be mistaken for an owned one.

### 2. It is not an orphan, even though it renders exactly like one

Trace a note with no owner through the feed as it stands today and every stage already does the
right thing:

- `JournalTimeline.ownerLabel` returns `nil` (no relationship, no `ownerLabelAtEntry`) → no caption,
- `JournalOwnerRoute.route` returns `nil` → nothing to tap,
- `JournalEntryRow.snapshot` returns `EmptyView` → no tempo or mastery line.

Kind chip, text, timestamp. That is a standalone note, and it means this decision costs the display
layer nothing. **Identical rendering is not identical meaning**, and the distinction is being drawn
now for a reason that expires: an orphan is a note that *lost* its subject, a standalone note never
had one, and the moment either wants its own treatment — a "this drill was deleted" line on an
orphan, a *Journal only* filter, a differently-worded delete toast — there will be entries of both
kinds in the store and no fact on disk to tell them apart. There is no backfill for a distinction
that was never recorded.

### 3. The Journal space writes standalone notes, and only standalone notes

`JournalTabView` gains a compose action that presents `QuickJournalSheet(owner: .standalone)`.
`JournalOwner` gains a matching `case standalone`, which slots in beside `.session` — an owner that
holds no relationship, has no journal to read (`entries` is `[]`), and exists only at the write seam.
`JournalWriter.add` gains a fourth case that inserts the entry and sets the flag.

ADR 0100 §1 is amended, not overturned. **Owned entries are still written and edited on their
owner's screen.** What the compose button cannot do is offer an owner picker. A picker would make
the Journal space a second authoring route for entries that already have a better one — worse, one
where the snapshot would have to be taken at a moment the player is not practising the unit, so
`masteryAtEntry` and `commandBpmAtEntry` would record where the drill stands *now* rather than where
it stood when the thing being described happened. One door, one kind of note.

### 4. A standalone note cannot be edited after writing — accepted for this slice

Editing lives in `JournalSheet`, which is per-owner and therefore unreachable for an entry with no
owner. A standalone note can be written and, via the feed's existing press-and-hold, deleted with an
Undo window; it cannot be amended.

Accepted deliberately rather than overlooked. These are quick captures, delete-and-rewrite is cheap
for a sentence, and the alternative — a fourth journal-editing surface — is a disproportionate
amount of new UI to add in the same breath as the model change. If it turns out to matter, the
honest fix is a tap on a standalone row opening the *existing* edit form, not a new sheet, and that
is a follow-up rather than a redesign.

### 5. There is nothing to snapshot, and the composer says so in one sentence

`QuickJournalSheet` currently assembles its destination line from two owner-supplied fragments:
`"Saves to \(owner.displayName)'s Journal, \(owner.snapshotBlurb)."` Neither fragment has an honest
value for an owner that is not a thing and records nothing, and patching them yields "Saves to your
Journal's Journal."

`snapshotBlurb` is therefore replaced by `destinationLine`, a **whole sentence** per owner (it has
exactly one caller, so this costs nothing):

| Owner | Line |
|---|---|
| loop / exercise | "Saves to *Name*'s Journal, snapshotting where the unit stands right now." |
| session | "Saves to *Routine*'s Journal, snapshotting what you practised in this session." |
| standalone | "Saves straight to your Journal — not attached to any loop or exercise." |

`JournalNoteComposer`'s footer uses `displayName` the same way but is only ever hosted on a run
screen, so it never sees `.standalone` and is untouched.

### 6. The tag vocabulary narrows on this surface

`EntryKindChipRow` renders all of `EntryKind.pickerOrder` with no way to narrow it. Three of those
seven tags assert that the note was written during something: 👂 **Ear** (ear-training on a loop),
🎸 **Improv** (jamming over a backing loop), 🎬 **Session** (a routine sitting just finished). Offered
on a surface with no owner, they let a player file a session note about no session.

The row gains a `kinds:` parameter defaulting to `pickerOrder`; the standalone composer passes
`[.goal, .breakthrough, .struggle, .note]`.

Stated plainly so the next reader can weigh it: `EntryKind` on a journal entry is **never** filtered,
queried or branched on anywhere in the app — it drives the chip's emoji, label and colour and
nothing else. A wrong tag is a misleading label, not broken behaviour. This is a three-line change
bought for honesty, not for correctness, and the four tags that survive are the four ADR 0100's own
composer led with.

### 7. Free, like the rest of the Journal

ADR 0144 put the Journal outside the paywall permanently. No gate, no `AccessPolicy` check, no
`presentPaywall` path. A player whose subscription has lapsed can still write down that their strings
are dead.

## Consequences

- The feed, the routing and the row need **no changes** — §2. The whole of this lands in the model,
  the writer, one composer and one toolbar.
- Adding the enum case breaks four exhaustive switches, which is the point: the compiler names every
  site. `JournalTimeline.ownerLabel`, `JournalEntryRow.snapshot` and `JournalTabView+Deletion.name`
  take the same branch as `.orphan`; `JournalSheet`'s snapshot section never sees one.
- Two empty-state strings in `JournalTabView` become false and are rewritten:
  - *all* — "Notes you write and takes you record gather here — from your loops and exercises, or
    straight from this screen."
  - *notes* — "Jot a goal, a breakthrough or a struggle — after a run, or any time with ＋."
    This is the line that teaches the button exists, so it is doing more work than it looks.
- The additive optional column is safe against the post-1.0 schema freeze; only retypes were ever
  now-or-never, and this is not one.
- **Open — the toolbar.** `JournalTabView`'s trailing edge already carries Progress and Sort, and a
  ＋ makes three. ADR 0126's grammar is `ellipsis.circle` then `+`, which implies folding Progress
  and Sort into a menu so the ＋ takes its proper slot — at the cost of demoting Progress from one
  tap to two. Decided at build time, not here.
- Tests to extend: `JournalOwnershipTests` (the `ownerKind` table — a standalone entry must **not**
  read as `.orphan`, and an orphaned entry must not read as standalone), `JournalWriterTests` (the
  flag is set, no relationship is), `JournalTimelineTests` (no caption, and the note still merges,
  sorts and day-groups).

## Alternatives considered

**Set no flag and let absence mean standalone.** Free, and it renders correctly today. Rejected in
§1: it spends a state ADR 0151 already spent, and the collision is unrecoverable once entries of
both kinds exist.

**A synthetic "General" owner — a real `Exercise` or a new model to hang these off.** Gives editing
via the existing per-owner sheet for free, which is the one thing §4 gives up. Rejected because a
fake unit does not stay in its lane: it surfaces in the exercise library, in planner candidates, in
routine pickers and in search, and every one of those becomes a place needing a special case to hide
it. A column is cheaper than a ghost.

**Reuse `.session` with a `nil` routineUID.** No schema change at all. Rejected twice over — the
`ownerKind` ladder would read it as `.orphan` anyway, and calling an ownerless thought a "session"
is the same category error as filing it under a drill, just less visible.

**Let the compose button pick an owner.** The natural-looking generalisation, and the one that
undoes the decision: it re-creates the corrupt-the-drill problem from the Context with a dishonest
snapshot attached, from a surface that cannot see the unit. Rejected in §3.

**Put the ＋ on Home instead, leaving the Journal space strictly read-only.** Preserves ADR 0100 §1
untouched, which has some appeal. Rejected: the note's home is the feed it lands in, and a write
button on a screen that does not show you the result is a worse teacher than one that does. It also
buys the purity by making the feature harder to find.

**Free-text tags rather than the closed `EntryKind` set.** Standalone notes are the loosest kind, so
the pressure to loosen the vocabulary lands here first. ADR 0038 chose a closed set specifically to
avoid a later text→enum migration; nothing about an ownerless note changes that reasoning.
