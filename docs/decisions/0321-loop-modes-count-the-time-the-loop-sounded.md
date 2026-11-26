# ADR 0321 — Active listening and Improvise count the time the loop sounded

- **Status:** Accepted. Built on `pocket-483-loop-modes-count-sounded-time` (2026-11-26) and checked
  on the simulator. Tomisin confirmed D1 the same day, sounded time rather than time with the app in
  front, taking the smaller number as the right trade. The device pass is owed.
- **Date:** 2026-11-26
- **Amends:** ADR 0117 — *Two surfaces stay unlogged*: standalone Active listening has logged since
  #259 (2026-08-18), which no ADR recorded, and so has standalone Improvise. Both now log the time the
  loop sounded (D1). The paragraph's objection, that *"however long the screen was open"* is not an
  honest length, stands, and is what D1 answers. Ear blocks still log on **Done**, for that length.
  ADR 0141 — **L7**: standalone is not unlogged. Its reason holds, now as a rule about the length:
  the screen being open is not one. ADR 0135 — the Slice 1 build note that the standalone
  `ImproviseSheet` writes no row: it does, for the time the bed sounded.
- **Relates to:** 0242 (the Metronome logs the time the click sounded; this is that rule for the
  loop) · 0104 (ear training) · 0050 (the screen is kept awake on these screens) · 0303 / 0304 (the
  lock screen and the background, where a playing loop goes on counting) · 0070 (never grades)
- **Schema:** none. The rows are the same shape; their `durationSeconds` now means time sounded.

## Context

Tomisin, 2026-11-26: *"If I go on active listening, play a loop, stop it, then leave the app, the
practice still logs even though I've left the app and nothing's playing."* Yesterday, and on Tuesday
of the week before, the Practice log's minutes were far too high.

The phone's store showed it exactly:

| Started | Kind | Logged | Ended |
|---|---|---|---|
| 25 Nov 20:59 | Active listening, *Chunk 3* | **755.8 min** | 26 Nov 09:35 |
| 17 Nov 16:34 | Improvise, *Chords* | **289.6 min** | 17 Nov 21:23 |
| 23 Nov 15:27 | Active listening block in a routine, *Chords* | 60.3 min | 23 Nov 16:27 |

…and older ones of 164.6, 156.0, 83.4 and 76.7 minutes. Every one is standalone Active listening or
Improvise, or one of their routine blocks. No other kind has one: the longest of anything else, in
471 rows, is a 35-minute ramp.

The cause is one line in `RampLessRunLog`: the clock started when the screen **appeared** and the
row was written when it **disappeared**. Leaving Red Moon doesn't make a screen disappear. A sheet
left open over a stopped loop stays open in the background, so when the app came back the next
morning and the sheet was closed, the whole night was logged as one run of listening. The routine
blocks had the same clock, so a routine came back to after an hour logged the hour.

That clock dates from when its premise held. ADR 0104's ear block played **from arrival**, so
arriving and listening were the same moment. The loop now waits for ▶, so they aren't. ADR 0117 and
ADR 0141 L7 had both refused to log these screens at all, because *"however long the screen was open
is not an honest length, and inventing one would put minutes in the log that nobody practised"*. #259
started logging them, rightly, because they are practice. But it timed them as the screen being
open, which is the length those two ADRs had ruled out, and no ADR recorded the change.

## Decisions

### D1 — The length is the time the loop sounded

A run of Active listening or Improvise lasts as long as audio was coming out on that visit:

- **counted:** the loop cycling, on screen or with the phone locked (the lock screen keeps it going,
  ADR 0303), and a slice of it playing for Name the notes, which plays through the same player.
- **not counted:** the loop stopped, the app in the background with nothing playing, the time before
  ▶ was first pressed, and the time after an interruption silenced it (D3).

A row starts when the loop **first** sounded and lasts for the total it sounded, with the stops left
out, exactly as a Metronome row is built (ADR 0242 D2). A visit that never pressed ▶ logs nothing.
`PracticeLogWriter.minimumSeconds` (one second) stays the floor. The Metronome's 30-second floor is
for tempo checks, and a loop has no equivalent.

**Rejected: time with the app in front.** Pausing the screen's clock while Red Moon is in the
background fixes the two nights above, and nothing else. These screens hold the phone awake (ADR 0050,
on by default) whether or not the loop is playing. So a stopped loop with the phone on a music stand
keeps counting until someone picks it up, which is the same bug without leaving the app. It would also
**stop** counting a loop played with the phone locked, which is real listening. **Rejected: time in
front or sounding.** It still has the awake-screen hole. **Rejected: capping a run.** Any number is
arbitrary, and a long jam is legitimate: the app never tells you to stop playing.

What D1 gives up is time on the screen with the loop stopped: reading what was saved, writing a note,
thinking between plays. It would be honest to count some of that, and impossible to tell it apart
from the phone lying on the stand. The log errs towards the smaller number. An over-count is worse
here, because the Practice log is what Tomisin reads to see where practice went and to adjust the
goals, and a padded figure makes any gap look smaller.

### D2 — The player counts; the screen decides it was practice

`ContinuousLoopPlayer` keeps the count (`SoundedTime`) because the start and stop happen there,
synchronously. That includes a stop from the lock screen while Red Moon is in the background, where a
view's `onChange` may not run until the app comes back. Counting it there would bring the bug back.
The player brings the count up to date after every change to what it is playing, so the count is
derived from its own state. No call site has to remember to start or stop it.

The **write** stays on the screen, as ADR 0242 D3 put the Metronome's. The same player plays *Watch it
on the neck*, which is not practice, and only the host knows whether it is a standalone visit, which
logs when it closes, or a routine block, which logs on **Done** or at its planned length, while skip
and exit log nothing. `SoundedTime` is pure, so its rules are unit-tested: a silence isn't counted,
stretches add up, a run is handed back once, and a visit that never played logs nothing.

### D3 — An interruption stops the count

A call, Siri, or another app's audio stops Red Moon's audio. The session is `.playback`, which doesn't
mix with other audio. Nothing restarts the engine afterwards, and the player isn't told, so its ■ stays
lit over silence. Counting `isPlaying` alone would count a loop nobody can hear, for as long as the
player stays away. That is the reported bug again, by another door: start a loop, open another app's
video. So an interruption beginning (`AudioInterruption.began`, the rule a take already ends on) stops
the count until the loop is stopped or started again.

The ■ over silence is not fixed here. It is older than this ADR and it is a transport question.

### D4 — Routine blocks log the same length

An Active listening or Improvise block logs the time its loop sounded, on **Done** or at its planned
length, as before. The block's **planned length is unchanged**: its countdown still runs from arrival
(ADR 0141), so a routine left in the background still moves on when it comes back. It now logs only
what sounded.

### D5 — The rows already written stay as they are

The log is append-only (ADR 0117) and has no edit, and the true length of a past run can't be
recovered: nothing recorded what sounded. The 755- and 290-minute rows stay. Whether to trim or remove
runs like them is **not decided here**.

## Consequences

- **Practice log minutes for Active listening and Improvise go down**, from this build on. Some of
  that is the bug going, and some is D1's trade.
- **The Practice log shows what was heard.** The manual says so beside the Metronome's line.
- **Watch it on the neck**, opened from Active listening, plays on a player of its own and isn't
  counted. It isn't counted anywhere else either.
- **The freeform block and a looping play-along** are timed from arrival and from **Play along** to
  **Done**, so a routine left in the background has the same hole there in principle. Neither shows it
  in the phone's 471 rows, and both need a different answer: a freeform block has no audio to count.
  Not changed here.
