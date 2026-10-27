# Messaging

*Written 2026-10-24 (ADR 0276). `docs/positioning.md` argues the position from the market; this is how
it is said, to whom, and what follows for outreach. A working document: the SWOT and the outreach plan
are judgements from the repo and the competitor roster, not research with players. Test them (§6).*

---

## 1. The line

> **Red Moon is a practice studio for players who learn from everywhere.** It doesn't hand you
> another method. It gives you the tools to build your own from what you already learn from, and it
> keeps everything you do, so your practice adds up instead of starting over.

*ADR 0279 (2026-10-27). Until then the line was ADR 0276's: "a practice studio for songs you own…
and it works alongside whatever you already learn from". The new line leads with the person instead
of the input.*

- **Practice that adds up** is the benefit. Yesterday's loop is a block in today's session, the tempo
  you reached is where you start, and a note sits on the loop it was about.
- **Works alongside your other sources** is the posture. A video, a teacher or a course stays where
  it is; the studio keeps hold of what you took from it (ADR 0167). It is also why the app never
  shames you for jumping between them (`positioning.md` §3).
- Say **practice studio**, both words. Not *coach*, *tutor* or *teacher* (promises judgement, ADR
  0070). Not *studio* alone (reads as a recording app).

**Four verbs, under one roof (ADR 0279):** **work it out** (the slow-downer and the ear) · **build
it up** (the click under every drill) · **run it** (routines) · **keep it** (takes, journal, log; your
own commentary, never a score). The roof is **your sources, your method**: it's why these are tools and
not a syllabus. The App Store description is organised this way.

The first-song guide keeps its own three beats, **Loop it → Slow it down → Keep it**: it's the way in,
the first verb taught in detail.

## 2. The pitch at each length

| Length | Say |
|---|---|
| **One line** | A practice studio for songs you own, where your practice adds up instead of starting over. |
| **10 seconds, to a guitarist** | You know looping the part you can't play and slowing it down? It does that on your own songs, then remembers where you got to so tomorrow starts there. |
| **30 seconds** | Most of us learn from four places at once: YouTube, a teacher, tabs, a record. Red Moon is where it adds up. Loop the hard bar in a song you own, slow it down without changing the pitch, then line those loops up with drills into a session you press play on. It keeps the notes, the tempos, and a link back to the lesson. Nobody scores you. |
| **To someone who doesn't play** | A notebook and a slow-motion replay for learning an instrument, that never tells you you're doing badly. |
| **To a teacher** | Build a routine, send it to your student with the songs inside, and it plays on their phone. They loop what you set, and you see nothing of what they play. |
| **App Store subtitle** | *Loop, slow down, learn songs* — unchanged: it is what people search for. |
| **App Store promotional text** (1.4; 166 of 170 characters) | Loop the hard bar in your own tracks and slow it down without dropping the pitch. Then line your loops up with drills into a session that picks up where you left off. |

Never say *free*, *streaks*, *score*, *level up*, or imply Apple Music or Spotify works (ADR 0001).

## 3. Feature → need → benefit

Features are grouped by the problem a person already has. Lead with the problem, not the feature.

| The person's problem, in their words | Features | The benefit |
|---|---|---|
| "I can't play this one bar." | Waveform loops, slow-down with pitch held, markers, tempo ramp against a click, click withdrawal | The hard four bars get clean in minutes, not by replaying the whole song. |
| "I waste the first ten minutes deciding what to practise." | Routines, Today's session, goals, drills | Open it and press play. |
| "Tomorrow I start from nothing." | Saved loops that become routine blocks, resume tempo, per-loop mastery and last-practised speed | **Practice adds up.** |
| "I can't work out what they're playing." | Counting notes, naming notes on the neck, your own tabs, the song map | Your ear improves, and the app never marks an answer wrong. |
| "I forget what I worked on and what my teacher said." | Journal, takes, references (a link or file on any song, loop or drill), the practice log | The thread survives jumping between sources. |
| "I don't know the fretboard." | Scale boxes, chord placer, saved chords, glossary, progressions | Theory shown where your hand goes. |
| "I just need the basics." | Tuner, metronome | No setup. |
| "My teacher or bandmate should see this." | Send a routine or a song with its loops | A plan that plays at the other end. |
| "Will it judge me, or sell my practice?" | No grading (ADR 0070), no account, no analytics (ADR 0239), nothing leaves the phone | Safe to practise badly. |

The first two rows are the hook. The third is why they stay. Present the tuner, chords and theory as
supporting tools, not as the pitch: leading with them is how the app ends up sounding like forty things.

## 4. Strengths, and the SWOT

### Strengths worth saying out loud

1. **A real audio engine on the player's own files.** Waveform, A/B loops, pitch-true slowing, markers,
   takes. The organisers (AxeLog, Modacity, Practis) have none; the audio apps (Moises, Anytune) hold
   no session.
2. **Memory.** Loops become routine blocks, tempos carry over, notes pin to a moment. Nothing resets.
3. **No judgement, as a design principle with a guard.** `check-manual.py` fails the build on
   *streak*. In a market of streaks, heatmaps and AI report cards, this is the emotional hook.
4. **Complements, doesn't compete with, the lesson.** References and sending a routine mean teachers
   and YouTubers are allies, not rivals.
5. **Private by construction.** No account, no analytics, nothing leaves the phone unless sent.
6. **Depth of craft.** A big exercise catalogue, a real fretboard and chord engine, and a manual that
   is held to what the app says.

### SWOT

| | |
|---|---|
| **Strengths** — the six above, plus a small, plain, locked-in price (ADR 0256, 0274) | **Weaknesses** — no users, reviews or social proof yet (the app has never been on sale, ADR 0256); needs DRM-free files, so it is near-empty for streaming-only players and beginners with nothing of their own (ADR 0001); a hard thing to explain, from feature accretion; iPhone-only and no cross-device sync; one-person marketing capacity; the landing page has no card for routines or memory |
| **Opportunities** — guitarists already scattered across YouTube, a teacher and tabs; backlash against streak and gamified apps; teachers who want a way to hand work over; the "founding price" as a real, honest scarcity story; beta testers as first voices; evidence that players pay for tools that work on their own audio (Moises, Anytune) | **Threats** — Moises, Anytune or Soundslice adding routines or memory; Captrice, free and shipping the "complement" idea on YouTube; AxeLog (4.8★, AI plans) owning "practice planner" in search; players who no longer own audio; App Store discovery cost for a one-person app; a low price read as low value |

### What the SWOT says to do

- **Weakness × threat:** the danger is being read as a loop app with extras (beaten by Moises) or a
  planner with no engine (beaten by AxeLog). *Adds up* is the sentence that only an app holding both
  can say, so it is the line to repeat.
- **Strength × opportunity:** *no judgement* against streak apps, and *works alongside your lesson*
  with teachers, are the two things competitors cannot copy without abandoning their model.
- **Weakness to fix, not message around:** be upfront that it needs audio files you own. Saying so
  filters the audience to the right people and avoids one-star "can't use Spotify" reviews.

## 5. How this changes marketing and outreach

**Who to speak to first.** The self-taught player who has tried a practice schedule and quit it
(`positioning.md` §8). Not beginners with no material, and not players who want to be told what to
practise.

**Message by channel**

| Channel | Lead with | Asset |
|---|---|---|
| **App Store page** | Loop and slow down (the search term); *adds up* in the promotional text; screenshot 6, the routine, with a caption | Promotional text now; description is already studio-voiced |
| **Reddit, forums, Discords for self-taught players** | The problem ("I loop a part, close the app, start over tomorrow"), not the app. Answer questions first. | A 15-second screen recording: draw a loop, drop the speed, hear it clean |
| **Guitar teachers and YouTubers** | "Your lesson, my studio." They stay the authority; the app holds their students' thread. | A routine they can send, and a founding-price code |
| **Friends and personal network** | The 10-second line, then hand them the demo song | Binta, in the app, with the guided first loop |
| **Press and newsletters** | The no-judgement angle against streak culture | One honest paragraph and the story page |

**Influencer and creator outreach, concretely**

1. Start with **micro-creators and working teachers** (hundreds to low tens of thousands of followers)
   who already make "how to practise" or "learn this song" content. They have the audience that
   matches the one person this app is for, and a small app can have a real conversation with them.
2. Open with the **complement** angle, not a request for a plug: *"your lessons plus a place where
   students' practice adds up."* Offer to build a routine around their lesson so they can see what
   their students would receive.
3. Give them the app free with a way to hand a code on (App Store offer codes), and **no script**.
   A paid script reads as one; the no-judgement stance gives them a story of their own to tell.
4. Prefer **demonstrations over claims**: the waveform is visual, and a loop sped up from slow to
   target is a better 15 seconds than any sentence here.
5. Use **beta testers' own words** once there are some; nothing persuades like another player.

**What to measure, honestly.** The app counts nothing (ADR 0239), so there is no in-app funnel. What
exists is App Store Connect: impressions, product page views, downloads, and conversion. Offer-code
redemptions will tell you which creator brought people. Everything else is qualitative: ask the first
fifty players how they heard of it and what they were doing before.

**Constraints that shape the copy.** No streaks or scores (ADR 0070); no Apple Music or Spotify
claims (ADR 0001); the manual, FAQ and help never name a price (ADR 0145 D6); ads are not ruled out
for ever but are kept off the practice screens (ADR 0240).

## 6. To test before leaning on any of this

- Does "adds up" mean something to a player, or is it your word? Ask five guitarists how they practise
  now and what they do when they get stuck, **before** pitching. Use their words if they have better ones.
- Does **studio** land as a place to practise, or as recording software? Watch for the question
  "is it a DAW?" If people ask it, add *a practice studio, not a recording app* to the long form.
- Is the first win fast enough? Time a stranger from install to a loop that sounds clean.
- Is the price settled in every surface? `positioning.md` §7 lists where it was still wrong.
