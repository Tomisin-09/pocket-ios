# Messaging

*Written 2026-10-24 (ADR 0276). `docs/positioning.md` argues the position from the market; this is how
it is said, to whom, and what follows for outreach. A working document: the SWOT and the outreach plan
are judgements from the repo and the competitor roster, not research with players. Test them (§6).*

---

## 1. The line

> **Red Moon is a practice studio for guitar players who learn from everywhere.** It doesn't hand you
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

### The why under the line: a practice studio for self-determined improvement

*Added 2026-10-28, from working out how to describe the metronome, and reframed the same day around
improvement. It is a framing, not research with players. Test it (§6) before it goes into public
copy. The Marketing Foundation carries the same Why from its 28 October revision.*

**The Why.**

> *Anyone can get better at an instrument when the method is their own, their practice carries over
> from one day to the next, and they can see it adding up.*

It replaces the Foundation's *anyone can learn to play an instrument, given the right inspiration, the
right tools and the right systems* in two ways. The promise is **getting better**, not learning to play.
That holds at any level, so it suits a player who has already learnt and stalled (`positioning.md` §8)
better than a beginner's promise does. And the three conditions are named instead of being "the right"
anything.

**What Red Moon sells: a practice studio for self-determined improvement.** A strategy sentence, not
copy, because *self-determined* is a strategy word. It says *practice studio* rather than a looser word
like *space*, so the place has one name everywhere (ADR 0276). Each part is one clause of the Why:

| Part | Clause of the Why | What it means |
|---|---|---|
| **Self-determined** | the method is their own | The player decides what to work on, how, and where they learn it from |
| **Practice studio** | their practice carries over | A place, not a path, and one that keeps what was done in it |
| **Improvement** | they can see it adding up | No finish line, so progress is measured from where they started |

The public line already says all three: it is a *practice studio*, *learn from everywhere* and *build
your own* are the self-determination, and *adds up* is the improvement. So this is the meaning under
ADR 0279's line, not a new position.

**The promise: improvement, not mastery.** Mastery is never reached. Daniel Pink's word for it in
*Drive* is an asymptote: you keep getting closer and never arrive. Tal Ben-Shahar calls the belief that
a reached goal will settle things the *arrival fallacy*; the next goal turns up instead. James Carse's
*finite and infinite games* (the source of Simon Sinek's *The Infinite Game*) names the difference: a
finite game is played to win, an infinite one to keep playing. Practice is an infinite game.

The catch is that an endless climb can sound like *you'll never be good enough*. What makes it bearable
is where it is measured from. Against the summit a player is always short; against where they started,
they are always ahead. That is why *they can see it adding up* is the clause the promise rests on, and
the app already measures that way: **Mark as met** retires a goal without deleting it, and Progress
keeps the old command tempo when a drill moves up (*Last rated 5 at 70 BPM*).

**The stance: Red Moon doesn't claim to have all the answers.** A course or a curriculum app claims two
things: **the path** (it knows what you should learn next) and **the verdict** (it knows whether you did
it right). Red Moon claims neither. *Your sources, your method* (ADR 0279) gives up the path, and the
no-grading law (ADR 0070) gives up the verdict. Education research has names for the difference.
*Andragogy* is self-directed learning: you pick your pace through a path someone else set, which is as
far as most learning apps go. *Heutagogy* (Hase and Kenyon, 2000) is self-determined learning: you also
decide what to learn, and where from.

That is not the same as offering no help. Red Moon ships methods (preset drills and routines, the
first-song guide, Today's session), and a new player needs a way in: the 1.3 beta's one clear finding
was a locked door. The claim is narrower: **Red Moon's answers are offers, and none of them is in
charge.** Say what Red Moon is, never what other apps claim.

**Why the promise needs the stance.** Because mastery has no finish line, nobody can own the answers. A
course has a last lesson, so *course complete* is the arrival fallacy built into a product. When the
goal keeps moving, a fixed path goes stale, and only the player can say what comes next.

**The barrier: practice that forgets.** A plain metronome is *stateless*: it keeps nothing between
uses, so every sitting starts from a tempo dialled in from nothing. So is nearly everything a
self-taught player learns from: the video, the tab site, the slow-downer that forgets the loop when it
closes (`positioning.md` §8). The only thing carrying practice from one day to the next is the player.
That is why discipline feels hard. The player isn't short of willpower. They are the only part of their
practice that remembers, and carrying all of it is tiring.

**What Red Moon does about it.** It carries that state, so discipline stops resting on the player's
memory. This is the Why's middle clause, *their practice carries over*. Discipline isn't a trait some
players have. It's what practice becomes when something remembers where you got to. James Clear's short
form: *"You do not rise to the level of your goals. You fall to the level of your systems."*

**Why the three clauses hold: Self-Determination Theory.** Deci and Ryan's theory says motivation lasts
when three needs are met. In music it predicts quitting: people who stopped playing had less of all
three in the run-up to stopping, and gave reasons that were about those needs (Evans, McPherson and
Davidson, 2013). That study followed people who started at school, not self-taught adults, so treat it
as support, not proof.

| Need | In Red Moon |
|---|---|
| **Autonomy**: the reasons are your own | Your sources, your method (ADR 0279); goals you write yourself (ADR 0171) |
| **Competence**: you can see yourself getting better | The tempo you reached; the practice log's *new tempos*; takes to listen back to |
| **Relatedness**: it connects you to people | Thin, on purpose: links back to the lesson (ADR 0167); sending a routine, or a song with its loops |

What the theory adds:

- **Aim for a reason the player endorses, not for fun.** SDT ranks motivation from external (rewards
  and punishments), through *introjected* (guilt and pressure: *don't break the streak*) and
  *identified* (*I practise because I want to play that solo*), to intrinsic (enjoyable in itself).
  Drills are rarely fun, so the realistic target is identified. A goal that schedules tonight's drills
  is that idea built in. A streak is introjected, which is the theory behind the streak ban
  (`design-brief.md` §3.5): motivation that runs on guilt wears off.
- **Consistency is structure, not a need.** The opposite of autonomy is control; the opposite of
  structure is chaos. So a player can have both (Jang, Reeve and Deci, 2010). Practice that forgets
  hides progress, and progress nobody can see feels like none. That makes statelessness **a competence
  problem that looks like a willpower problem**.
- **Tracking informs; it never controls.** Feedback that tells a player something feeds motivation, and
  feedback that judges or pressures drains it (Cognitive Evaluation Theory, part of SDT). The test for
  any progress feature: **if the player ignored it for a week, would it scold them?** A streak would.
  The practice log doesn't. Progress is measured against the player's own past, never against other
  players, and only the player reads it.
- **Relatedness is the thin leg. Say so, and don't build it in.** Feeds and leaderboards compare
  players, which breaks ADR 0070 and ADR 0239. Red Moon meets the need by staying out of the way of the
  people a player already has: the teacher, the band, the person in the video. Don't claim all three
  needs equally.
- **The satisfaction lands on the guitar, not the app.** The METUX model (Peters, Calvo and Ryan, 2018)
  asks where a need is met: in the app, or in the activity the app serves. Gamified learning apps meet
  competence inside the app, with points and streaks. Red Moon is the other way round.
- **Where it shows the gaps.** An empty studio is autonomy without structure: total freedom and no idea
  where to start, which is the activation gap. And never grading is a real trade. Competence has to
  come from evidence the player reads for themselves, and some players want to be told.

**Three layers, so the app doesn't sound like forty things.** The features are evidence for the Why,
not headlines of their own.

| Layer | Says |
|---|---|
| **Why** | Anyone can get better at an instrument when the method is their own, their practice carries over, and they can see it adding up. |
| **How** | No path imposed and no verdict given. Red Moon remembers for you, you decide the method, and nothing grades you. |
| **What** | The four verbs; goals that schedule sessions; a metronome whose tempo you can keep. |

**Two worked instances.**

- **The metronome.** The click screen on its own forgets, and copy must not say otherwise: the memory
  starts when the tempo is attached to something. The 🔖 keeps the tempo and meter as a drill. The
  drill keeps its command tempo, *the fastest you own it*. A finished run offers to move it up to the
  reach, and Progress keeps the old one (*Last rated 5 at 70 BPM*). The log's month lists new tempos.
  A song's tempo can be carried in the other way (ADR 0170). Nor does the start of a sitting ask for
  theory: you tap the beat, and the meters are named for the music they belong to (*3/4 · Waltz*,
  *6/8 · Jig · ballad*). Together: *you don't need to know the number to start, or remember it
  afterwards.*
- **Goals.** Don't lead with "set your goals". Every organiser offers that, and this player has already
  tried it and dropped it. Lead with what is different: **a goal here schedules practice.** Its skills
  pull drills and loops into Today's session (*"an empty one schedules nothing"*), a target song
  schedules that song's loops and a play-through, and **Mark as met** retires a goal without deleting
  it. A goal written in a notebook is stateless too: it doesn't change what you play tonight.

**Words.**

- ***Discipline***: use it only to redefine it (*discipline isn't willpower*), never as a demand (*be
  more disciplined*). What this player fears is quitting again.
- ***Self-determined***, ***heutagogy***, ***Self-Determination Theory***: words for strategy, not
  copy. In public, say the needs in plain words. If the theory is named anywhere, it is once, on the
  story page.
- ***Practice studio***, not *space* or *platform*, in strategy as well as copy, so the place has one
  name. ADR 0276 chose *studio* over *room*, and *space* would reopen that choice.
- ***Mastery***: the app's word for a rating on a loop or drill (*mastered* is a 5 at full speed, ADR
  0250), never a promise. Copy promises getting better, not arriving.
- ***Chasing the dragon***: a good private picture of a goal that keeps moving, and drug slang, so never
  in copy. *There's no last lesson* says the same thing.
- **Not *intelligence* or *smart*.** Both read as AI, which is the Oracle's territory, and both put
  the knowing in the app. The app keeps what the player decided: the command tempo only moves when they
  accept the offer.
- ***A goal for this session*** and ***a long-term goal***, the app's own terms, not *short-term*.
  The manual says they *"differ in what they are about, not in how long they last"*. ADR 0171's
  title, *a goal that outlives the session*, is the phrase to borrow.
- ***Approachable***, not *accessible*, unless the claim also holds for VoiceOver and Dynamic Type. On
  the App Store, that is what accessible means.

**Analogies.** For players: **the tempo pencilled in the margin.** Disciplined players already write
their working tempo on the part, start there next time, and cross it out when they move up (60, 66,
72, 80). That shows the climb without grading it. Red Moon does the pencilling, so a player gets that
habit without needing that kind of discipline. For people who don't play: **the gym log.** Nobody guesses what to put on the
bar: you check last time and add a little. That is progressive overload, and command → reach → move up
is the same cycle. Use the analogy for how it works, not for gym culture, where personal bests are
verdicts. A doorframe with height marks was considered and dropped: its payoff is being measured, and
it is passive.

**Candidate lines** (untested):

- *Discipline isn't willpower. It's remembering where you got to.*
- *Say what you're working toward. Red Moon turns it into today's session.*
- *Keep the tempo you found, and start there next time.*
- *Good players pencil in their tempo and start there next time. Red Moon does the pencilling.*
- *Your lessons, tabs and videos stay where they are. Red Moon remembers what you took from them.*
- *There's no last lesson. There's where you got to.*
- *Red Moon doesn't have all the answers. It keeps yours.*

**Sources.** Deci and Ryan, Self-Determination Theory. Evans, McPherson and Davidson (2013), *The role
of psychological needs in ceasing music and music learning activities*, Psychology of Music 41(5).
Jang, Reeve and Deci (2010), *Engaging students in learning activities: it is not autonomy support or
structure but autonomy support and structure*, Journal of Educational Psychology. Peters, Calvo and Ryan
(2018), *Designing for motivation, engagement and wellbeing in digital experience*, Frontiers in
Psychology. Hase and Kenyon (2000), *From andragogy to heutagogy*, ultiBASE. Daniel Pink (2009),
*Drive*. James Carse (1986), *Finite and Infinite Games*.

## 2. The pitch at each length

| Length | Say |
|---|---|
| **One line** | A practice studio for songs you own, where your practice adds up instead of starting over. |
| **10 seconds, to a guitarist** | You know looping the part you can't play and slowing it down? It does that on your own songs, then remembers where you got to so tomorrow starts there. |
| **30 seconds** | Most of us learn from four places at once: YouTube, a teacher, tabs, a record. Red Moon is where it adds up. Loop the hard bar in a song you own, slow it down without changing the pitch, then line those loops up with drills into a session you press play on. It keeps the notes, the tempos, and a link back to the lesson. Nobody scores you. |
| **To someone who doesn't play** | A notebook and a slow-motion replay for learning an instrument, that never tells you you're doing badly. |
| **To a teacher** | Build a routine, send it to your student with the songs inside, and it plays on their phone. They loop what you set, and you see nothing of what they play. |
| **App Store subtitle** | *Loop, slow down, learn songs* — unchanged: it is what people search for. |
| **App Store promotional text** (1.4; 161 of 170 characters; ADR 0279) | Work out the hard bar, build it up against a click, run it in a routine, and keep what you learn. A practice studio for guitar players who learn from everywhere. |

Never say *free*, *streaks*, *score*, *level up*, or imply Apple Music or Spotify works (ADR 0001).

## 3. Feature → need → benefit

Features are grouped by the problem a person already has. Lead with the problem, not the feature.

| The person's problem, in their words | Features | The benefit |
|---|---|---|
| "I can't play this one bar." | Waveform loops, slow-down with pitch held, markers, tempo ramp against a click, click withdrawal | The hard four bars get clean in minutes, not by replaying the whole song. |
| "I waste the first ten minutes deciding what to practise." | Routines, Today's session, goals, drills | Open it and press play. |
| "Tomorrow I start from nothing." | Saved loops that become routine blocks, resume tempo, per-loop mastery and last-practised speed | **Practice adds up.** |
| "Every time I open the metronome, I start from zero." | Tap tempo, meters named for their music, the ramp, keeping a tempo you found as a drill with its command tempo | The tempo you reached is where you start next time. |
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
- Does **discipline** help or hurt (§1, *the why under the line*)? Even in *discipline isn't
  willpower*, the word may put off a player who has quit a schedule before. Try the line on players
  who have, and watch for a flinch.
- Which analogy lands, the pencilled tempo or the gym log, and with whom? A player who has never kept
  a practice notebook may not recognise the first.
- Does *get better* pull harder than *learn to play* for a player who has stalled (§1, *the Why*)?
- Does *your method* read as freedom or as *you're on your own*? Say the self-determined studio in plain
  words to a beginner and to a lapsed player, and listen for "so what do I do first?" If the beginner
  asks it, the stance needs its way in said in the same breath.
