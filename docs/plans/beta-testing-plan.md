# Closed beta — plan of attack (2026-08-09)

Eight invited testers, distributed via TestFlight, over three weeks. Nobody is onboarded in
person and nobody is observed live, so the protocol has to carry what a room would normally
carry. Sequenced so each week tests one thing and the cheapest questions come first.

**This round is not primarily a bug hunt.** Its main job is to produce the specification for
the unbuilt onboarding flow in
`docs/decisions/0149-guidance-arrives-with-the-song.md` (Proposed, v1.2). 0149 asserts a
three-step path — listen whole, mark sections, create loops — fired on first import. This
beta is the manual, human-run version of that flow. **Where testers stall is the spec.**

The tester-facing guide that accompanies it is `docs/beta/user-guide.md`.

> **Revised 2026-08-12, against the build the round actually runs on: 1.2 (4).** Eleven merges
> landed between this plan and the build, and three of them change the protocol rather than
> just the app. **ADR 0161** made the in-app Contact Support row work without Mail, retiring
> C0's fourth screening question. **ADR 0163** added a hold whose tap does something else
> entirely, which belongs in the C2 gesture count. **ADR 0116 S7 and 0164** moved the
> instrument choice onto the exercise-creation screen and gave bass its own chord vocabulary,
> which is most of tester H's lane. Also landed: **0157** (the walk animates by default —
> Week 2 now reads a moving board), **0155** and **0160** (standalone journal notes, and a
> note at the metronome that records the click), **0162** (Settings is nine destinations, and
> "Transport" is now "Song player"), and **0159** (two collections widen rather than narrow).
>
> **Deferred past this build, deliberately:** ADR 0156's paywall cadence and ADR 0149's guided
> walkthrough. The round is unaffected by the first — interaction 3 in
> `docs/plans/v1-2-integration-plan.md` already established that testers hold Pro and can tell
> us nothing about paywall reaction. The second is the *point*: 0149 is unbuilt, and this round
> is the manual, human-run version of it.

---

## Decisions taken at planning — settled, don't re-litigate

- **Testers get Pro for free via the StoreKit sandbox environment, not via a purchase.**
  TestFlight builds are Release builds, so `debugProOverride` (`#if DEBUG`) does not apply,
  and under ADR 0144 D4 Practice, the Song library and the planner are all locked with a
  launch paywall on every cold launch. The alternative — telling testers to "subscribe" with
  a free sandbox purchase — was rejected: sandbox subscriptions are time-compressed, so a
  one-month trial lasts minutes and auto-renews only a handful of times, meaning testers
  silently lose Pro mid-round with no way for us to see it happened. **Cost accepted: this
  round learns nothing about paywall reaction.** That is a separate round.
- **No new analytics events.** With n=8, no user identifier in Aptabase, and a region-split
  consent default, new event vocabulary buys nothing a six-question form gives better. ADR
  0149 §8's checklist metrics stay unbuilt until there is a population large enough to read
  them.
- **Activation is measured by hand.** Time from install to first loop created, from the day-0
  screen recording and self-report. Not from telemetry.
- **Two testers are held out from the guide for 48 hours.** Their stalls are the onboarding
  spec; a guided tester's success only tells us the guide works.
- **The guide is gated by obscurity, not access control.** An unlisted URL plus a
  click-accept. Real auth on the marketing site was rejected — that branch pushes straight
  to production with no CI or staging gate, and a bad middleware matcher would take down
  `/redmoon/support` and `/privacy`, both of which App Review checks.

## Scrapped at planning — recorded so they don't come back

- **A formal signed NDA.** The app has already shipped to the App Store and the guide
  describes shipped features. TestFlight's own terms already forbid redistributing builds.
  Ground rules with a timestamped acceptance carry the real weight here; an NDA would add
  friction with eight friends and protect nothing extra.
- **1–5 satisfaction scales.** With eight people they produce a number that looks like data
  and isn't. Every question in this plan is behaviour-anchored instead.
- **Asking everyone to test everything.** Eight people cannot cover this surface by
  wandering. Lanes below.

---

## What the app cannot tell us, and why the protocol looks like this

Worth stating once, because it is the reason for the screen recordings and the forms:

- **Aptabase carries no user identifier at all.** There is no per-tester funnel and no
  retention curve. Events are aggregate counts.
- **Consent is region-split** (ADR 0147). EEA + Switzerland default **OFF** and are only
  asked after `hasPracticed` — a tester there who never starts a run is never asked and
  emits nothing, ever. UK and rest-of-world default **ON**.
- **The event queue is in-memory.** Events are lost if the app is killed while offline.
  Someone practising with the phone face-down in a room with no signal under-reports.
- **There is no event for the intake, the name prompt, FAQ opens, settings changes, or any
  onboarding step.** The observable pair is `song_imported` → `loop_created`, plus the
  `since_install` bucket on `practice_started`.

Treat telemetry as a coarse sanity check on the round's shape. Everything that matters comes
from the recordings and the forms.

---

## The cohort

| ID | Instrument(s) | Background | Primary lane |
|---|---|---|---|
| A | Electric + Piano | Masters student | Toolkit and theory language; scale/chord naming precision |
| B | Electric + Acoustic | Artist | The core path clean, on two instruments |
| C | Acoustic | Artist | Strumming and Chords & Strum; tuner with room bleed |
| D | Electric + Singing | Artist | Recording, takes, journal, mic permission |
| E | Afro guitar | Guitar teacher | Routines, planner, exercise authoring |
| F | Electric | Hobbyist | **Held out.** Cold unassisted core path |
| G | Not sure | Not sure | **Held out.** Absolute-beginner read |
| H | Bass | Hobbyist | The whole bass axis |

**Read of the cohort.** Only one teacher, and three self-described artists. Per the release
cohort strategy, teachers are the hope but bedroom and intermediate players are the reality —
which makes **F, G and H the closest proxies to the actual target user**, and the group whose
silence would be most costly to misread. Weight their experience accordingly; do not let the
three artists' fluency stand in for the median user's.

**Risks in the cohort, named up front:**

- **H is the only bass tester.** The entire ADR 0116 multi-instrument axis rests on one
  person. If H drops out, bass ships untested. Consider recruiting a ninth.
- **A (piano) and D (singing) are partly out of scope.** The app is guitar and bass. Their
  value is the *musician-who-isn't-a-guitarist* read on language and framing, not feature
  coverage. Tell them that at the outset so they don't spend their goodwill hunting for
  piano support.
- **G is unscreened.** "Not sure" on both axes. C0 decides whether G is an
  absolute-beginner read or not a guitarist at all — a different, still useful, but much
  narrower contribution.
- **E plays Afro guitar, and the ADR 0113 intake genre chips contain no Afrobeats or African
  genres** (Rock, Blues, Pop, Folk/Acoustic, Jazz, Funk/Soul, R&B/Neo-soul, Metal,
  Singer-songwriter). This is a predicted finding, not a hypothetical. Watch whether it reads
  as an oversight or as exclusion; the two call for different fixes.

---

## Three weeks, three themes

- **Week 1 — the loop.** Import → mark → loop. Tests ADR 0149 directly.
- **Week 2 — build something.** The exercise templates. Tests authoring.
- **Week 3 — let it plan.** Goals and generated sessions. Tests the planner.

---

## The build, and what to tell testers it is

The round runs on **1.2 (4)**. `fastlane beta` sets the build number itself from
`latest_testflight_build_number + 1`, so the value committed in `project.yml` is a record of where
the cut was taken, not what ships.

**"What to Test" is the only per-build message testers actually read**, and the lane takes it from
`BETA_WHATS_NEW` rather than baking it in — so it changes without a commit, and so it has nowhere
else to live. Week 1's copy:

```
This is the first build. Don't go looking for the new bits — there's nothing here
you've seen before.

One thing this week: get a song in, find the bar that beats you, and loop it slow.
The guide walks you through it. Everything else can wait.

If you get stuck, stop and tell me where. That's the part I need.
```

Keep it to a mission, not a changelog. A changelog invites testers to audit features; a mission
sends them at the one path the week is measuring.

## C0 — Screening, before any build goes out

A short form. Five items, each of which changes what we can conclude:

1. **Device model and iOS version.** 17+ required.
2. **Instrument, and do you consider yourself a guitarist at all?** G's gate.
3. **Do you own any audio files — not streaming — that you could put on your phone?**
   The single biggest risk to the round. A fresh install has no song (ADR 0148 §7) and
   streaming audio cannot be used (ADR 0001), so a tester with no files cannot reach the
   core loop at all. Testers answering no get the starter track — *Binta*, served from the
   guide at `/redmoon/beta/starter-track.m4a` — and a nudge to record thirty seconds of
   themselves.
4. ~~**Is Mail set up on your iPhone?**~~ **Retired 2026-08-12.** ADR 0161 replaced the
   `mailto:` row with an in-app form that sends with or without Mail configured, so the
   answer no longer changes what a tester can do or how they can reach us. Left in place
   rather than deleted because both this plan and the guide used to route around it, and
   the absence of the question would otherwise read as an oversight.
5. **What country is your App Store account in?** Determines whether they are ever asked
   about analytics, and therefore whether they emit anything at all.

---

## C1 — Day 0, the highest-value artifact

**Ask for a fifteen-minute iOS screen recording, microphone on, thinking aloud, from first
launch.** This is the closest remote substitute for sitting beside someone, and the only way
to see the hesitation *before* a tap — which is precisely what an onboarding flow exists to
remove. F and G record **before** receiving the guide; everyone else records with it open.

Then six questions, no more:

1. What did you think this app was for, before you opened it?
2. What was the first thing you tried to do?
3. Where did you get stuck, and what did you try next?
4. What did you expect to happen that didn't?
5. Did you get a loop playing? Roughly how long did it take?
6. *(Open)* Anything you want to say about the first fifteen minutes.

---

## C2 — Day 7, the templates and the hidden gestures

### Exercise authoring

`ExerciseTemplate` (`Pocket/Core/Models/ExerciseTemplate.swift`) has fourteen cases: basic,
strumming, scales, arpeggios, chords, strumChords, picking, legato, fingerstyle, rhythm,
warmup, earTraining, theory, freeform. The first-run seed exercises only five of them, so
**nine templates ship with no example to look at** — a tester meets an empty authoring
surface or never opens it.

**H sees a different menu.** Since ADR 0164, a bass drill is offered twelve templates, not
fourteen — Strumming and Chords & Strum are withheld, because a down/up strum lane isn't a
bass technique — and the Chords editor draws a four-string box with a bassist's vocabulary
(roots and fifths, octaves, the major and minor tenth, two shells) rather than the guitar
catalogue. The instrument is now chosen on the creation screen itself (ADR 0116 S7), with
Settings ▸ You only setting the default. **Two things to watch with H specifically:** whether
they notice the instrument control at all, and whether the withheld templates read as *absent*
or as *broken*. A tester who wanted to build a strum drill and found no such option may not
conclude it was deliberate.

Everyone authors **one Scale exercise and one Chord progression**, plus their lane's
template. Three questions each:

1. **Where did you stop?** Not "was it easy" — the abandon point is the finding.
2. **Did what you built match what was in your head?** The real question for scales and
   chords, because two deliberate design decisions cut across player expectations:
   - Scale positions are labelled by **root anchor**, with CAGED demoted (ADR 0091). A player
     taught CAGED may not find their shape.
   - Notes are spelled **key-first** via the parent major, with sharp/flat preference only a
     tiebreaker (ADR 0123). A player expecting a fixed preference may see a spelling they'd
     call wrong.
   Both are correct decisions. Whether they are *legible* is the open question.
3. **Would you build a second one?** A tester who authors once and never again has told you
   the template is a demo, not a tool.

Weight the answers: **E's** view on whether these express what they'd actually set a student
is the single highest-value opinion in the round. **A** catches imprecise theory language
nobody else will. **H** tells us whether the scale and picking editors behave on four
strings. **C** lives in Strumming and Chords & Strum.

### Hidden gestures

The app has roughly sixteen interactions with **no visual affordance** — all documented in
**section 4** of the guide, all following one house rule (a 0.4-second hold). One of them is
new since this plan was written: ADR 0163 put the song player's four display switches behind
a hold on the **"Loop controls"** status line, where a tap shows the gesture cheatsheet. That
one is worth asking about specifically — it is the newest hold in the app and the only one
whose tap and hold do entirely different jobs. Ask which ones each tester found **on their
own**, before the guide told them. Anything nobody found unaided is a
candidate for a visible affordance, and that count is worth more than any opinion they could
offer about it. The held-out pair's answers are the only truly clean data here.

### Confusion log

Running all week, freeform, low ceremony: one line every time the app didn't do what they
expected. The per-step "It didn't do that" button in the guide feeds the same pool, captured
at the moment of confusion rather than recalled a week later.

---

## C3 — Day 21, the planner and retention

### Know the mechanism before writing the questions

Three properties of the planner will generate complaints that are **by design**, and
misreading them as bugs would send us chasing the wrong fix.

The ranking is one formula (`Pocket/Core/Planner/DueScore.swift`):

```
dueScore = goalWeight × dueness(lastPracticed) × (1 − mastery/5)
```

Goals are a **closed set of four** (`Pocket/Core/Planner/GoalTemplate.swift`) — *Play a
specific song*, *Build speed*, *Improvise in a style*, *General progress* — each pre-seeding
skill IDs the player trims, with Low/Normal/High priority mapping to weights 0.5/1.0/2.0.
Goals are not free text.

1. **Taste tilts, it never filters.** `PracticeEmphasis` is lift-only and capped: a genre
   match multiplies by 1.35, and the cap sits deliberately *below* a High goal's 2.0, so a
   stated goal always outranks declared taste. A tester who picks Blues at intake and gets a
   mixed session will say *the planner ignored what I told it*. It didn't; it weighted it.
   **So don't ask "did it match your goals."** Ask **"what did you expect to see, and what did
   you get?"** The gap between those two is the finding, and it may well be that the design is
   right and only the communication is missing.
2. **Mastery 5 retires an item completely.** The `(1 − 5/5)` term is zero and nothing
   auto-decays it (ADR 0070 — the app never silently changes a number the player set). Rate
   your best exercise 5 and you will never be offered it again. A tester who does this will
   reasonably report *"it only ever gives me the things I'm bad at."* Ask directly whether
   anyone hit this, and whether they understood why.
3. **The pool is their own library, and it starts at six.** A generated Quick session on a
   fresh install is three of your six seeded exercises. **The planner cannot look good on a
   six-item library.** This is why Week 3 comes last and why Week 2 asks everyone to author.
   E is the only tester likely to build real depth — weight their planner read as the one
   about ranking quality, and treat everyone else's as a read on *expectations*.

### Questions

1. Set a goal, generate a session, and start it. What did you expect to see, and what did you
   get?
2. Was there anything in it you'd have taken out? Anything missing you expected?
3. Did you ever wonder *why* a particular item was in there? Could you find out?
4. Did anything stop appearing that you wanted back?
5. What do you still open? What did you stop using, and when?
6. *(Open)* Anything else.

**Question 3 carries the most weight.** If a generated session offers no reason and no swap,
then "it doesn't capture my goals" is a **transparency** problem rather than a **ranking**
problem — and those have very different, very differently-priced fixes. Establishing which
one it is is a primary output of this round.

Pinned planner behaviour lives in `PocketTests/DueScoreTests.swift`,
`SessionBuilderTests.swift`, `PracticeEmphasisTests.swift` and `GoalPriorityTests.swift`. If
the round says the weighting is wrong, those tests are where the correction lands.

---

## The held-out pair

F and G install with no guide. They record their first fifteen minutes cold, then receive the
guide at **48 hours** — capped, so a stalled tester doesn't simply churn.

Every place a guided tester sailed past and an unguided one stopped is a place **the app must
teach itself**. That list, and not any opinion collected in this round, is the specification
for ADR 0149.

---

## Question design rules

- Never *"would you use this"* — ask *"when did you last open it, and what made you stop."*
- Never *"do you like X"* — ask *"what did you do the last time you practised."*
- No 1–5 scales.
- One open question per checkpoint, no more. Open questions are expensive to answer and
  testers ration their goodwill.
- Never ask a tester to evaluate a design decision. Ask what they did and what they expected.

---

## Triage

On close, triage into `docs/backlog.md` in the format the two prior passes established
(2026-07-20 and 2026-07-28): a header stating volume and medium, a **decisions taken at
triage** block, a **scrapped, with reasons** block, then slices sequenced
cheapest-and-safest-first, each carrying a *notes worth carrying forward* sub-list. Detail
lives in the owning backlog section; the pass section is an index with cross-references.

Individual notes leave a permanent trace in the source as doc comments, matching the existing
convention: `// beta feedback 2026-08 #N`.

---

## Exit criteria

- [ ] All testers have completed C0 screening.
- [ ] C1 recordings received from at least six, including both held-out testers.
- [ ] Install→first-loop time recorded for everyone who reached one; **unaided fraction
      known**.
- [ ] Every tester has authored at least one Scale and one Chord exercise, with the abandon
      point recorded if they didn't finish.
- [ ] Gesture-discovery counts recorded — specifically which holds nobody found unaided.
- [ ] At least three testers have generated a session *after* building beyond the seeded six,
      so the planner is judged on a fair pool.
- [ ] Known whether "the planner missed my goals" is a ranking problem or a transparency
      problem.
- [ ] Triage written into `docs/backlog.md` in the established pass format.
- [ ] ADR 0149 revisited — steps confirmed or corrected against the recordings, and moved
      from Proposed toward Accepted.
- [ ] **The TestFlight Pro grant removed before the next App Store submission.** It is a
      Release-build entitlement path; a `TODO(beta)` marker in
      `Pocket/Core/Monetization/StoreManager.swift` exists so a grep finds it.
