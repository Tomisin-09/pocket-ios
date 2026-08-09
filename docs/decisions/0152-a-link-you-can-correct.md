# ADR 0152 — a link you can correct

- **Status:** Accepted
- **Date:** 2026-08-09 (`pocket-247-replace-song-audio`)
- **Extends:** ADR 0148 §6 (relink is the repair path)

## Context

ADR 0148 §6 gave relink exactly one door, and said so as a principle:

> **The door is the failure itself.** "Find the file" is the primary button on
> `AudioUnavailableNotice`, so the repair is offered at the moment and place the problem is
> discovered, rather than filed away in a settings screen the player would have to know to look for.

That is the right instinct for the case it was written for — a library carried through a reinstall,
where every song is dead and the player needs the fix put in front of them. It has one blind spot,
and it is relink's own failure mode.

**A relink onto the wrong file succeeds.** `SongRelinker.prepare` asks two questions of the picked
file: can it be opened, and can `WaveformExtractor` read it as audio. A different track passes both.
The copy is adopted, the waveform is re-extracted, the duration is written, and the song resolves
from then on. `audioLoadFailed` goes false and stays false, so `AudioUnavailableNotice` never
appears again — and it was the only route to relink. The door closes behind the player, from the
inside, at the exact moment they need it a second time.

What is left is not a small inconvenience. The song plays the wrong recording, and the loops,
markers, takes and practice history attached to it are still perfectly good work aimed at a track
that is no longer there. Re-importing is not a way out: it mints a new `sourceID`, and §4 is
explicit that the `sourceID` is what all of that hangs off — a re-import strands every bit of it and
leaves a duplicate row behind. Deleting and starting over throws the work away on purpose.

This is not hypothetical and it is not rare. Picking the wrong file happens in any file picker, and
it is *most* likely in exactly the situation relink exists for: a restore, where the player is
matching dozens of dead songs against a folder of files they have not looked at in months, from a
notice that hurries them along. The first thing they will want is to correct the one they got wrong.

There is a second, quieter case for the same door: a song relinked to a low-quality or wrong-length
encode that plays fine, and a player who later finds the proper file. Today they cannot use it.

## Decision

### 1. Replacing a song's audio does not require anything to be broken

`SongAudioSection` adds an **Audio** section to `SongDetailsSheet`, carrying the file's format and
size and a **Replace audio file…** action. It is always available — it gates on nothing, because the
state it repairs is by definition one where nothing looks wrong.

ADR 0148 §6's principle is extended, not overturned: the failure is still *a* door, and still the
primary one. `AudioUnavailableNotice` is unchanged. What changes is that it is no longer the only
one, because a class of wrong links produces no failure to hang a door on.

### 2. The door lives in the per-song inspector

`SongDetailsSheet` is reachable two ways, and both matter here. From the library it is the song's
long-press **Details**. From the practice screen it is a hold on the title — which puts the repair
one gesture from where a wrong track is actually *heard*, since the way you discover this problem is
by pressing play and not recognising the song.

It is not in `SongEditSheet`. That sheet is Cancel/Done over a local draft, and a replace is an
immediate, irreversible write to the container — putting it behind a **Done** that also means
"discard on Cancel" would promise an undo that does not exist.

### 3. The practice screen replaces through its own model, not through `SongRelinker`

`SongFileStore.adopt` deletes and rewrites the file at the song's path. When Details is opened from
the practice screen the engine has that exact file **open**, so the plain path would replace the
bytes under a live `AVAudioFile`.

`SongAudioSection` therefore takes its replace operation as an injected closure. The library passes
nothing and gets `SongRelinker.replace` — prepare off the main actor, apply on it. The practice
screen passes `WaveformPracticeModel.relinkAudio`, which already stops the engine and reloads around
the swap. One operation, two callers, and the caller that owns an engine is the one responsible for
quieting it.

### 4. A confirmation before, the length warning after

The picker is preceded by a confirmation naming what will happen and what survives — the action is
irreversible and now sits in a browsing surface where a stray tap is possible, which the failure
notice's dedicated button never was.

Afterwards, ADR 0148 §6's rule is reused unchanged: a duration differing by more than a second means
a different recording, so the player is told their loops may not line up, and **nothing is deleted**.
Worth noting the warning now fires in a case §6 did not anticipate — correcting a wrong link *back*
to the right track will usually trip it, and there the loops line up again. It is still the honest
thing to say: we know the length changed, we do not know which direction is the correction.

Unlike the practice screen, this surface confirms success explicitly. There the waveform redrawing
and the transport coming alive is the confirmation; here the sheet looks identical afterwards, and a
player correcting a mistake needs to know it took.

### 5. The file line describes, it does not name

The Audio row shows format and size, never a filename. The owned copy is stored under a
`sourceID`-keyed leaf (`SongFileStore.fileName`), so the name on disk is ours and not the one the
player would recognise — printing it would be a confident-looking lie. Format and size are true, and
are enough to tell two files apart when checking whether a link went astray. `SongAudioLabel` is
pure and pinned by tests across all three ADR 0148 custody states: an owned copy, a legacy in-place
bookmark, and neither.

### 6. A failed replace restores the state it found

`relinkAudio` previously set `audioLoadFailed = true` on any error, which was correct when it could
only be entered from a broken song. It can now be entered from a healthy one, and `prepare` throws
before anything is written — so a failed replace of a *playing* song would have dropped a blocking
"audio is missing" notice over a screen that was working perfectly. It now restores the failure
state it found rather than asserting one.

## Consequences

- A wrong link is correctable without losing loops, markers, takes or practice history.
- The `sourceID` invariant (ADR 0148 §4) is untouched — this is the same operation from a new door.
- One more surface can write a song's audio, so the "two decodes racing onto one `sourceID`" guard
  now has to exist in two places. Both hold it while a replace is in flight.
- `SongDetailsSheet` crossed SwiftLint's `type_body_length` cap; its row builders and derived text
  moved to a same-file extension, and the new section is its own file.

## Alternatives considered

**Leave it — tell people to delete and re-import.** Cheapest, and wrong. It trades the player's
accumulated work for our convenience, and does it at the moment they are already recovering from a
restore. §4 exists precisely so this is never the answer.

**Detect the wrong file instead of allowing a correction.** Tempting — compare duration, or hash the
file — but there is nothing to compare *against*. The song's stored duration came from the file it
is now being pointed away from, which in the restore case may itself have been wrong. And a "this
doesn't look like the same track" block would refuse legitimate relinks to a different encode, which
§6 explicitly allows. Warn, never refuse.

**An undo for the previous file.** Genuinely appealing, and rejected on cost: `adopt` deletes the old
copy, so an undo means keeping a second file per replaced song and a retention rule for it, to serve
a case the replace door already handles by pointing at the right file again.

**A library-row menu item instead of a details section.** Cheapest to build and the most
discoverable in the library, but it is not reachable from the practice screen, where the mistake is
heard — and a bare menu row shows nothing about what is currently attached.
