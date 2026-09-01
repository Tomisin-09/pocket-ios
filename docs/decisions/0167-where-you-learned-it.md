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

**A `ReferenceLink` is a URL, a title and an optional note, owned by an exercise, a song, a
loop or a routine, shown where you choose what to practise and never where you are
practising.**

> The note was added by the revision at the end of this ADR (2026-08-19). As originally
> decided this read "a URL and a title".

### The model

New `@Model ReferenceLink`. A new entity is **additive**, which the schema freeze
explicitly permits — `docs/backlog.md:1164` records that only retypes, renames and removals
are now-or-never.

```swift
var uid: UUID
var title: String = ""
var note: String = ""        // added by the 2026-08-19 revision, below
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

## Built — 2026-08-17 (`pocket-268-reference-links`)

The URL half shipped as decided, with three things worth recording because they are not in the
decision above:

- **`ReferenceLinkStore` is the single write path**, over a `ReferenceLinkOwner` protocol the four
  models conform to (`Core/Models/ReferenceLink+Owners.swift`). Without it the `http`/`https` gate
  would live in a view, and the five surfaces would each own a copy of the `order` renumbering.
- **A scheme-less paste is read as `https`.** Not stated above, and it is the input the feature
  exists for — a phone share sheet hands over `youtube.com/watch?v=…`. A string that *does* carry a
  scheme is still taken at its word and refused if it is not on the allowlist, so `javascript:` is
  never rewritten into something openable.
- **The paste affordance is a `PasteButton`, not a `Button` that reads `UIPasteboard`.** The first
  build did the latter — inside `body`, so it could offer *"Paste youtube.com"*, naming the site it
  would paste. That is a worse feature than it sounds: reading the pasteboard programmatically
  raises the system's *Allow Paste?* prompt, so opening this sheet would have asked permission to
  inspect the clipboard, and it re-read on every body evaluation. Under UI test it hung the app for
  sixty seconds (`App event loop idle notification not received`). `PasteButton` makes the tap the
  consent: nothing is read until the player asks, and no prompt appears. The cost is that the
  control says *Paste* rather than naming the host — the right trade, and one §3.5 would have
  reached anyway.
- **The routine surface needed three constraints the ADR did not anticipate**, all from
  `RoutineDetailView` being a sandboxed editor rather than a live one:
  1. **Gated on `existsInStore`.** A provisional generated session is not saved yet; attaching a
     link would insert the routine through the relationship and quietly keep a routine the player
     never chose to keep.
  2. **Writes into `editContext`, not the environment's context.** The routine is faulted into a
     private child context; inserting a link through the app context while pointing it at that
     routine is a cross-context relationship — a corruption, not a preference. `ReferencesSection`
     grew an explicit `context:` parameter for this, defaulting to the environment for the other
     three surfaces.
  3. **Read-only outside edit mode, and it does not save on each change.** Outside edit mode there
     is no Save, so a link added there would sit in the sandbox until the next Cancel threw it away;
     inside it, saving per-change would commit whatever block rearrangement was pending, making an
     unrelated edit permanent because somebody added a link. Links follow the screen's existing
     contract instead — Cancel discards, Save keeps — which is also the rule the manual already
     stated for that screen.

  The other three surfaces edit live models and keep the immediate write, matching how linked songs
  already behave beside them.

The manual page is `docs/manual/references.md` — one page, pointed at from the four owner pages
rather than restated on each.

**Phase 2 (images) is unbuilt and unchanged.** `kindRaw` ships carrying `.image`, so it stays a pure
addition.

## Revision — a note beside the link (2026-08-19, `pocket-277-a-routine-that-remembers`)

**A reference link gains an optional free-text note.** The decision line and the model block
above are amended in place; this section is the reasoning.

**Why the title was not already enough.** The title answers *what the resource is*, and a week
later that is the half you can reconstruct — the host is right there under it. What you cannot
reconstruct is *what it gave you*: that the useful four minutes start at 4:10, that only the
chorus voicings are worth taking, that the first half is theory. The whole argument of this ADR
is keeping the thread back to where something came from, and a pointer with no note keeps the
address while losing the reason.

- **`var note: String = ""`** — plain non-optional `String` with a declaration default, the
  shape `Exercise.notes` and `Song.comment` already use. Never `String?`: an `init`-only
  default is the CoreData 134110 failure this file's model discipline exists to prevent.
  Additive on a live table, which the schema freeze permits, and device-verified against an
  install holding pre-existing links rather than trusted to a green in-memory test.
- **It renders as a third row line, capped at two lines**, under the site. The cap is
  load-bearing rather than cosmetic: `ReferenceLinkRow` is shared by the section, the read-only
  section and `ReferencesCard`, and the card sits in `RoutineBlockPreview`'s `ScrollView` where
  an uncapped note would push the rest of the card off the screen.
- **VoiceOver gets it in full, untruncated, by construction** — the row is a plain `Button`
  with no `accessibilityElement(children:)` override, so SwiftUI folds the note into the
  combined label. The two-line cap is a layout decision, not a content one, and the hint stays
  about opening the destination. Adding the note to the hint as well would read it twice.
- **`ReferenceLinkStore.add` defaults `note:`; `update` deliberately does not.** A defaulted
  parameter on `update` would let a call site that never mentions the note silently erase one
  the player wrote. Adding a link cannot lose anything; correcting one can. The note is written
  *after* the URL guard, so a rejected edit still leaves title, URL and note all untouched.

**Fixed in the same pass:** the editor's Link field is `axis: .vertical` and shipped with no
`keyboardDoneButton`, so there was no way off the keyboard. One accessory now covers the sheet.

**The routine's prose gap is narrowed but not closed.** A routine still has no description of
its own — this gives it words *about a source*, not about itself. `docs/backlog.md` Routines
item 2 stays open.

**Phase 2 (images) remains unbuilt and unchanged by this.**

### Also in this revision — a hold that opens the row's menu

**Correcting a link was reachable only by a leading swipe**, and nothing on the row said so.
Tapping opens the source, so a player looking for a way in finds the one gesture that does
something else. Found the way this kind of thing is always found: on a device, by going
looking for it and not finding it.

A hold now opens a **menu — Edit link, Delete** — which is the grammar every other list row in
the app already reads in through `pocketRowActions`. The swipes stay; this adds a route rather
than moving one.

**It is a `.contextMenu`, and the first attempt was worse.** That pass hung an
`onLongPressGesture` on the row, which forced `ReferenceLinkRow` to stop being a `Button` —
a SwiftUI `Button` fires its tap action on the *release of a long press too*, so it would have
opened the source **and** the editor on every hold, the bug this repo has already shipped to a
device twice. Rebuilding the row as a plain shape with hand-rolled gestures worked, but it also
meant re-deriving the accessibility traits a `Button` gives for free, and it produced a bare
Edit action where every other row in the app offers a menu. A `.contextMenu` has no quarrel
with the tap, brings its own haptic and lift preview, and needs none of that. **The row that
needed hand-rolled gestures was the row solving the wrong problem** — worth recording, because
the hand-rolled version looked like the careful choice right up until the shared idiom was the
answer.

Delete is `role: .destructive` and **immediate**: these hosts install no deferred-delete seam,
so there is no undo toast, and a row that vanished on a promise the screen cannot keep would be
worse than one that goes when you say so. `docs/manual/references.md` says this out loud, since
`gestures.md` otherwise promises undo on every row delete.

The menu is on `ReferencesSection` only. The two read-only surfaces
(`ReferencesReadOnlySection`, `ReferencesCard`) get no hold — a gesture offering to edit on a
screen that deliberately does not edit is worse than no gesture.

One tooling consequence, found the hard way. `scripts/check-manual.py`'s `long-press-sites`
tripwire counted **raw text**, so the doc comments *explaining* the `onLongPressGesture`
decision registered as two extra hold sites and failed C8 against a file that wires up none.
The counter now strips comments before counting, exactly as C9 already does and for exactly the
same reason: this codebase documents itself heavily and names the APIs it discusses.

## Phase 2 built — 2026-08-31 (`pocket-287-reference-attachments`)

**A reference can now be a file you keep: a picture, a PDF, a `.txt` or a `.md`.** The four questions
`docs/backlog.md` left open were the whole decision list; they are answered here, and everything else
came off the shape phase 1 already had.

### It stopped being "images" during the build, and that was right

The entry, the backlog and the first day's code all said *image attachments*. What the feature is
**for** is keeping the thread back to where something came from — and the honest observation, made
while testing the file picker, is that **a downloaded guitar tab is usually a PDF or a `.txt`, and
neither is ever in the camera roll.** Shipping images alone would have covered the screenshot case
and missed the format the material actually arrives in.

So `ReferenceLinkKind` carries four: `.image`, `.pdf`, `.text`, `.markdown`. Three consequences worth
stating, because each one is a place a simpler design would have been wrong:

- **Only images are re-encoded.** A photo is *material to look at*, so downscaling it costs nothing
  anyone can see. A PDF is a **document**, and rewriting a document loses part of it — a tab
  flattened to a JPEG of page one silently drops pages five to nine, which is a worse feature than
  refusing PDFs. Documents are stored byte-for-byte, bounded instead by a 25 MB ceiling, since
  nothing else bounds them.
- **`.txt` and `.md` are separate kinds because they are drawn differently.** ASCII tab is a *grid*:
  fixed-width, never wrapped, scrolling sideways, because soft-wrapping folds bar 3 under bar 1 and
  the six strings stop being six strings. Markdown is *prose*: it wraps, in the app's own face, with
  its emphasis rendered. Storing both as one kind would have meant picking one treatment and being
  wrong about half the files. The known cost is stated in the manual — ASCII tab pasted inside a
  `.md` wraps; save it as `.txt`.
- **The bytes decide the kind, not the picker.** `contentType` is a hint. A `.txt` extension on a
  JPEG, a PDF served with no type at all — the model must never say *picture* about something no
  picture viewer can open. `resolve` tries ImageIO, then the PDF magic number, then text; and it
  checks **Markdown before plain text**, because `net.daringfireball.markdown` *conforms to*
  `public.plain-text`, so asking the plain-text question first answers `true` for every `.md`.

### The picker was offering files the app would then refuse

`allowedContentTypes: [.image]` looks right and is not. `UTType.image` is the abstract supertype, so
the filter offers everything conforming to it — including **SVG, which ImageIO cannot decode**
(measured on iOS, not assumed: a throwaway probe listing `CGImageSourceCopyTypeIdentifiers()`). The
picker advertised a file and the app then rejected it. `pickerTypes` is now derived from what ImageIO
actually reads, plus the document types, so a file that appears selectable is one that will work.

The same probe settled what *is* accepted, and it is worth having written down: JPEG, PNG, HEIC/HEIF,
GIF, TIFF, BMP, ICO, WebP and about thirty camera RAW formats.

- **Photos and Files. No camera.** Both are out-of-process pickers, so neither needs an
  `Info.plist` usage string — and `AGENTS.md` forbids adding one the app does not exercise. A camera
  would be a real new capability for a feature whose commonest input (a tab screenshot) is already in
  the roll. Photographing a book page goes through the camera app and the roll, one extra step, for a
  permission the app never has to ask for. Reversal condition: if that step is what stops people using
  it, `NSCameraUsageDescription` plus a third menu item is the change, and nothing else moves.
- **2048px longest edge, JPEG 0.85, enforced in `ReferenceAttachmentStore.adopt`.** In the store, not at
  the picker, because that is the single write path: a 48-megapixel photo entering through Files must
  arrive the same size as one from Photos, and an import surface added later must not be able to opt
  out. ImageIO rather than `UIImage`, for three reasons that all bite here — it reads HEIC, which is
  what the roll actually hands over; `kCGImageSourceCreateThumbnailWithTransform` bakes in the EXIF
  orientation, so a sideways photo is stored the way it was seen; and it touches no UIKit, so the rule
  stays testable on bytes with no container, no picker and no device.
- **Five per owner; the control disables and the footer says the number.** Files are capped and links
  are not, which reads as inconsistent until the two are priced: a link is a hundred bytes and a row,
  a file is megabytes and a thumbnail in a card `RoutineBlockPreview` already has to keep short. The limit **replaces** the footer's second sentence rather than appending a third clause —
  a footer that grows when you hit a cap reads as telling you off (§3.5).
- **The title is the alt text, and it is not required.** No fifth string on the model. An unnamed
  attachment reads as its kind — *Picture*, *PDF*, *Text file*, *Markdown file* — and the Name
  field's footer is where that is said. Requiring a name in
  front of a photo just chosen is friction exactly where the feature is weakest, and the row is a
  plain `Button` — SwiftUI folds the title and note into one combined label with no work from us.

### What the ADR did not anticipate

- **`attachmentFileName` is a new field, not a reuse of `urlString`.** Storing the leaf in the URL column
  would have been free and wrong at the first read: `destination` would have handed a container file
  URL to `openURL`. `destination` now returns `nil` for an image by construction, so a picture cannot
  be opened *out* of the app however the row is wired.
- **The bytes are written before the row exists.** `adopt` is the throwing half, so a picture that
  cannot be decoded leaves the store exactly as it was — no row pointing at a file that was never
  written. That forces the `uid` to be minted in `ReferenceLinkStore.addImage` rather than by
  `makeReference()`, because the file is named for it.
- ⚠ **`OrphanSweep` is the *primary* collector for this directory, not a backstop.** For songs and
  takes the sweep catches interrupted writes. Here the cascade — the rule this ADR chose over nullify
  — deletes reference rows without running a line of our code, so **deleting an exercise strands every
  file attached to it**. `ReferenceLinkStore.delete` removes the file on the paths that do run
  through us, which is what makes space come back when the player deletes one rather than the next
  time they open Settings; everything else lands in *Reclaim space* (ADR 0182). `StorageUsage` gained
  a *Reference files* category so the figure stays honest.
- **The routine editor's Cancel deletes the bytes it discards.** That screen defers every save
  (phase 1, constraint 3), but a picture's file is written the moment it is picked — so discarding
  the sandbox's rows alone would strand a file on a path the player takes on purpose, not on an
  edge case. `cancelEdits` now sweeps `editContext.insertedModelsArray` for reference links before
  rebuilding the sandbox: that set is exactly the uncommitted rows, because the context never
  autosaves, so a picture the player *kept* is never in it. Everywhere else the orphan sweep is the
  right answer; here, space that only comes back via Settings is space they would notice going.
- **The export carries them** (ADR 0181), staged into `references/` and **not** behind the
  take-audio switch. That switch exists because recordings are the bulk of a library; five capped
  attachments are not, and a second toggle for them would be a choice offered for no reason. An
  export that named a file it did not carry would be a record the player cannot reassemble.
- **The picture viewer does not zoom; the PDF viewer does.** A picture is glanced at beside the
  thing being practised — which is exactly why 2048px is enough — and a pinch-zoom image reader is the
  first step towards parsing a tab, which
  `docs/research/feasibility-tab-to-fretboard.md` Phase T3 explicitly does not plan. A PDF is
  different in kind: it *arrived* as a document, it is stored whole, and a multi-page tab you cannot
  page through is not a tab. PDFKit does that properly and we do not reimplement it.
- **`ReferenceImagePresentation` is a third piece of host-owned state**, alongside
  `ReferenceLinkDraft`. `.photosPicker` and `.fileImporter` are presentations too, so they hit the
  same trap phase 1 paid six minutes a run to find: attached inside another sheet's `Form`, they fight
  the presentation that already owns the screen. The read-only surfaces take the viewer half alone
  (`.referenceImageViewing`) — looking at a picture is reading, which is what those screens do.

**Not built, and not owed by this ADR:** no reordering of files relative to links beyond the one
`order` they already share, no captions burnt into an image, no in-app editing of any attachment, and
**no OCR** — that last one is a decision, not an omission, and taking `.txt` and PDF makes it *less*
tempting rather than more: the tab arrives as text already, and we still do not read it.
