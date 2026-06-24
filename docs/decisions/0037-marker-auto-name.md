# 0037 — Markers drop instantly, auto-named (amending 0019)

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

ADR 0019 made loop creation instant: confirming a capture creates an auto-named
loop ("Loop 3") with no naming sheet, renamed later from the row. It deliberately
*kept* the naming step for markers, on the reasoning that "a marker *is* its
label" — a single point carries no range to identify it, so "Marker 3" looked
like a worse default than forcing a name.

Use has shown the opposite. Dropping a marker means stopping to type before you
can keep listening, which fights the same quick-capture intent the loop change
served. It matters most in the intended **loop-creation method** (the parked "art
of creating loops" flow): the musician scans the song and drops markers on
sections of interest *as they go*, then creates loops from those signposts later.
A mandatory naming modal at every drop breaks that scan. The standardised name is
fine as a placeholder — what the marker *is* gets decided later, when loops are
built, not at the instant of dropping it.

## Decision

- **Markers drop instantly, auto-named, no sheet.** `dropMarkerAtPlayhead` now
  creates, persists, and attaches the marker immediately with an auto name
  ("Marker 3") and a confirming haptic — mirroring `createLoop`. The name-only
  `MarkerNameSheet`, the `namingMarker` draft state, and `saveMarkerName` are
  removed.
- **Naming becomes non-obligatory, deferred to the row.** Renaming already lived
  in `MarkerEditSheet` (tap a marker row → edit). That is now the *only* place a
  marker is named — same shape as loops.
- **Reuse the existing `AutoName`.** `AutoName.next(prefix: "Marker", existing:
  markers.map(\.label))` — the same pure, high-water-mark numbering as loops,
  already covered by `AutoNameTests` (its `testWorksForOtherPrefixes` exercises
  the "Marker" prefix). No new pure logic, no new fields on `Marker`.
- **Undo-on-delete is unchanged.** Marker deletion still shows the ADR 0019 undo
  toast and restores by `uid`. Only the *create* path changed.
- **Tapping a marker plays from it.** `seekToMarker` now seeks *and* calls
  `engine.play()` — a marker is a "take me here and go" cue, so selecting one in the
  list starts playback at that point instead of leaving you paused (the same
  play-on-seek a freshly created loop already does).
- **Marker rows mirror loop rows: hold for settings, no pencil.** The trailing edit
  pencil is removed; a marker row is now **tap = seek-and-play, long-press = edit**
  (with a haptic), exactly like the loop row (ADR 0028). The shared `EditPencil`
  view — used only by markers once loops moved to hold — is deleted. VoiceOver, which
  can't long-press, gets explicit **Edit** / **Delete** actions on the row.

## Consequences

- Dropping a marker is one modal shorter: tap **Mark** → it's there, named
  "Marker N", renamed later if the musician cares. The markers panel fills with
  "Marker 1/2/3…" until renamed — the same trade ADR 0019 accepted for loops.
- This **reverses ADR 0019's "markers keep their naming sheet" decision** (and its
  "auto-name markers too — rejected" alternative). The rest of 0019 stands.
- Loop and marker creation are now symmetric, which simplifies the mental model
  and the code (one instant-create pattern, one edit-sheet rename pattern).

## Alternatives considered

- **Keep the sheet but pre-fill the auto name** (one-tap Save) — rejected for the
  same reason 0019 rejected it for loops: still a modal between the action and
  continuing, which is the friction being removed.
- **Open the edit sheet immediately after an auto-drop** so naming is right there
  but skippable — rejected: it reintroduces a modal in the common path. Loops
  don't do this, and symmetry is the point; the row is one tap away when a name is
  actually wanted.
- **Leave markers as-is** — rejected: it's the friction this change exists to
  remove, and it blocks the scan-and-signpost step of the loop-creation method.
