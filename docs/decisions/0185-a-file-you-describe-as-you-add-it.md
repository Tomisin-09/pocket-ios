# ADR 0185 — a file you describe as you add it

- **Status:** Accepted
- **Date:** 2026-09-01 (`pocket-289-name-a-file-as-you-add-it`)
- **Relates to:** ADR 0167 (references — this corrects an asymmetry that ADR's phase 2 introduced),
  ADR 0090 (`.sheet(item:)` on a `@Model` — why a draft is identified by `uid`), ADR 0165 (the manual
  quotes the app — `docs/manual/references.md` moves with this)
- **Schema:** none. No `@Model` field is added, removed or retyped; the only writes are the two
  `String`s `ReferenceLinkStore.updateAttachment` has always written.

## Context

ADR 0167 shipped in two phases, and the two halves of **Where you learned it** ended up with
different manners.

**Adding a link** opens a sheet with three fields — Link, Name, Note — and you describe the source
while you are putting it in. The Note field is the one the manual argues hardest for: *the name says
what the source is, which you can work out from the address a week later; the note says what you took
from it, which you cannot.*

**Adding a file** did none of that. The menu opened a picker, the picker handed back bytes, the bytes
were written, and a row appeared in the section called `Picture`. Name and Note existed for a file —
`ReferenceLinkStore.updateAttachment` has always written both, and the editor has always hidden its
Link field for an attachment — but the only way to reach them was **hold the row ▸ Edit details**.

That is the wrong shape for three reasons, and the third is the one that matters:

1. **The gesture is unadvertised.** ADR 0167 phase 1 already learned this once, on this exact
   section: editing a link was reachable *only* by a leading swipe, nothing on the row said so, and a
   badly named link was effectively stuck. The fix then was to add the hold menu. A file arriving
   unnamed puts the player back in front of the same undiscoverable gesture.
2. **The row says less than it could.** An unnamed attachment falls back to its kind, so five
   screenshots on one exercise are five rows all reading `Picture`.
3. **The moment you know what a file is, is the moment you pick it.** You have just come out of a
   grid of four thousand photos having recognised one. A week later you are looking at a thumbnail
   44 points wide. Deferring the naming to "whenever you think to hold the row" defers it past the
   only point at which it is easy — which is precisely the argument ADR 0167 made for putting the
   Note field in front of a link rather than behind one.

Raised by the owner as *"align it more to how we add links in a descriptive sense"*.

## Decision

**D1 — The editor opens on a file the moment it is imported.** `ReferenceAttachmentPicking` no longer
ends at the write; it hands the new row to the same sheet **Add a link** uses. Adding a file is now
two steps, the second of which is describing it — the same shape, and the same sheet, as a link.

**D2 — A new draft case, `.naming`, rather than a reuse of `.editing`.** They are different moments
and the sheet has to say so: `.editing` is a correction of something that has been sitting there,
`.naming` is the second half of adding. Only the title and the way out differ, so the case carries no
state of its own.

**D3 — The sheet is titled "Add a file", not "Edit details".** It is the completion of the act the
menu item started, and it should be called what started it — the way "Add a link" is.

**D4 — The way out is Skip, and the file stays.** The bytes are copied into Red Moon by
`ReferenceAttachmentStore.adopt` at the moment of the pick; by the time this sheet is on screen there
is nothing left to cancel. A button that said *Cancel* would be describing an undo that does not
happen. **Skip** declines the describing and nothing else, which is what both fields — each marked
optional — already promise.

Two alternatives were weighed and both rejected:

- **Cancel that deletes the attachment.** It would mirror the link sheet exactly, where cancelling
  means nothing was added. Rejected because it throws away a pick over a naming step the app itself
  calls optional, and because it puts a destructive path on a sheet that otherwise only writes words.
  A file picked by mistake is removed the way every other row is: hold, Delete.
- **Hold the bytes and write only on Save.** Semantically the cleanest — Cancel would then be true.
  Rejected because it puts a draft payload into the modifier whose entire history is presentation
  bugs, and because it splits the import into two moments that can disagree about the per-owner cap.
  One write path, at the moment of the pick, is what makes the cap and the re-encode impossible to
  differ between the photo route and the Files route.

**D5 — The sheet shows the file it is describing.** A read-only row at the top: the thumbnail at 64
points, and the kind beside it. The Link field tells you what you are describing; for a file, a
picture of it does the same job. Without it, naming a photo means naming it from memory of a picker
you have already left, which is where the wrong one gets kept *and* described. It is read-only
because a file is renamed, never re-pointed — the phase 2 rule that the commit path already enforces
by branching on the row's own kind rather than on what the editor sent.

Shown when **editing** an attachment too, not only when naming one. One sheet, one shape.

**D6 — The naming intent is raised a main-actor turn late.** The picker is still dismissing when it
hands the bytes back, and asking SwiftUI to present a sheet on a root that is mid-dismiss is the
fight ADR 0167 phase 1 paid six-minute test runs to learn about. `describe(_:)` clears the picker's
own intent and hops to the next turn.

## Consequences

- The four hosts (`ExerciseDetailSheet`, `SongDetailsSheet`, `WaveformEditSheets`,
  `RoutineDetailView`) each pass their existing `ReferenceLinkDraft` state to
  `.referenceAttachments(…)` as well. They already held it for the link half; nothing new is stored.
- `RoutineDetailView` keeps its contract untouched. It passes `savesImmediately: false` and its
  sandbox context to both modifiers, so a file added *and named* inside the routine editor still
  lives or dies with that screen's Cancel/Save.
- `ReferenceLinkKind.capitalizedNoun` replaces a `fileprivate` helper used in one place. The row's
  fallback title and the preview's label now read the same accessor, so the two cannot drift into
  disagreeing about what a `.md` is called.
- **No new shot marker.** The naming sheet is a figure worth having, but it can only be reached
  through an out-of-process picker, and `docs/manual/README.md` already carries one open row
  (`references/section`) for a figure that cannot be driven. A marker nothing can shoot makes the set
  worse, not better; the prose describes the step instead.
- `docs/manual/references.md` moves with the feature, per ADR 0165 D1 — the manual owns procedure,
  and this changes the procedure.

## How D6 was actually verified, and what that turned up

**On the device, by hand, because the harness could not reach the control.** Driving the flow in the
simulator failed twice over: tapping `Add a file` on the exercise detail sheet lands on the *run
screen* — the sheet dismisses instead of the menu opening — and `ManualReferenceShots
.testReferencesSection` could not resolve `Where you learned it` at all.

**Both reproduce byte-identically on unmodified `main`.** Checked by stashing this branch and
re-running the same probe against a clean tree: same failure, same accessibility hierarchy, same
navigation bar. So neither is a regression from this change or from ADR 0167, and neither should be
read as one by whoever meets them next.

Whether they are a real defect or an XCUITest artifact is **open**. Two things argue for the
artifact: a `Menu`'s items already fail to resolve under test on CI's Xcode 16, which is the same
control in the same position; and this exact flow — menu, picker, pick, naming sheet — was walked by
hand on an iPhone 16 Pro on 2026-09-01 and behaved correctly, D6 included. Two things argue for
caution: the machine those runs happened on was in Low Power Mode under a load average near 16, and
one run of the same suite aborted on an unrelated `AudioToolbox` RPC timeout in
`PracticeAudioEngine.init()`.

The consequence that matters: **the `references/section` reshoot is blocked behind this**, since the
test that would shoot it cannot reach the section. Settle it on a quiet machine, and on device,
before changing app code for it.
