# Red Moon Practice — beta guide

**Canonical copy for the tester-facing guide.** The web version at
`/redmoon/beta/<slug>` on the `.co.uk` site is a port of this file. Written here so it is
reviewed alongside the app, and so it can later seed the in-app guided-creation copy
(ADR 0149).

**Do not restate the FAQ here.** `Pocket/Core/Help/FAQEntry.swift` is the single source of
truth for those seventeen answers. This guide points at Help & FAQs; it does not duplicate
it, or the two will drift.

Voice: address the reader as a musician. Plain, direct, no marketing. The one moment that
gets any ceremony is the first loop.

---

## 0. Before anything — the ground rules

Thanks for doing this. Three things, and then we'll get to the music.

- **Don't share the build.** The TestFlight link is yours. Apple's terms say the same thing,
  but it's worth saying in plain English.
- **Don't post screenshots** or talk about it publicly yet.
- **Tell me when it's bad.** Politeness is the enemy here. If something confused you, that's
  the most useful sentence you can send me — more useful than anything you liked.

*(Web version: name + email + tickbox, then the rest of the guide unlocks.)*

---

## 1. Before you start

You'll need:

- **An iPhone on iOS 17 or newer.** iPhone specifically — it'll install on an iPad, but in
  phone-compatibility mode, and I've never tested it there. An iPad read isn't useful to me
  this round.
- **The TestFlight app**, and the invite link I sent you.
- **Headphones**, or at least somewhere you can hear the click over your playing.
- **One piece of music you own as a file.** This is the important one — see below.

### About that file

Red Moon slows music down, loops a bar of it, and puts a click over it. To do that it needs
the actual audio, which means **a file on your phone or in iCloud Drive**. Spotify and Apple
Music won't work — that audio is encrypted, and no app can reach inside it. That's not a
limitation we chose; it's the wall every app hits.

So you need one of:

- **A track you bought** as a download.
- **A backing track** you own.
- **Something you recorded yourself.** Thirty seconds of you playing into Voice Memos is
  genuinely enough to test with.
- **The starter track** — *Binta*, [download it here]. It's a piece I wrote and recorded, so
  you're clear to use it. Grab it if you have nothing else to hand.

Get at least one of your own in there too, if you can. How that import feels on your own
music is a big part of what I'm trying to learn.

---

## 2. What this is, and what it isn't

Red Moon is a practice room, not a music player. You bring a song you're trying to learn,
mark the bar that keeps beating you, slow it right down, and loop it against a click until it
stops beating you. Everything else in the app exists to support that.

**It will never score your playing.** Nothing listens and grades you, and nothing ever will.
When you see a rating, you put it there. Your recordings stay on your phone.

---

## 3. Your first session

Three steps. Do them in order — they build on each other, and together they're the whole app
in miniature.

### Step 1 — Get the song in, and listen to it

Tap **+** on the home screen and pick your file. Then play the whole thing through at full
speed, without touching anything.

This feels like a wasted step. It isn't. You're deciding what you actually want out of this
song before you start dismantling it.

Then write it down: open the **Journal**, tap **＋**, and note what you're after. One line is
fine. *"The turnaround at 1:20 — I keep rushing it."*

### Step 2 — Mark the bit you can't play

Drop the speed to around **0.85×** and play through again. The pitch doesn't change when you
slow it down — it's still in the same key.

When you reach something you want to come back to, drop a **marker** on it. Do that a few
times. You're building signposts, not being precise.

### Step 3 — Make the loop

This is the one.

Play up to the start of the passage that's giving you trouble and **tap Loop**. That drops
your start point. Play through to the end of the passage and **tap Loop again** — it closes
the loop and starts repeating it immediately.

Now take the speed down to about **50%** and let it go round. Play along. Stay there longer
than feels necessary.

When it's comfortable, nudge the speed up and stay there. Then again.

If you want to keep this loop, tap **Save as loop**. If you don't, tap **✕** and the song
plays on through.

> **That's it. That's the app.**
>
> Everything else — the drills, the routines, the planner, the tuner — is scaffolding around
> that one move. If you only ever do this, you're using it right.

---

## 4. Hold anything for a moment

Now the thing you'd otherwise never find.

**Across the whole app: a tap does the thing, a hold edits the thing.** Press and hold for
about half a second, and you'll usually get more. Once you know the rule you don't need the
list — but here's the list anyway, because some of these are genuinely hidden.

**On the practice screen**

| Do this | Get this |
|---|---|
| **Hold the BPM number** | Type a tempo in directly, instead of nudging it |
| **Hold the song title** | Song details |
| **Hold a loop** in the panel below | Edit it (a tap just plays it) |
| **Hold a marker** | Edit it (a tap jumps there) |
| **Hold a panel header** | Select several at once, to delete or edit in bulk |
| **Double-tap** the restart button | Jump to the previous marker |
| **Hold** the skip button | Choose how far it skips |
| **Hold "Loop controls"** — the status line under the speed bar, beside Follow and Grid | This screen's four switches, opened over the waveform so you can watch them take effect: which side the Loop button sits on, the whole-song strip, marker labels, and what pinch-to-zoom holds still. A *tap* still shows the gesture cheatsheet |
| **Pinch** the waveform | Zoom, centred where your fingers are |

**Everywhere**

| Do this | Get this |
|---|---|
| **Hold a − or + button** | It repeats, and speeds up the longer you hold. Don't tap forty times |
| **Hold any row** in a list | Its menu — including Favourite and Delete |
| **Swipe a row** | The same actions, faster |
| **Hold "insert rest"** when building a routine | Places rests between *every* block at once |
| **Drag a block** in a routine | Reorder it |

*(If you're using VoiceOver, all of these are announced as actions — you don't need this
page.)*

---

## 5. Build your own drill

Beyond songs, you can build practice drills from scratch. **Practice → Exercises → +.**

Pick a template and it gives you the right surface for that kind of practice — a fretboard
for scales, a chord grid for progressions, a strum lane for rhythm. Fourteen of them:
Basic, Strumming, Scales, Arpeggios, Chords, Chords & Strum, Picking, Legato, Fingerstyle,
Rhythm, Warm-up, Ear training, Theory, and Freeform.

**Freeform** is worth knowing about: it's a duration and a box for your own instructions.
Sight-reading, transcribing, whatever your teacher set you — practice that's real but that
the app doesn't model.

**Guitar or bass is decided on this screen**, by the control at the top — not in Settings.
Settings ▸ You only sets which one the screen *opens* on; whatever you pick here is what the
drill is, and what its notes get named in. Pick **Bass** and you get a four-string neck, bass
tuning, and a chord vocabulary a bassist would actually play — roots and fifths, octaves, the
major and minor tenth, two shell shapes for further up. Strumming and Chords & Strum aren't
offered for a bass drill, because a down/up strum lane isn't a bass technique.

**The board moves while it plays.** The walking highlight — the one that walks a scale along
the fretboard, or the strokes along the strum lane, in time — is on out of the box now. If
you'd rather it didn't, Settings ▸ Practice has the switch, and Reduce Motion turns it off
everywhere.

**For the beta, please build at least two:** one **Scale** and one **Chord progression**.
They're the two richest editors and the two I most need eyes on.

Once a drill exists you set its **command tempo** — the speed you can currently play it
cleanly — and optionally a **ramp**, which climbs the tempo for you while you play.

---

## 6. Let it plan the session

**Home → Start today's session.**

Set a goal, pick a length, and it builds a session out of *your* library. What it chooses
leans on: how long since you last practised something, how well you've rated yourself on it,
which goal you set and how high you weighted it, and the genres you picked when you first
opened the app.

Two honest notes:

- **It draws only on what you've built.** On a fresh install that's six drills, so early
  sessions will feel thin. It gets meaningfully better once you have a dozen or so — which
  is why this is worth trying in week three rather than day one.
- **Rating something 5 out of 5 retires it.** The planner reads that as *done*, and stops
  offering it. Nothing decays it back on its own — if you want it in rotation again, lower
  the rating yourself. The app won't quietly change a number you set.

---

## 7. The rest of it

- **Routines** — string drills together into a session you can replay. Rests allowed.
- **Journal** — every note and recording you've made, newest first. Tap the caption on any
  entry to jump back to what it was about. **A note doesn't have to be about anything** —
  the ＋ writes one that belongs to no loop, drill or routine, which is what you want for
  "left hand tired today" or an idea you don't want to lose.
- **Progress** — from the Journal toolbar. Your week, your month, your all-time hours.
- **Toolkit** — tuner (guitar and bass), your saved chords, and a glossary. Free forever,
  no subscription.
- **Metronome** — standalone click with ramps and a tap-tempo. The **pencil** in its toolbar
  writes a note that carries the click you wrote it to — tempo, time signature, subdivision,
  any withdrawal — so weeks later it still says what it was clean *at*.
- **Help & FAQs** — in the Toolkit, and in Settings → Help & About. Seventeen answers to the
  questions that actually come up. Start there before you email me.

---

## 8. Telling me what happened

**Use TestFlight.** Take a screenshot inside the app, then share it to TestFlight — you can
scribble on it and add a note. That comes straight to me with your device and build details
attached, which saves us both a round trip.

There's also a **Contact Support** row in **Settings → Help & About**. It used to open Mail —
and do nothing at all if you had no Mail account set up — but it's a form now: your email,
your message, Send. It works whether or not Mail is configured. Three details ride along, and
they're printed in the sheet above the Send button so you can see exactly what you're sending:
the app version, your iOS version, and your device model. Nothing from your library goes with
it — not your songs, recordings, notes or artist name.

Either channel reaches me. TestFlight is still the better one for anything visual, because the
screenshot comes attached.

And on this page, every step has an **"It didn't do that"** button. Press it the moment
something goes sideways — a note written while you're confused is worth ten written a week
later.

### What I'm actually after

Not *"it's nice"*. This:

- Where did you stop, and what did you try next?
- What did you expect to happen that didn't?
- What did you open it for the last time, and what made you put it down?

The confusing parts are the useful parts. Send those.
