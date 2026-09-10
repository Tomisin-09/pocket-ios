# ADR 0209 — an exercise you can hand over

- **Status:** Accepted — both slices built (2026-09-09, `pocket-310-share-an-exercise`).
- **Date:** 2026-09-09 (`pocket-310-share-an-exercise`)
- **Amends:** ADR 0188 — the `.redmoonpractice` file gains its second payload kind (D1), the one
  inbound door now branches on it (D4), and **0188's gate-before-read ordering is reversed** (D5).
  0188's trust asymmetry (D1), its version gate (D2), the file type and its `Info.plist` declaration
  (D3), what a drill loses when it crosses (D5) and the preview-before-landing rule (D9) are all
  untouched, and the routine door behaves exactly as it did.
- **Amended by:** ADR 0210 — D2's subtraction list gains one entry. A drill handed over on its own
  now also loses its **folders**: those paths are positions in the *sender's* tree, and reproducing
  them on a stranger's phone would hand over a filing cabinet along with the drill. The folders'
  **leaf names are added to `tags`** instead — added, not substituted, so a drill with tags and no
  folders shares exactly what it did before. Everything else here stands: the same
  `shareable(_ exercise:)` still answers the question for both doors, and D4's generalised
  `PracticeReceiveHost` is what 0210's S3 will receive a whole folder through.
- **Relates to:** ADR 0077 (the read-only detail sheet this sends from), ADR 0112 / 0144 (the
  authoring gate the receiving side asks), ADR 0070 (never grading — the reason a drill's numbers do
  not cross), ADR 0148 (Red Moon owns its song copies, so no audio and no song links travel),
  ADR 0126 (the toolbar grammar that puts the receive row in the options menu), ADR 0120 (the event
  D7 adds), ADR 0165 (the manual quotes the app)
- **Schema:** none. No model, no new stored field, and — see D1 — **no change to
  `SharedPractice.currentSchemaVersion`.**

## Context

ADR 0188 built the whole of file-based sharing: one file type, one payload, two doors. A drill could
already cross, but only as a passenger — inside a routine whose blocks named it.

`docs/positioning.md` §1 argues the product's multiplier is a teacher handing practice to a student,
and §5 makes the routine the unit of that. A single drill is the *smaller and more frequent* unit of
the same act: "try this one at 80 this week" happens far more often than handing over a whole sitting.

**The format was built for this and said so.** Three comments in 0188's own code named this feature
before it existed:

- `SharedPracticeKind` carried one case under an argument for a discriminator over a second file
  type, because it "costs a field now and nothing later — the first time an exercise share ships".
- `ReceiveFailure.unsupportedKind` named "an exercise share from a later version, most likely" as the
  case it existed for.
- `SharedPractice.exercises` already carried `ExerciseRecord`s inline, and
  `SharedPracticeBuilder.shareable(_ exercise:)` had already decided exactly what a drill loses when
  it goes to somebody who has practised none of it.

So the question this ADR actually had to answer was not "how do we share an exercise" but "was that
estimate honest, and where does the second kind change the shape of the door". It was, and it does —
in one place, D5.

## Decision

### D1 — a second kind, and **no** schema-version bump

`SharedPracticeKind.exercise`. The drill travels as a single element of the existing `exercises`
array; `routine` stays `nil`. One field for both payloads rather than a `var exercise:
ExerciseRecord?` beside it: a drill crosses on identical terms either way, and a second spelling of
the same fact is a divergence waiting to happen where nobody can see it — in the file.

`SharedPractice.currentSchemaVersion` is **not** incremented, and this is the load-bearing half of
the decision. The version is about record *shapes*, and no record changed. The discriminator is what
tells an older build it is looking at something it cannot open, and it already does so in words. A
bump would additionally make every **routine** file written by this build refused by every build
already in the wild — a real regression, bought for a change that altered no record.

The consequence is that a shipped build meeting an exercise file says *"This file holds something
this version of Red Moon can't open yet."* That is `.unsupportedKind`, reached exactly as 0188
predicted it would be.

### D2 — the drill loses what ADR 0188 already decided it loses

`SharedPracticeBuilder.shareable(_ exercise:)` unchanged, and
`ReceivedRoutineBuilder.exercise(from:)` unchanged on the way back: mastery, `masteryTempo`, command
tempo, `linkedSongIDs`, `references`, `presetSlug`, `isFavorite` and `lastPracticed` all dropped. The
shape crosses; the sender's achievement does not.

The alternative — a second pair of functions for the standalone door — would mean two answers to
"what does a received drill keep", and the day they disagreed the same file would land differently
depending on how it had been sent. Both functions stopped being `private` instead.

`currentTempo` **does** cross, as it already does inside a routine share. Recorded here as a knowing
carry-over rather than an oversight: it is where the ramp starts, `Exercise.duplicated(named:)` keeps
it too, and changing it for the standalone door alone would violate the paragraph above.

### D3 — sent from the drill's own read-only sheet, and not gated

The share control goes on `ExerciseDetailSheet` — the ⓘ reference sheet, the place you go to read
what a drill *is* (ADR 0077). ADR 0188's argument transfers whole: practice is handed over
deliberately, usually after looking at it, and the library's hold menu is where the bulk verbs live
(details, duplicate, favourite, delete), where a share is a share nobody finds.

**One thing does not transfer.** The routine's control hides itself while editing, because a routine
handed over mid-edit could contain blocks the sender then cancelled. This sheet has no edit mode — but
it does keep its **description** in `@State` until Done. A payload built from the model alone would
hand over the description the sender had just replaced, silently, with nothing about the file to show
it. So the sending path passes the in-flight text (`SharedPracticeBuilder.exercise(_:notes:)`) and the
file says what the screen says. Mastery, the sheet's other uncommitted field, needs no such care: a
share drops it either way.

**Sending is not gated.** Every other exercise verb asks `AccessPolicy.canAuthor` first; this one
deliberately does not. Handing a drill to a friend authors nothing on the sender's device, costs
nothing, and is the multiplier working in the app's favour. Stated here so it is not later tidied
into a gate on the grounds of consistency.

### D4 — one door, generalised

`ReceivedPracticeBuilder.evaluate` is now the single entry point for both payloads: it decodes,
gates the version, reads the kind, and returns a two-case `ReceivedPractice`. `RoutineReceiveHost`
became `PracticeReceiveHost` and `\.receiveRoutineFile` became `\.receivePracticeFile`.

A second `evaluate` for exercises would have meant a second decode, a second version gate and a
second place for the trust asymmetry to be got wrong. Both existing doors — tap-to-open at the root
and the picker — then accept both kinds for free, and the Exercises library gained a picker row of
its own.

**The pickers are deliberately not kind-specific.** The kind lives *inside* the file and the system
filters on type, so a picker that offered only routines is not something that can be built. Both
libraries share one importer; the host reads what is really in the file and the confirmation says
where it went. Picking a drill from the Routines screen works, rather than presenting a file the app
then refuses.

Adding the row to the Exercises library also required making its options menu **unconditional**. It
was wrapped in `if !presentExercises.isEmpty`, which would have hidden *Receive an exercise…* at
exactly the moment a player most wants it — a first drill arriving from somebody else, with nothing
of their own to show yet. `RoutineLibraryView` had already solved this; the fix was to adopt its
shape, where only the favourites filter takes the emptiness.

### D5 — the gate moves behind the read

ADR 0188 checked Pro **before** opening the file, on the stated grounds that a free player's problem
is not the file, so they should get the offer rather than a report about JSON.

That worked while a routine was the only thing a file could hold and the answer was "Pro, always". An
exercise's gate is `AccessPolicy.canAuthor(_:isPro:)`, which asks about the drill's **template** — a
fact *inside* the file. So the file has to be read to know which question to ask. The order is now:
read, evaluate, then gate on what was found.

**Today that question has only one answer, and this is worth stating rather than implying otherwise.**
Since ADR 0144 every `ExerciseTemplate.authoringTier` is `.pro`, so `canAuthor` collapses to `isPro`
and the exercise gate behaves exactly like the routine one. A pre-read `isPro` check would give the
same verdict on every file that exists. The reason the gate is nonetheless asked in template-shaped
form, after the read, is ADR 0144 D3's seam: the tier is deliberately kept as a *per-template*
question so a free line can return without touching a call site. A gate that read `isPro` directly
would be the one place that had quietly hard-coded the collapse, and it would wall a free-tier drill
on the day the seam was used.

So what changes for a free player **today** is only the **failing** cases. A valid file walls exactly
as it did. A corrupt or future-version file now reports itself instead of presenting a paywall for a
file that was never going to open — which is the more honest of the two, and arguably what 0188
should have done.

The trigger is its own case, `PaywallTrigger.receivedExercise(ExerciseTemplate?)`, for
`RoutineGate.receive`'s reason: it is the one exercise gate the player did not walk up to, and a wall
in front of a file that arrived unbidden is very different evidence from a wall in front of an empty
editor. A drill whose template this build cannot name is refused for a free player rather than waved
through — an unreadable tier is not a free tier — and the trigger carries `nil`, which is true.

### D6 — a preview before it lands, with no placeholders

`ReceivedExercisePreviewSheet`: name, template, feel, tempo plan, description, tags, and the same
provenance footer. Every value is read off `ReceivedExercise` rather than off the record, so what the
player is told and what lands cannot disagree.

**No `SharedBlockPlaceholder` equivalent, and the asymmetry is the point.** That type exists because a
routine would otherwise arrive silently *shorter*: a block whose loop cannot travel leaves a visible
gap, so the file names it. A drill's shape arrives whole — its dropped song and reference links leave
no hole to explain — so the footer says once, plainly, what a shared drill never carries, and nothing
in the file has to enumerate it.

A template this build cannot name draws **nothing** rather than a wrong chip. The confirmation screen
is the last place that should tell the player something untrue about a file, and the raw value still
survives into the model for a build that understands it.

### D7 — analytics

`exerciseReceived(template:)`. The template is the one property worth carrying: it says what kind of
practice actually gets passed between players, and makes the comparison against `exerciseCreated` —
what people author for themselves — possible.

## Consequences

- **A drill can now be handed over, and the file format did not have to change to allow it.** ADR
  0188's estimate that the second kind would cost "a field now and nothing later" was accurate to
  within one decision: D5.
- **`currentTempo` crosses**, which means a received drill starts where the sender's did rather than
  at a default. Defensible (it is the ramp's floor, not a grade) and consistent with the routine door,
  but it is a number the receiver did not set, and it is the one carry-over worth revisiting if the
  distinction between "where this starts" and "where I got to" ever needs to be sharper.
- **Two existing tests were asserting nothing and were found by this change.** Both used the string
  `"exercise"` as their example of a payload kind no build writes; shipping one turned each into a
  test that passed while checking a known kind. Both now name something no build writes. A refusal
  test whose sentinel becomes real is a failure mode worth watching for wherever else a raw string
  stands in for "unknown".
- **The archive's dates round-trip to within a millisecond, not exactly.** `ArchiveCoding` writes
  ISO-8601 to three decimal places and truncates: .123 returns .122. Harmless for what these
  timestamps are, but `ReceivedRoutineHydrationTests`'s "dates survive to the millisecond, both ways"
  used a whole-second fixture and so never tested it. `ReceivedExerciseTests` uses a fractional one
  and asserts with tolerance.
- **Reference links still do not cross**, for either payload. 0188 left this open because half of them
  are attachments whose bytes live on the sender's device; nothing here changes that, and the preview
  now says so out loud.
- Not built: sharing more than one drill at a time, a share control on the library row, and any
  crossing of attachments.
