# ADR 0220 — a song that arrives signposted

- **Status:** Accepted — **all three build steps built** (2026-09-25). Step 1
  (`pocket-326-the-song-knows-itself`): the song arrives with its tempo, downbeat, grid lines and two
  markers. Step 2 (`pocket-327-beat-one-scripted`): beat 1 scripted on the starter track, the rest of
  0149's beats and its one ceremony — the choices the build made are under *Step 2 as built*. Step 3
  (`pocket-328-the-two-hints`): the click and backing-track hints (D4), under *Step 3 as built*,
  which also settles where the backing-track hint points.
- **Date:** 2026-09-24 (`pocket-325-a-song-that-arrives-signposted`)
- **Amends:** ADR 0219 — D1's "no loops **and no markers**" loses its second half. The starter track
  arrives with two markers, a measured tempo and downbeat, and grid lines on (D1–D2). The first
  half stands: it still arrives with **no loops**, for exactly the reason D1 gave. `StarterTrack.bpm`
  was wrong (104), and so is `ScreenshotSeed`'s Binta entry, which D1 mirrored; both become 83.
- **Amends:** ADR 0149 — the 2026-08-11 amendment's "**Markers are deliberately out**" now covers
  markers as a *beat*, not markers as scenery (D2). Its three beats stand. On the starter track only,
  beat 1 runs as a scripted pause-at-marker (D3), and two hints join the first session without
  becoming beats (D4). §2's trigger, §4's experience branch and §5's single ceremony are untouched.
- **Relates to:** ADR 0021 (snap to markers — which a play-along tap does **not** get, D3),
  ADR 0022 / ADR 0154 (the beat grid and its anchors), ADR 0026 / ADR 0027 (the in-song click),
  ADR 0041 (play-along A/B), ADR 0135 (backing tracks), ADR 0153 (the playhead may not be read in a
  body)
- **Schema:** none. Everything here is values written at adoption, onto attributes that already
  exist (`Song.bpm`, `preciseBPM`, `downbeatSeconds`, `showsGridlines`, `Marker`).

---

## Context

ADR 0219 got a song past the paywall. What the player finds when they open it is a bare waveform:
no markers, no tempo, a greyed-out metronome, and a Loop button whose job they have to guess.

The walkthrough ADR 0149 describes has not been built. So the question for its first build is not
only "what are the beats" but "what should the song already know when the beats start". This ADR
answers that for the one song we control completely.

Three observations drive it:

**The best loop in Binta is already known.** The author's own Chords loop, pulled off their phone
on 2026-09-24, runs 23.168 s → 34.731 s: exactly four bars (bars 9–12) at 83 BPM, 16 beats. A first
loop that lands on those bars is a better demonstration than one that lands wherever a new player's
thumb happened to fall.

**A play-along tap does not snap.** `tapAB()` sets A and B at the raw playhead. Snapping (ADR 0021)
happens on the *release* of a gesture: a hold-drag, a handle, a tap-seek. A player tapping Loop by
ear lands 150–250 ms late, which on Binta cuts into the bar-9 kick.

**The grid and the click need a tempo and a downbeat, and a new player cannot set either.** Tapping
a tempo and placing the 1 are skills the Set tempo sheet assumes. Without them the metronome is
unavailable (`canUseMetronome` is `!beatGrid.isEmpty`) and the Grid button has nothing to draw.

## Decision

### 1. The song arrives with its tempo and downbeat measured

| | Value | Why |
|---|---|---|
| `bpm` / `preciseBPM` | **83** / **83.0** | The author's figure. The click holds to the end of the song by ear on device |
| `downbeatSeconds` | **0.027** | Measured, below. Displays as `0:00` |
| Time signature | 4/4 | |
| Extra downbeat anchors | none | Not needed: the click holds to the end |
| `showsGridlines` | **on** | The grid is part of the demonstration, not a setting to find |

**How the downbeat was measured.** Binta opens on about two seconds of drums alone, so the kick is
the only low-frequency event and its onsets are unambiguous. Decoding the bundled `Binta.m4a` and
reading onsets in that window, a kick-band filter and the full band agree to within 2 ms:

| Hit starts | At 83 BPM from 0 |
|---|---|
| **27 ms** | bar 1, beat 1 |
| 1,113 ms | beat 2½ |
| **1,476 ms** | beat 3 |
| 1,658 ms | beat 3¼ |
| 2,744 ms | beat 4¾ |
| **2,925 ms** | bar 2, beat 1 |

Every hit sits the same ~0.04 beats after its grid position, so the grid is right and its origin is
27 ms late. That fixed offset is also why the author's hand-made loop sat ~33 ms after both bar
lines. With the downbeat at 0.027 s it lands within 8 ms of bar 9 and 5 ms of bar 13.

> **A measurement that was wrong first, recorded so it is not repeated.** An earlier pass measured
> every bar line of the whole song through a 120 Hz low-pass and reported three shifted sections and
> a tempo of 82.87. Past bar 8 the bass shares that band, and the detector was reading bass notes as
> kicks. **Calibrate on a passage where the thing being measured plays alone**, then check the
> result by ear on the device, which is what caught it.

### 2. Two markers, and still no loop

| Label | Seconds | Where |
|---|---|---|
| **Chords start** | **23.160** | bar 9, beat 1 |
| **Solo start** | **34.726** | bar 13, beat 1 |

Both are `0.027 + (bar − 1) × 4 × 60/83`, so they sit on the grid rather than beside it. The loop
edges, the bar lines and the click then agree on every point the player can see or hear.

ADR 0219 D1 refused markers along with loops, and ADR 0149's amendment kept markers out of the
beats. Neither reason reaches this:

- **0219 D1's reason was about loops**: "a song that arrived pre-looped would answer the question the
  walkthrough exists to ask". A marker does not answer it. The player still makes the loop, with
  their own two taps, and owns it afterwards.
- **0149 left markers out as something to teach.** These are not taught. Nobody is asked to drop one.
  They are scenery: signposts on a song someone else prepared, which is what a teacher's copy of a
  track looks like.

Label text follows the app's own auto-names ("Marker 1"): sentence case, no punctuation. Both are
ordinary markers: renameable, deletable, and nothing afterwards depends on them (D5).

### 3. On the starter track, beat 1 pauses at the markers

ADR 0149's first beat is *"tap Loop at the start of a passage, tap Loop again at the end"*. On the
starter track it runs like this:

1. Playback starts two bars early, at bar 7 (**17.376 s**), so the section is heard arriving.
2. When the playhead reaches **Chords start**, playback pauses and the playhead is set exactly onto
   the marker. One hint points at Loop.
3. The player taps Loop. A lands on the marker because the playhead is on it. `tapAB()` already
   resumes playback on the armed tap.
4. At **Solo start** playback pauses again, and the hint says to close the loop.
5. The player taps Loop. B lands on the marker, and the four bars start looping straight away. This
   is unchanged from today.

**The pause is the app saying "here". The tap is still the player's**, on the button they will use
from then on. That meets 0149 §1: nothing advances on a Next button.

**The watcher lives in the model, never in a view body.** ADR 0153: a body that reads the playhead
invalidates at 120 Hz. At that rate it can overshoot the marker by up to ~16 ms, which is why step 2
seeks back to the marker exactly instead of pausing where the playhead happens to be.

**This is a walkthrough behaviour, not a feature.** Nothing outside the scripted beat pauses at a
marker.

**What it does not fix.** The pause teaches the tap-tap motion in slow motion. Once the walkthrough
ends, a play-along tap still lands wherever reaction time puts it. The general fix is to snap a
play-along tap *back* onto a marker it has just passed. That changes ADR 0041's behaviour everywhere,
so it is **not decided here** and is recorded as the obvious next question.

### 4. Two hints join the first session, and neither is a beat

0149 §5 warns against a theme-park ride, and its amendment cut five steps to three. The three beats
stay: **Loop it, Slow it down, Keep it.** Two things are added *beside* them, as hints:

| Hint | When | Points at | Ends when |
|---|---|---|---|
| **The click** | Once beat 1's loop is playing | The metronome in the speed bar | Tapped, or dismissed |
| **Backing track** | After beat 3's ceremony | The Backing track toggle on the saved loop | Used, or dismissed |

A hint differs from a beat in three ways. **It never gates anything**: the next beat is reachable
whether or not it is taken. **It is shown once.** And it cannot make the ceremony happen: that stays
on beat 3 (0149 §5).

**The grid gets no hint.** Its lines are on when the song opens (D1), which is the demonstration:
the player sees the bars before anything points at them, and watches their loop close onto two of
them.

**Why the backing-track hint is in the first session.** Four bars of chords is the most natural bed
in the song, and the toggle's own help text asks for "a whole number of bars". The loop the player
has just made is exactly that. Note what the flag does: **Improvise is already offered on every
loop** (`LoopEditSheet+Fields.swift`, ADR 0135 B2). The flag controls where the loop *reappears*:
the Backing tracks filter, and an Improvise button on its row. So the hint says "keep this somewhere
you will find it", not "unlock this".

### 5. The positions are constants, not lookups

`StarterTrack` gains the two marker positions and the bar-7 lead-in as constants beside `sourceID`.
The walkthrough reads the **constants**, never the `Marker` records.

Markers are the player's once they arrive. A player who renames or deletes one before the walkthrough
reaches it must not break it, and a player who later drags one must not have their song's scenery
re-read as instructions. The records exist to be seen; the constants drive the script.

### 6. Only the starter track is scripted

ADR 0149 §2 fires the walkthrough on the first successful import, which can be the starter track or
the player's own song. D1–D5 apply only to the starter track, because only there do we know where
the good four bars are. **A player whose first song is their own gets 0149's beats unscripted**:
tap Loop by ear, no pauses, no preset markers. §4's experience branch applies in both cases.

### 7. It is applied at adoption, with no back-fill

The values are written by `SongImporter.prepareStarterTrack()` when the song is adopted, beside
the metadata it already writes. ADR 0219 merged on 2026-09-22, after 1.3 (7) was cut on 2026-09-10,
so no App Store player owns a bare Binta. A development or TestFlight install that adopted it before
this ships keeps it bare, and removing and re-adopting the song fixes it. A migration for a handful
of test devices would cost more than it saves.

## Build order

1. **The song knows itself.** D1, D2, D5, D7: constants, the adoption writes, `bpm` 104 → 83 in
   `StarterTrack` and `ScreenshotSeed`. Pure values, unit-tested against the arithmetic in D2.
2. **Beat 1, scripted.** D3 and D6: the marker watcher, the pause, the seek-back, the two hints on
   Loop. The rest of 0149's beats and the ceremony land here too, since none of them are built.
3. **The two hints.** D4.

Figures are reshot once, after slice 3, not per slice.

## Step 2 as built (2026-09-24)

ADR 0149 said what the beats are and left how they behave at the edges to the build. These are the
answers it gave, recorded here because each one closes off an alternative.

**The beats complete in any order.** A beat ticks on the action, never on a button (0149 §1), and
the card shows whichever beat is first still outstanding. The alternative — each beat only counting
once it is current — asks a player who saved the span before slowing it to make a second loop to
satisfy the card. A saved loop also ticks *Loop it*: however it was made, it is a loop.

**The ceremony lands on the first loop kept, even with *Slow it down* outstanding** (0149 §5 puts
it on beat 3, and that is when beat 3 happened). Closing it returns the card to the beat still
owed. Its latch is separate from the walkthrough's, so a re-entry from Help ticks silently.

**Any player-driven step below full speed is *Slow it down* done.** The copy suggests "about half"
with the musician's discretion attached; a tick that demanded 0.5× would be a grade (ADR 0070).
Only the player's hand counts — arming a loop at its own tempo is the app setting the speed.

**0149 §4's "substantial experience" is the intake's top two answers**: *Comfortable, want to level
up* and *Been playing a while*. They are offered the walkthrough — one card, *Show me* or *Not now*
— and everyone else, including anyone who skipped the question, gets it started.

**Armed at the one import choke point, spent when it appears.** `SongImporter.persist` arms it,
because every import passes through it, the starter track included (0219 D3). An import into a
library that already held audio spends it instead, so a player upgrading into this is never walked
through an app they already use. It is spent when the card appears — once the song's audio has
loaded — rather than when the visit ends: a crash or a force-quit is the walk-away §4 describes, and
a song that never loaded spends nothing. The only way back is **Show the first-song guide again**,
last in Help & FAQs' *Getting started* (§4, §6). No schema: two `UserDefaults` keys.

**The watcher.** `PracticeAudioEngine.onTick` hands the playhead to the model once per display
frame; the pure `StarterTrackScript` decides, and the model pauses and seeks back onto the constant
(D3, D5). Nothing observable is written on a frame unless the script's stage moved, so the card
redraws a handful of times a walkthrough, not at 120 Hz (ADR 0153). A stop trips only on playback
that runs *through* it — a jump of more than half a second is a seek or a skip, not playing — and
not on a playhead already sitting on it, so resuming from the marker does not stop there again.
Rewinding before *Chords start* without tapping Loop lets it stop there once more.

**The lead-in places the playhead; it does not press play.** D3 step 1 starts playback two bars
early. The walkthrough puts the playhead on bar 7 and the card says *Press play*: audio that starts
itself on a screen the player has just opened, possibly somewhere quiet, is not ours to decide.

**The hint that points at Loop is a ring on the button**, breathing unless Reduce Motion is on, and
drawn outside the button so it cannot take the tap it asks for. VoiceOver announces the card's
instruction at each pause. In landscape the card shows only the current beat, inline in the
cockpit, because the reference list it sits above in portrait is a closed drawer there.

**Each beat's single link (0149 §6) opens one Help answer.** Two were written for it: *Why loop one
part of a song?* and *What happens to a loop I save?*; *Slow it down* points at the existing pitch
answer. A test pins that every linked question is in the catalog.

**Not built: 0149 §8's activation measure.** The analytics consent prompt arrives after a first
practice (ADR 0120, 0147), so nothing that happens during the walkthrough is observable, and
`loop_created` already exists. No event was added for a moment the pipeline cannot see.

**Under test** the walkthrough is off unless a test asks for it with `-walkthrough`: it would sit
over every control the suite drives, and over every figure the manual shoots on the player.

## Step 3 as built (2026-09-25)

D4 said what the two hints are. These are the answers the build gave, each of which closes off an
alternative.

**The hints are their own pure type, `StarterTrackHints`, beside the script and not inside
`SongWalkthrough`.** That keeps D4's first rule structural: nothing the beats decide reads a hint, so
a hint cannot gate one. It lives exactly as long as the walkthrough's visit, which has to change in
one place: the walkthrough used to end the moment its last beat ticked, and the backing-track hint
arrives *after* that. It now ends when no beat is outstanding **and** no hint is showing.

**Starter track only.** D6 scopes D1–D5 to the starter track, and D4 is inside that. Both hints also
depend on things only it guarantees: a grid from the first note, and four bars of chords.

**The backing-track hint is offered only when the loop kept is the scripted span**, *Chords start* to
*Solo start* within 50 ms. It says "four bars of chords make a good bed", and that is only true of that
loop. The script seeks onto each stop, so a scripted loop lands within a millisecond, and a handle
dropped on a marker snaps there exactly. A tap by ear, 150–250 ms late (D3), does not qualify. A
player who loops something else is not told it makes a good bed.

**The click hint arrives with the span, not with the loop saved.** "Once beat 1's loop is playing"
is the moment the second Loop tap closes the span, because the span repeats straight away. It is not
offered when the click is already on (there is nothing to point at). It is not offered when there is
no grid either: the hint points at a click that exists, never at a tempo to set, which is the skill
D1 says a new player lacks.

**One hint at a time.** Keeping the loop offers the backing-track hint, which replaces a click hint
still showing, and that click hint is spent. It has had two beats to be noticed. Showing both would put
two pointers on one screen, the ride 0149 §5 warns against.

**Shown once means once per run.** A hint that is taken, dismissed or replaced does not come back on
that visit. It is not latched per install the way the ceremony is (0149 §5's "exactly once" is about
the moment). A player who asks for the guide again from Help gets the hints again, because that is
what they asked for.

**Neither hint shows during the ceremony.** The ceremony card replaces the beats and the hint rows,
and the rings go with them. The moment belongs to the player, and a pointer pulsing somewhere else
would talk over it. The backing-track hint appears when the ceremony closes. On a re-entry, where the
ceremony has already been seen, it appears as soon as the loop is kept.

**How a hint looks.** Each hint is the same ring as beat 1's on Loop, now shared as `HintRing`, plus
one row on the card. The ring on the metronome is teal and round. The ring on the kept loop's row is
a rounded rectangle in the loop's own colour, and goes round the part that takes the hold, not the
adjust pair beside it. The card row sits under the beats behind a divider. Its badge is the glyph of
what it points at rather than a number, and its title is in the accent. Two bold white titles on one
card read as two steps; the simulator showed that before the tint went in. The row has its own ✕,
separate from the card's ✕, which still ends the whole guide. Once the beats are done a hint can be
the whole card, and then the card's ✕ is the hint's. VoiceOver announces each hint when it appears.

**Where the backing-track hint points: both places** (decided 2026-09-25 from simulator screenshots,
as the Consequences below asked). A hold is the only way into Edit loop, so the card says *"Hold Loop
1 and turn on Backing track"* and the row carries the ring. Inside the sheet, Edit loop opens
scrolled to the toggle and rings it until it is switched on. At the sheet's medium detent the toggle
sits four sections below the fold, so without that half a new player would hold, find Name and
Range, and have to go looking. The Loops panel is expanded when the hint is offered, since a ring on
a row inside a folded panel points at nothing.

**What ends each hint.** The click hint ends when the click is switched on, from the hint or not. The
backing-track hint ends when the loop is a backing track once Edit loop closes. The flag is written
only on Done, so the model reads the loop after the sheet has gone rather than watching the toggle,
and Cancel does not count. Deleting the kept loop also ends it, at the delete and not when the delete
commits, because the row disappears straight away. **Improvise does not end it**: it runs on any loop
without setting the flag, and the flag is what the hint is about.

## Consequences

- **The starter track's first loop is the same for everyone.** That is the intent: every player's
  first loop is four good bars on the grid. It does mean the first loop teaches the *gesture* rather
  than the *judgement* of where a section starts. That judgement is the method's job (0149's
  amendment moved it to the website), and a player's own songs will ask it of them soon enough.
- **`StarterTrack.bpm` was wrong since 0219 shipped to `main`,** and `ScreenshotSeed` with it. Any
  manual figure showing Binta's tempo as 104 is stale. It is added to the list for the reshoot after
  slice 3.
- **Nothing here verifies that the downbeat stays right if the audio is re-encoded.** ADR 0219 D8
  re-encoded Binta to 128 kbps, and these figures were measured on that file. Any future change to
  the resource has to repeat the D1 measurement, and `StarterTrackTests` records why.
- **The play-along snap question is open (D3).** If first-session analytics show players who finish
  the walkthrough then make ragged loops on their own songs, that is the ADR to write.
- **Where the backing-track hint points was decided from screenshots:** both places. See *Step 3 as
  built*. The toggle is one **hold** past the loop's row, not one tap as this line first said.
- **The reshoot this ADR deferred is now owed.** With step 3 built, the figures that show Binta's
  tempo, `toolkit/faq` (the guide row and two new answers), and any figure of the walkthrough are
  taken once, together. The shoot has to pass `-walkthrough` to show the card at all.
