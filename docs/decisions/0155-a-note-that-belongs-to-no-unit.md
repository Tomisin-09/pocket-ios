# ADR 0155 — a note that belongs to no unit

- **Status:** **Accepted — built 2026-08-12** (branch `pocket-252-standalone-journal-note`). Refined 2026-08-11 (§3a, §8, and a recommendation on the open toolbar question); the open toolbar question is now **decided** — see the build note after *Consequences*.
- **Date:** 2026-08-09, refined 2026-08-11
- **Amends:** ADR 0100 §1 (the read-only stance), narrowly
- **Extends:** ADR 0058 (polymorphic owner) · ADR 0143 (`ownerKind` is the discriminator) · ADR 0151 (the orphan state)
- **Second consumer:** the Metronome tool — see §8, added on refinement
- **Partly superseded:** §8's two refusals — *"No `.metronome` owner kind"* and *"No snapshot of the
  tempo"* — were reversed by **ADR 0160** on 2026-08-12. Everything else here stands, including §1's
  stored flag, §3a's owner-picker prohibition, and §8's decision to put the door on the metronome at
  all. The reversal is conditional and does not weaken this ADR: what §8 objected to was a *fragment*
  of a unit's context (a bare BPM), and 0160 records a metronome sitting's context in **full** on an
  entry that declares what it is, so there is nowhere wrong left to attach it.

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

### 3a. What §3 constrains, and what it does not *(added on refinement, 2026-08-11)*

The heading above is a rule about **what the Journal space writes** — that surface writes standalone
notes and nothing else. It is not a rule that the Journal space is the only surface allowed to write
a standalone note. Read the strong way it would forbid §8 below, which is not what it was written to
do.

The prohibition that does generalise, and that must survive every future door, is the **owner
picker**: no surface may offer to file a note against a unit the player is not currently in. That is
what protects the snapshot's honesty, and it is the whole of §3's argument.

So the test for any new write seam is not "is it the Journal tab" but: *does this surface have a unit
whose snapshot would be honest?* If it does, the note belongs to that unit and is written the
existing way. If it does not, a standalone note is correct and the seam is welcome.

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

### 8. The Metronome is the second door *(added on refinement, 2026-08-11)*

From a device-testing note: *"Let's add a journal to the metronome… could give users a chance to
actually try out the journaling feature."*

A metronome sitting is not an exercise, a loop, or a routine. It is the clearest case in the app of
§3a's test — a surface with no unit whose snapshot could be honest — so what gets written there is a
standalone note, and this ADR already provides the whole mechanism.

`MetronomeView` gains the existing `QuickJournalButton` in its `.topBarTrailing` group, ahead of the
meter button, presenting `QuickJournalSheet(owner: .standalone)`. Both the button and the sheet
already exist and are already used by `ExerciseRunView` and `LoopRunView`; nothing new is written.
That the door costs one toolbar item and no new types is the strongest evidence that §1's model
change is the right shape.

Two things this deliberately does **not** do:

**No `.metronome` owner kind.** A metronome owner would need a snapshot — BPM? the automator's
ramp settings? — and a journal to read back, and the note's stated purpose is discoverability, not a
record of metronome sittings. A fifth owner is a large price for a door.

> **Reversed by ADR 0160 (2026-08-12).** The question this refusal asks — *what would a metronome
> owner even snapshot?* — turned out to have a complete answer: tempo, meter, subdivision and
> withdrawal, all of them to hand at the write seam. A sixth owner kind was the right price once the
> snapshot was a full description of a real thing rather than a fragment. It still holds no journal
> to read back, exactly as this section anticipated.



**No snapshot of the tempo, even though one is available.**
`StandaloneMetronomeEngine.elapsed` exists (`:100`), accumulates across pause/resume, and is
rendered nowhere in the app; the live BPM is equally to hand. Both were considered as a way to give
the note *some* context. Rejected for the same reason §5 gives the composer its own sentence: a
standalone note records nothing, and half a snapshot — a BPM with no unit attached to it — is the
lending of false context this ADR's Context section is about. A player who wants the tempo in the
note can type it, and it will mean what they meant by it.

> **Reversed by ADR 0160 (2026-08-12).** The premise — that a standalone note records nothing — is
> what changed, not the reasoning. A tempo *alongside its meter, subdivision and withdrawal*, on an
> entry classified as a metronome note, is not half a snapshot; it is a whole one of something that
> is not a unit. The device pass also supplied the case this section did not weigh: a player who
> takes this door and writes "finally clean here" gets a note that does not say what tempo, which is
> the outcome most likely to teach them the journal isn't worth using.

**Discoverability is the point, and it is worth being honest about the size of the claim.** A pencil
in the metronome's toolbar teaches the journal exists to players who open the metronome. It does not
solve journal discovery generally, and it should not be counted as having done so.

## Consequences

- The feed, the routing and the row need **no changes** — §2. The whole of this lands in the model,
  the writer, one composer and **two** toolbars (the Journal's, and the Metronome's per §8).
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

  *Recommendation, added on refinement 2026-08-11 — still not a decision.* **Follow ADR 0126.** Three
  bare trailing items is the shape 0126 was written to stop, and the Journal is not special enough to
  be the exception. Two supporting facts: Sort is a two-state flip (newest/oldest) that is not even
  persisted, so it is the weakest claim on a top-level slot of the three; and `LibraryOptionsMenu`
  already establishes the pattern of an `ellipsis.circle` holding actions, sort and filters together
  across three libraries, so folding is a move toward the app's existing grammar rather than away
  from it. The cost is real and should be stated when the build lands: Progress goes from one tap to
  two. If that proves wrong in use, the honest fix is promoting Progress back out and folding
  something else — not three bare items.

  Note that §8's metronome door needs none of this. Its toolbar has one trailing item today, so the
  pencil simply joins it.
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

## Build note (2026-08-12) — what was decided at build time

**The open toolbar question is resolved as recommended: ADR 0126 wins.** `JournalTabView`'s trailing
edge folds Progress and Sort into an `ellipsis.circle` menu, and the ＋ takes the slot 0126's grammar
gives it. Progress is demoted from one tap to two — the cost the question named, paid knowingly.

One mechanical detail the recommendation didn't anticipate: **a `NavigationLink` inside a `Menu` does
not push.** Progress therefore became a `Button` setting a flag, with the push moved out to a
`.navigationDestination(isPresented:)` beside the existing owner-route destination. It behaves
identically; it is simply not the one-line move into a menu it looks like.

**One deviation from §5.** That section says `JournalNoteComposer` "never sees `.standalone` and is
untouched", which is true — but `JournalOwner.displayName` is an exhaustive `switch`, so the case
must still be written. It returns the string `"your Journal"` rather than trapping. A
`preconditionFailure` was considered and rejected: this repo's standing trade is that a sentence
reading oddly beats a crash (the same reasoning `AboutSection.supportURL` gives for being optional),
and if a future surface ever wires one through by mistake, a visibly silly "your Journal's Journal"
is a perfectly good bug signal that costs nobody their session.

**§2's "no changes needed" held, with one addition made on purpose.**
`JournalTimeline.ownerLabel` needed a `.standalone` branch returning `nil` — which is what it would
have returned anyway by falling through, since `forStandalone` writes no `ownerLabelAtEntry`. It is
written explicitly regardless: resting on that would leave a caption one careless assignment away,
and a standalone note wearing a unit's name is the exact corruption this ADR exists to prevent.

**Six exhaustive switches broke**, two more than the four *Consequences* predicted — `JournalSheet`
accounts for three of them (its empty state, its capture preview, and the entry-detail snapshot
section) and `RoutinePlayerView+Done` for the fourth beyond the forecast. All six either take the
orphan's branch or document why they are unreachable. This is the mechanism working as intended: the
compiler named every site.

**Not built, per §4:** a standalone note still cannot be edited after writing. Delete-and-rewrite
remains the answer, with the feed's existing hold-to-delete and its Undo window.
