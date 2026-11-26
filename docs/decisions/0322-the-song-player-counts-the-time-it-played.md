# ADR 0322 — The song player counts the time it played

- **Status:** Accepted. Built on `pocket-484-song-player-counts-its-time` (2026-11-26) and driven on
  the simulator (Build notes). Tomisin agreed D1–D5 the same day. The device pass is owed.
- **Date:** 2026-11-26
- **Amends:** ADR 0241 — **D3** named the song library among the parts of the app the log *"has no
  rows for … and was never meant to"*. The song player now writes rows: runs of what was played, for
  the time its audio sounded (D1), not a part of the app being open. D3's refusal to time screens
  stands, and the new rows are named for what was played (D3, D4 here), never "Song player".
- **Amends:** ADR 0242 — *What stays out* kept *"the tuner and the song library. Still not practice,
  and still not timed"*. The song player is now timed by what sounded; the tuner and the library's
  list of songs stay out.
- **Relates to:** 0321 (the loop modes log the time the loop sounded: the rule applied here) · 0242
  D3/D4/D6 (the screen logs, never the shared engine; the 30-second floor; no tempo when the tempo
  moves under you) · 0137 D2a (any run on a unit makes it recent) · 0267 (Jump back in reopens a loop
  in the mode its run names) · 0298 D2 (a goal counts a loop in the mode it would run it in) · 0295
  (By song) · 0239 (Red Moon counts nothing about how the app is used) · 0070 (never grades) · 0029 /
  0041 (the song player's session state; the A/B span)
- **Schema:** none. `songPlayerLoop` and `exploring` are new values of `PracticeRun.kindRaw`, a
  `String`, not new columns.

## Context

Tomisin, 2026-11-26: *"I'm thinking about logging time in the practice log for the song player,
listening and creating loops."*

The song player wrote nothing to the log. Practice there, looping a passage at a slower speed or
running a ramp on the automator sheet, counted only if it was started from Practice instead, where
the loop trainer logs it. Learning a song by ear, which is how Tomisin learns outside a routine
(transcribing *Frontin'*, the open-mic covers), left no trace at all.

ADR 0241 D3 and ADR 0242 kept it out for want of an honest length: the screen being open is not one,
and timing it is the usage counting ADR 0239 removed. ADR 0321 has since given the loop modes one, the
time the audio sounded, and the song player plays audio, so it has the same length available.

That left whether it is practice. Asked how the song player is used, Tomisin: *"I tend to cycle
between loops, I hardly ever play the song through."* The first proposal counted only a loop being
played and left loop-making out as preparation. Tomisin: *"I'd still want to count the time creating
the loops… this isn't practice per se but it's still exploration/experimenting, I wouldn't want the
time dedicated to this to be lost."*

## Decisions

### D1 — The song player logs the time its audio sounded

ADR 0321 D1's rule, on the song player:

- **counted:** the song or a loop coming out of the speaker or headphones, on screen or with the phone
  locked (ADR 0303 keeps it playing).
- **not counted:** paused or stopped, before ▶ was first pressed, after an interruption silenced it
  (ADR 0321 D3), and while *Practice now* has the loop trainer open or a nested sheet plays its own
  audio. Both pause the song player first, and the trainer logs its own run.

The visit's runs are written as the screen closes (`endPlaybackSession`). A visit that never played
anything writes nothing. An app closed from the app switcher runs no seam and writes nothing, as for
the Metronome (ADR 0242, *What stays out*).

Time on the screen with nothing playing is not counted: thinking between plays, dragging a loop's
handles over silence. It would be honest to count some of it and impossible to tell it from the phone
on a music stand, the trade ADR 0321 D1 made for the same reason.

### D2 — Split by what was sounding: a loop being played, or Exploring

At every moment the song player sounds, it is one of two things:

- **A loop being played**: a saved loop armed and cycling, with no A/B span open.
- **Exploring**: everything else. The song playing through, an A/B span being set or adjusted (making
  a loop, or changing one's range, which lifts it into a span), and a loop heard too briefly to be a
  run of its own.

A visit writes **one row per loop played** for at least 30 seconds, on that loop, from when it first
sounded, for the total it sounded. **Everything else is one Exploring row**, on the song. The floor is
the loop's **total on the visit**, not each stretch: cycling back to a loop adds to it.

**A loop under 30 seconds goes to Exploring**, not into the bin. Saving an A/B span plays the new loop
at once (`createLoop`), and a few passes to hear where it starts and ends are part of making it. That
time is kept, which is the point of Tomisin's correction, and it isn't a run of the loop.

**An Exploring row under 30 seconds is dropped.** The song player is also where you go to check what
a song sounds like, and a quick listen must not mark the day as practised: the Metronome's floor, for
the Metronome's reason (ADR 0242 D4).

**Rejected: only a loop being played counts.** The first proposal. Nothing ambiguous would get in,
but the time spent making loops, which Tomisin wants kept, would be lost.

### D3 — A loop on the song player is its own kind, listed with Loops

The row's kind is **`songPlayerLoop`**, labelled **Loop**, and *What you played* lists it under
**Loops** with the trainer's runs (`PracticeRunKind.listedAs`): one row per loop, wherever it was
played. It carries the loop's `uid`, so the planner sees the loop as practised (ADR 0137 D2a).

**Rejected: a `.loop` row.** It would be the trainer's kind, and two readers act on that:

- **Home's *Jump back in*** reopens the newest loop run in the mode its kind names (ADR 0267). A `.loop`
  row names the trainer, so a player who had just looped on the song player would be offered the loop
  in the trainer, which is the plan's (ADR 0256 D3): a free player would meet a locked card. The song
  player is reopened through the song, which it stamps on arrival (ADR 0044), as before.
- **A goal counts a loop in the mode it would run it in** (ADR 0298 D2). A skill goal that claims a
  loop to train it counts trainer runs on it, not this. A goal whose target is the song counts it, as
  it counts everything *By song* puts under that song. That is the smaller number, which ADR 0321 D1
  prefers for a log read to adjust goals. Whether song-player looping should count toward a skill goal
  through the loop is **not decided here**.

**No tempo.** The speed moves while you play, by hand or by the ramp, so no one number is the speed
it was played at: ADR 0242 D6's reason. And the trainer's row records the loop's *command*, the speed
it is owned at; the slider's last position in the same field would mean something else. Nothing reads
a loop row's tempo today (`TempoTrajectory` and `TempoRecord` read exercises only).

### D4 — Exploring counts like any other kind

**`exploring`**, labelled **Exploring**, Tomisin's word. It counts everywhere the log counts: minutes,
the week and month, *This week* on Home, the month grid, all-time, and the review prompt's sittings. A
day of only exploring is a practised day (Tomisin, the same day). Its own group in *What you played*,
opening onto songs. *By song*, it sits under its song. *By goal*, a goal whose target is that song
counts it.

**It names its song and no unit**, so it makes no loop less due in the planner, not even the loop just
made: making a loop is not practising it.

### D5 — The model counts, not the engine and not the view

`PracticeAudioEngine` plays the song player, the loop trainer and the song play-along, and the last
two log their own runs, so a count in the engine would log them twice: ADR 0242 D3. A view's
`onChange` may not run until the app comes back from the background, so a pause from the lock screen
would be counted until then: ADR 0321 D2.

So the engine gains one hook, `onPlayingChange`, fired as `isPlaying` flips, which only the song
player sets. `WaveformPracticeModel` tells a pure `SongPlayerTime` what is sounding after every change
that could move it: the transport, the armed loop, the A/B span, an interruption. `SongPlayerTime`
keeps the rules and is unit-tested: what counts as sounding, a loop's run, the floor and where the
time under it goes, a silence left out, a visit logged once.

## What stays out

- **The song library's list, and the tuner.** Still not practice and still not timed.
- **Time on the song player with nothing playing** (D1).
- **A song-player loop toward a skill goal's claim on it** (D3). Not decided here.
- **A tempo on either row** (D3).
- **Backfill.** Nothing was recorded, so there is nothing to recover.

## Consequences

- **The Practice log's minutes and days go up** for anyone who uses the song player, from this build
  on. *What you played* gains an **Exploring** group, and a loop's row under **Loops** includes its
  song-player time.
- **An older build** (a TestFlight build switched back) reads both kinds as *other*: listed as *From a
  newer version of Red Moon*, minutes counted (ADR 0242 D8). An archive from this build restores into
  an older one the same way.
- **The review prompt** (ADR 0214) can come sooner for a player who mostly explores, since an
  Exploring row makes a sitting like any other run.
- **The Oracle's span lines** count a song-player loop run among the runs at that width (ADR 0187 D22).
- **`PracticeAudioEngine.swift`** was at SwiftLint's 400 lines, so `heard(_:)` and its DEBUG toggle
  moved, unchanged, to `PracticeAudioEngine+Latency.swift` to make room for the hook.
- **The manual** says what the song player counts (`looping.md`) and lists Exploring
  (`journal-and-practice-log.md`).
- **The figures:** the shoot's history seed has no rows of either kind, so the Practice log figures in
  the owed reshoot show no Exploring group unless the seed gains one. Not done here.

## Build notes

Driven on the simulator (iPhone 17, iOS 26.5) with a throwaway UI test on the naming seed's song,
since deleted. It played the song, set A and B, let the span cycle, paused for 10 seconds, played the
saved *Verse riff* for 40, paused for 10 more, and left. The store then held two new rows:

| Kind | Started | Logged | The drive's own clock |
|---|---|---|---|
| `exploring`, *Naming test*, no unit | 11:24:42 | 40.8 s | play 11:24:43 → pause 11:25:23 |
| `songPlayerLoop`, *Verse riff*, no tempo | 11:25:35 | 41.6 s | play 11:25:35 → pause 11:26:17 |

106 seconds on the screen, 82.4 logged: the two quiet stretches left out. The Practice log showed
**Exploring** as a group of its own and one **Loops** group.
