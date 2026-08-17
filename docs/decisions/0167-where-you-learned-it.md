# ADR 0167 — where you learned it

- **Status:** Accepted
- **Date:** 2026-08-16 (`pocket-267-positioning-and-references`)
- **Relates to:** ADR 0001 (local files — the material is the player's own), ADR 0066 R4
  (typed optional owners over a generic `ownerKind + ownerID`), ADR 0070 (never grades the
  player), ADR 0077 (the run screen carries no authoring or review), ADR 0151 (a take
  outlives its loop — the *nullify* contrast), ADR 0161 (the app's one outbound request)
- **Unrelated to ADR 0152 *"a link you can correct"***, despite the word. That ADR is about
  **relinking an audio file** whose bookmark has gone stale. This one is about a **URL the
  player types**, pointing out of the app at where they learned something. Different sense
  of "link", no shared code, no shared model.
- **Positioning:** `docs/positioning.md` §1 (multiplier), §3 (no shame). This is the
  feature that makes the multiplier thesis visible rather than merely claimed.

## Context

Pocket does not own the material and does not own the method. Somebody else is teaching
the thing — a YouTube lesson, a teacher, a course, a tab site — and the app's job is what
happens between opening that resource and being able to play it.

Today the app records **none** of it. A player builds an exercise from a lesson, closes
the app, comes back a week later and the exercise is a fretboard diagram with no
provenance. The lesson is somewhere in a watch history. The routine built around a
course's week 3 does not know the course exists. The multiplier thesis is stated in
`PROJECT.md` and lived nowhere in the model.

`Routine` is the sharpest case: it has **no description, no notes and no comment field at
all** (`Pocket/Core/Models/Routine.swift` — `uid`, `name`, `dateAdded`, `lastPracticed`,
`isFavorite`, `presetSlug`, `items`), unlike `Exercise.notes` (`:200`) and `Song.comment`
(`:70`). A routine built from a specific course has nowhere to say so.

### Prior art, named

**Captrice** (`captrice.io`) already ships this: free, browser-based, it embeds tab and
notation inside an exercise for reference and loops a marked YouTube section at an
adjustable rate. An ADR that ignores a free competitor shipping the same feature is a wish,
not a decision record.

What we do differently is narrower and, we think, more honest:

- **Four owner types, including `Routine`.** Captrice attaches reference to *exercises*.
  A course belongs to a session, not to a drill — the routine owner is the most on-thesis
  half of this feature and the half nobody else models.
- **We point out, we do not render in.** Captrice embeds; we open the source in its own
  app. Embedding means owning a viewer, a fetch path and somebody else's content policy.
  Pointing out means the resource stays the resource.
- **It works on the player's own audio.** Captrice is YouTube-only. The material practised
  against here is a file the player owns (ADR 0001), and the reference is a pointer beside
  it, not the thing itself.

### It answers the backlog's parked question

`docs/backlog.md:1431` parks image attachments on exercises *"until we can articulate what
the user gains."* **This is that articulation** — the gain is not "attach a picture", it is
*keep the thread back to where this came from*. Marked unparked there, with images
sequenced second.

## Decision

**A `ReferenceLink` is a URL and a title, owned by an exercise, a song, a loop or a routine,
shown where you choose what to practise and never where you are practising.**

### The model

New `@Model ReferenceLink`. A new entity is **additive**, which the schema freeze
explicitly permits — `docs/backlog.md:1164` records that only retypes, renames and removals
are now-or-never.

```swift
var uid: UUID
var title: String = ""
var urlString: String = ""
var order: Int = 0
var dateAdded: Date = Date.now
var kindRaw: String = "link"
```

- **`kindRaw` is a `String`, never a raw enum attribute.** `docs/swiftdata-gotchas.md`
  records the ADR 0036 device crash this rule comes from: a custom enum stored on a
  `@Model` migrates cleanly in the simulator and crashes on device. Carrying the field
  from day one makes phase-2 images a **pure addition** rather than a retype after the
  freeze.
- **Owners are typed optional relationships**, the pattern ADR 0066 R4 chose over a generic
  `ownerKind + ownerID` and `JournalEntry` follows: `exercise: Exercise?`, `song: Song?`,
  `loop: Loop?`, `routine: Routine?`. Exactly one is non-nil.
- **Inverses on each owner are `.cascade`.** ⚠ This is the opposite of notes and takes, and
  it is the first question a reviewer will ask. Notes and takes **nullify** (ADR 0151)
  because they are records of *you* — a reflection you wrote outlives the loop it was
  about. A reference link is a record of *the owner*: it is a pointer to where **this
  exercise** came from, and it means nothing once the exercise is gone. Delete the owner,
  delete the pointer.
- Register in `PocketApp.swift:77` alongside the other twelve models.
- **Never filter on it in a `#Predicate`.** Optional-relationship predicates freeze the
  main thread (`docs/swiftdata-gotchas.md`); filter in memory.

### Where it appears

**At the *choosing* moment.** A References section on the owner's detail or edit surface —
the exercise editor, the song details sheet, loop settings, routine detail — plus the
read-only `RoutineBlockPreview`, which the manual already frames as checking *"what is in a
session without starting it"* (`docs/manual/routines.md:140-143`).

**Deliberately not on run screens.** This dissolves what looked like a four-surface problem
(`LoopRunView` · `EarLoopRunView` · `ImproviseLoopRunView` · `WaveformPracticeView`; only
the middle two share chrome, via `LoopModeSections.swift`). Two principled reasons, not one
practical one:

1. **ADR 0077 already strips authoring and review from the run screen.** A reference belongs
   to the same family as a note: something you consult before or after, not during.
2. **Tapping a YouTube link mid-session leaves the app.** That is the exact interruption the
   product is written against. Putting the link on the run screen would be building the
   distraction in.

Reversal condition, recorded so it is not re-argued from scratch: if players ask for it,
`LoopModeIdentityHeader` in `LoopModeSections.swift` is the insertion point for the ear and
improvise modes.

### Behaviour

- **`http` and `https` only**, validated on save. Anything else is rejected with a plain
  message.
- **Open with `openURL`.** No web view exists in this app; this adds none, adds no
  capability and needs no `Info.plist` key.
- **No title fetching, no thumbnails, ever.** The app makes exactly **one** outbound request
  today (Formspree, ADR 0161). Fetching link metadata would be new network behaviour on the
  player's private practice data and would require a **privacy-policy change**. The player
  types the title; the row shows the host as its subtitle, derived locally from the URL.
- **A paste-from-clipboard affordance is required, not optional.** On a phone, typing a
  YouTube URL by hand is the difference between this feature being used and not.
- **Copy follows design-brief §3.5.** The section is *References* or *Where you learned it*
  — never "Resources you should organise". No count is judged, no owner is nagged for
  having none.

## Alternatives considered

- **A plain URL field on each owner.** Cheapest, and wrong at the first "I have two lessons
  for this". Also a retype away from ever supporting more than one — the exact class of
  change the freeze closes.
- **A generic `ownerKind: String + ownerID: UUID`.** Rejected for the reason ADR 0066 R4
  gave: it moves referential integrity out of SwiftData and into hand-written lookups that
  cannot cascade. `JournalEntry`'s `routineUID` is the *deliberate* exception (a loose copy
  precisely so it survives deletion) and it proves the rule — a reference link wants the
  opposite lifetime.
- **Embedding the resource, Captrice-style.** Requires a viewer, a fetch path, and a
  position on somebody else's content policy. It also inverts the thesis: embedding is a
  small step towards *being* the source, which §1 of `docs/positioning.md` forbids.
- **Shipping images in the same slice.** Images need storage, downscaling, a per-owner cap
  and alt text. Bundling them would delay the URL half, which is the half that carries the
  argument.

## Phase 2 — images, sequenced second

Not built here. Two things are decided now so the field shape does not change later:

- **Storage follows `SongFileStore` / `RecordingStore`** — bytes in `Application Support/`,
  the leaf filename in the model. **Not** `@Attribute(.externalStorage)`, which is used
  nowhere in this codebase, and which is also the wrong choice for when sync lands: a file
  reference is CloudKit-safe in a way a blob attribute is not.
- **A tab screenshot is deliberately the non-parsing version** of
  `docs/research/feasibility-tab-to-fretboard.md`, whose Phase T3 (OCR) is explicitly *"not
  planned"*. A photo you look at collides with nothing.

## Consequences

- The multiplier thesis becomes a thing the app *does* rather than a line in `PROJECT.md`.
- A routine can finally say where it came from — partially. It still has no description of
  its own; that gap stays open in `docs/backlog.md` (Routines, item 2).
- Thirteen models become fourteen. The container gains one registration line and one
  cascade rule per owner.
- Four owner surfaces gain a section; **no run screen changes**, which is what keeps this
  slice small.
- Deleting an exercise now deletes its links silently. That is intended, but it is the one
  destructive consequence here, and it differs from the note/take rule a reader may have
  internalised — hence the contrast being stated twice.
- **The ADR decides; it does not build.** Implementation is a separate slice.
