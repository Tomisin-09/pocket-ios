# ADR 0192 — one transport grammar: the skip is clamped to what is playing

- **Status:** Accepted
- **Date:** 2026-09-06 (`pocket-300-transport-unification`)
- **Relates to:** **reunifies ADR 0030** (the rewind · pause · forward cluster, whose restart /
  previous-loop / next-loop mapping is withdrawn) and **ADR 0124 D1** (the timed skip, whose scope
  this widens from *idle only* to *always*). Constrained by ADR 0008 (the crossfaded loop buffer)
  and ADR 0041 (a seek inside an armed loop resumes from that point). Leaves ADR 0124 D2
  (`canRepeatSong`) untouched. Picked up from `docs/directions-2026-09.md` §5c / §6 Tier 1.
- **Schema:** none. No model, no persisted key — `AppSettings.Key.transportSkipSeconds` is unchanged
  and keeps whatever the player already chose.

## Context

The two outer transport buttons have meant two different things depending on a state the player set
several gestures ago.

With **no loop armed** they are timed skips: −N / +N seconds, clamped to the song, the increment
picked from a hold menu (ADR 0124 D1). With a **loop armed** they are loop navigation: rewind
restarts the loop, a double-tap on rewind steps to the previous loop, forward steps to the next one
(ADR 0030). Same two glyphs, same two pixels, two grammars.

ADR 0124's own argument is what settles it. It gave up rewind-to-restart in the idle state because
*"moving freely inside the waveform beats a one-tap restart you can also get by tapping the start of
the wave"* — and that is **more** true inside a loop, not less. A player working a four-bar phrase
does not want to be sent to the top of it, and does not want to be thrown into the *next* loop; the
move they make constantly is *nudge back four seconds and catch the entry again*. Until now that
move existed everywhere except the one place the work happens.

The double-tap made it worse than a missing feature. A second tap on rewind, which is what an
impatient player does when the first one didn't go back far enough, **left the loop they were
working**. The two gestures are a stacked `onTapGesture(count:)` pair, so the disambiguation delay
also sat on every single tap.

⚠ **The constraint that forces the design.** An armed loop does not play the file; it plays a
pre-rendered, equal-power-crossfaded PCM buffer of the region on `.loops`
(`PracticeAudioEngine+LoopBuffer.swift`, ADR 0008). So *skip past the loop end* is not a seek that
happens to land outside — it is a **disarm**, a rebuild and a different thing playing.

## Decisions

### D1 — Both buttons are timed skips, in both states

The outer glyphs are `gobackward.N` / `goforward.N` whether or not a loop is armed, holding either
to change the increment. One gesture, one meaning: **move ±N seconds through whatever is playing.**

Nothing else about the two transport states changes — the flanking identity controls still morph
(big idle circles ⇄ the compact stacked column and the loop's colour strip), the header still reads
the loop's name, and `repeat` is still disabled while a loop is armed (ADR 0124 D2). The bar still
*says* a loop is running. It just no longer changes what the buttons do.

### D2 — The scope is the armed region, not the song

`TransportSkip.target(from:by:within:)` takes a `ClosedRange` instead of a duration, and
`TransportSkip.bounds(loopRegion:duration:)` resolves that range: **the armed loop region if there
is one, else the whole song.** Both are pure and unit-tested; the model reads the bounds off the
**engine's** `loopRegion` rather than off `activeLoop`, so an unsaved A/B span (ADR 0041) — which is
just as much "what is playing" — scopes the buttons the same way a saved loop does.

So a skip near the loop end lands **on** the loop end and keeps looping, the same way a skip near
the song end lands on the song end. Overrunning is clamped, exactly as it always was; only the
bound moved.

Two degenerate cases fall back to the song rather than trapping the playhead: an empty or inverted
region, and a region that outlives the audio it was measured against. The alternative is a transport
whose buttons appear live and do nothing.

**Rejected: letting a skip past the edge disarm the loop.** It is surprising — nothing else in the
app disarms a loop as a side effect of moving — and it destroys the intent the player expressed by
arming it. If they want out, the ✕ on the colour strip is right there and says so.

**Rejected: keeping the loop grammar and adding a modifier** (a long-press to skip, a third button).
The bar has no room, and it would answer "the buttons mean two things" with three.

### D3 — What is deleted, and where the withdrawn behaviour lives

This is a **net deletion**: `TransportNav` (and its test file), `transportPrevious`,
`transportNext`, `hasPreviousTarget`, `hasNextTarget`, the private `jump(to:)`, `transportRestart`,
the `RewindButton` component with its stacked-tap disambiguation, `TransportGlyph`'s disabled
variant, and five parameters off `TransportBar`.

Nothing has to move to replace them, because each already had a home:

- **Loop → loop** is the Loops panel, where loops live. `activate(_ loop:)` is documented as *"Tap a
  loop row: make it the active looping region, seek to start + play"*, and it carries the ADR 0089
  arming-speed rule that `jump(to:)` duplicated. One insert path, not two.
- **Restart the loop** is a tap on the region's start on the waveform, or the loop's row — the same
  answer ADR 0124 already gave for restarting the song. A seek inside an armed loop resumes from
  that point without a rebuild (ADR 0041), so this is a cheap gesture, not a workaround.
- **Previous / next song** never existed. ADR 0030 dimmed those affordances pending cross-song
  navigation; ADR 0124 withdrew the idle half. This withdraws the rest, so the app no longer ships a
  disabled control for a feature no ADR has since proposed.

`TransportGlyph` now has no disabled state at all, which is the honest consequence: **every glyph in
the row is live in both states.**

## Consequences

- The gesture the player makes most often inside a loop now exists, and the one that used to throw
  them out of it is gone.
- The transport is documented in `docs/manual/reference/song-player.md` — whose transport section
  described the *idle* buttons and is now simply true — and in `docs/manual/looping.md`, whose
  "Running a loop" paragraph described the withdrawn mapping and is rewritten. `check-manual.py`'s
  C9 quotes (`Back 10 seconds`, `Forward 10 seconds`) are unchanged: those labels already existed
  and now apply in both states.
- VoiceOver loses the "Previous loop" custom action and gains nothing, because the skip buttons
  already carry their amount in their label (*Back 10 seconds*).
- **Not covered:** the lock-screen transport. ADR 0025 scoped it to play/pause because there was
  "nothing to skip to"; there is now — a ±N second skip is exactly what `MPRemoteCommandCenter`'s
  skip-forward/backward commands are for, and `NowPlayingController` explicitly disables them.
  `docs/directions-2026-09.md` §5d.2 already wants one of those slots for *mark a moment*. Left
  alone here deliberately: this ADR does not add a surface, it removes a grammar.
