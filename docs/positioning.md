# Positioning

*Written 2026-08-16. Competitor roster gathered 2026-08-16 from vendor sites and App
Store listings — pricing and features move; re-date this section if you refresh it.*

This is the differentiation argument the repo has never written down, plus the audit
that answers the harder question: **are the shipped surfaces actually saying it?**
(They are not, yet — §7.)

---

## 0. The line (2026-10-24, ADR 0276)

The sections below argue the position from the market. This one states it in the player's words,
and every surface should be able to be traced back to it.

> **Red Moon is a practice studio for songs you own. Your practice adds up instead of starting over,
> and it works alongside whatever you already learn from.**

Two ideas carry it, and they are one claim seen from two sides:

- **Practice that adds up.** The loop you saved yesterday is a block in today's session; the
  tempo you reached is where you start; the note you wrote is on the loop it was about. Nothing resets
  when the app closes. This is the *benefit*, and the answer to "why not just a slow-downer".
- **It complements your other sources.** A video, a teacher, a course stays where it is (§1, the
  multiplier thesis; ADR 0167's references). This is the *posture*, and the reason it never shames you
  for jumping between them (§3).

**The word is studio, not room** (ADR 0276). A studio is a place with equipment, where you work on
something over time. Never "tutor", "coach" or "teacher", which promise judgement (§3), and never
"studio" alone, which reads as a recording app: it is always *practice studio*.

Everything below keeps its argument. Where it says *practice room*, read *practice studio*.

---

## 1. The multiplier thesis

We do not own the material and we do not own the method. Somebody else wrote the song;
somebody else — a YouTube lesson, a teacher, a course, a tab site — is teaching it.

**We own what happens between opening a resource and being able to play the thing.**

`PROJECT.md:9` already states the narrow version of this — *"an intelligence layer over
the library — it never replaces it"* — but says it about the player's **music**. The
multiplier thesis generalises it to their **learning sources**. Same restraint, wider
target: we reinforce whatever you already learn from, and never ask you to move it
here.

This is a real constraint, not a slogan. It is why ADR 0001 chose local DRM-free files
over becoming a catalogue, why ADR 0092 forbids sending audio anywhere, and why ADR
0167 points *out* at the source rather than rendering it.

## 2. The competitor roster

The first time this repo names anyone. Three cohorts.

| Cohort | Who | Have | Lack |
|---|---|---|---|
| **Audio transformation** | Moises · Anytune · Capo · Amazing Slow Downer · Audipo · Soundslice · Songsterr · Chordify | Slow-down, pitch-hold, stems, notation sync | No session, no routine, no history |
| **Practice organisers** | **AxeLog** · **Captrice** · Guitar Practice Planner & Log · Modacity · Practis · Instrumentive · Andante · OpenFret · Riff Quest | Routines, templates, logs, streaks, tempo progression | No audio engine on the player's own files |
| **Lesson platforms** | Justin Guitar · Fender Play · Yousician · Rocksmith | Curriculum, grading, a path | Not rivals — these are the **resources a multiplier multiplies** |

Sources, one per name that matters:

- Moises — `moises.ai` · Anytune — `anytune.us` · Capo — `supermegaultragroovy.com/products/capo`
- Amazing Slow Downer — `ronimusic.com` · Audipo — `audipo.amuse-net.com` (already cited in ADR 0001)
- Soundslice — `soundslice.com` · Songsterr — `songsterr.com` · Chordify — `chordify.net`
- Modacity — `modacity.co` · Practis — `practisapp.com` · Andante — `andanteapp.com`
- OpenFret — `openfret.com` · Riff Quest — `riffquest.com`
- Justin Guitar — `justinguitar.com` (ships a 10-minute Daily Practice Routine) ·
  Fender Play — `fender.com/play` · Yousician — `yousician.com` · Rocksmith — `rocksmith.com`

### 2a. Captrice — the one that already ships our position

`captrice.io`. **Free**, browser-based, local data. Describes itself as *"a deliberate
practice app for guitar players"*. It has an exercise repository and collections, it
**embeds tab and notation inside an exercise for quick reference**, and it **loops a
marked section of a YouTube video at an adjustable playback rate**.

That is the multiplier position *and* the substance of ADR 0167, shipping today, at £0.
Any argument that starts "nobody else connects practice to where you learned it" is
already false.

Its limits are precisely our opening: **YouTube-only.** No waveform, no markers, no
takes, no ramp against a click — nothing that works on your own recordings, or on a
song you own but nobody has posted a lesson for. Browser-based; sync is "coming soon".

### 2b. AxeLog — the one that grades you

iOS, $39.99/yr, 4.8★
(`apps.apple.com/us/app/axelog-guitar-practice-tracker/id6758068428`). 100+ exercises,
20+ routines, AI-generated plans from a skill profile, per-exercise BPM logging, a
12-week heatmap.

Two things follow from it:

1. **It self-rates and issues an "AI Report" in persona voices.** The closest routine
   competitor in the market *grades the player*. That turns ADR 0070 from a private
   abstinence into a stated difference (§3).
2. **It ships the routine history we don't** — the highest-value gap in
   `docs/backlog.md`, and one we wrote down only after looking at the market.

## 3. No shame — the principle nothing has articulated

We do not shame the player for jumping from YouTube video to video, or from resource to
resource. **That jumping is not the failure.** The failure is the absence of a frame to
catch what you find.

The competitor move is *"you are scattered, we will fix you"*. Ours is *"scattered is
normal — here is what makes it add up."*

This is already half-built and wholly unstated:

- **ADR 0070** says the app never grades your *playing*. This extends it one level up:
  it never grades your *learning habits* either.
- **`scripts/check-manual.py` C7** (`:423`, `:426`) fails the build if `streak` or
  `this year` appears on any published manual page. **A tooling guard has been
  enforcing the no-guilt stance for months, and it was never written down as a value.**
- The story page's creed already carries the playing half: *"There's no score here…
  The app will never tell you you're wrong — because you're the one listening."*
- The contrast is concrete and it is the loudest end of the market: **AxeLog** ships
  streaks, a 12-week heatmap and an AI report in persona voices; **Yousician** ships
  levels and streaks.

**This is what makes ADR 0167 a hero feature rather than a nice-to-have.** A reference
link is the app saying *keep using YouTube — we will hold the thread.*

Written up as a voice/tone principle in `docs/design-brief.md` §3.5, which had no
voice/tone section at all despite `docs/backlog.md:2650-2656` naming that as where the
musician-voice principle belongs *"when acted on… and should then govern copy
app-wide."* This is the moment it is acted on.

## 4. Progressive disclosure — the cost of holding both ends

Sitting at the intersection of two categories means carrying the surface area of both,
and a new player meets all of it at once. The games analogy holds: games gate mechanics
behind progression rather than presenting the whole verb set on level 1.

**The app already does this in exactly one place and has never generalised it.**
`hasEarnedAName` (`Pocket/Features/Home/HomeView+ProfileMoment.swift:50-52`) withholds
the artist-name invitation until the player has completed an exercise or captured a
loop — a genuine behaviour-gated reveal, shipping today.

Related restraints, each decided in isolation and never named as one idea: ADR 0149's
behaviour trigger (*"guidance should behave like a competent person noticing you are
stuck, not a tour that fires because you are new"*), `RoutinePresets` shipping **one**
routine *"shown whole, rather than a library to wade through"*, ADR 0162 collapsing
Settings from 13 sections to 9, ADR 0145 making help something you look up.

So the pattern is real but **ad hoc**. There is no model anywhere of what this player
has met yet. Two tensions constrain any future design, and both are recorded here
because they are easy to forget:

- **It fights §3 if done wrong.** Gating on *achievement* re-introduces the judgement
  no-shame rejects. The resolution: **reveal by relevance and behaviour, never by
  permission or attainment.** Never lock a feature — just don't lead with it.
  `hasEarnedAName` passes that test; a level system would not.
- **It fights the trial clock.** The trial is one month (ADR 0144). Drip-feed too
  slowly and it expires before the player meets the feature that would have converted
  them. Any reveal schedule has a hard commercial bound.

**Deliberately not an ADR yet.** An ADR for "we should drip-feed" with no mechanism is
the over-engineering ADR 0149 §9 warns against. It becomes worth writing when there is
a concrete proposal; the likeliest first one is generalising `hasEarnedAName` into a
small derived "what has this player met?" read over existing data, needing no new
schema. Parked in `docs/backlog.md` under Routines & disclosure.

## 5. Why routines still carry it — with the caveat

A routine is the only object modelling a *session over time*. That matters, and it is
also **table stakes in cohort 2** — nine organisers ship it and AxeLog ships it better
in places.

What is rare is a routine whose blocks **run a real audio engine over your own files**.
The existing fragments already argue this and were never gathered:

- **ADR 0001** — local DRM-free files. The wall that is also the moat: no competitor in
  cohort 1 practises *your* recording of the thing.
- **ADR 0066 / 0071** — the routine conducts existing engines rather than
  reimplementing them. That is why a block can be a real loop and not a checklist item.
- **ADR 0139** — off-instrument practice, a block type no tracker models.
- **ADR 0070** — no grading, now pointed at AxeLog by name.

**Never claim "we have routines".** Nine other apps have routines. Claim both ends.

## 6. The layered position

| Layer | The line |
|---|---|
| **Acquisition** (App Store search) | **Stays** loop / slow-downer keywords. *"Slow downer"* is a real query with real volume; *"practice routine app"* is not. Do not trade a working keyword for a positioning statement. |
| **Product framing** (landing page, story, in-app, manual) | The intersection: **the practice studio that runs on your own recordings, and adds up.** |
| **Retention** | The routine — the thing that makes the second week look like the first. |

The claim everywhere is **both ends**. Pocket is the only app holding a session
conductor and a real audio engine over the player's own DRM-free files at the same
time. The organisers have no engine. The audio apps model no session. Neither half is
defensible alone, which is exactly why the position is the intersection and not a
feature list.

## 7. The contradiction audit

*Written 2026-08-16 as a list of live contradictions; re-audited 2026-10-24 against the tree. Most
of it has since been fixed, which is why this is now a status table.*

| Surface | Status | Note |
|---|---|---|
| In-app FAQ, *"What is Red Moon?"* and *"Where do I start?"* (`Pocket/Core/Help/FAQEntry.swift`) | **Fixed** | Both-ends framing since 1ab4ff2; 2026-10-24 adds *studio*, *adds up* and the complements-your-sources line. The first question was *"What is Red Moon Practice?"* until the store rename (ADR 0278); `check-manual.py` C3 holds the manual's citation to it, and `ManualToolkitShots` matches the question and the answer's opening words. |
| Manual, `getting-started` | **Fixed** 2026-10-24 | Opening now says *adds up* and states the complements-your-sources posture. The closing line *"the loop is the app. Everything else is a way of doing more of it"* — the last loop-first sentence in the manual — is replaced: the loop is the first move, not the thesis. |
| Manual spine (`docs/manual/README.md`) | **Fixed** | Grouped under the two halves since 2026-08-17; its own note already says *first* is about sequence, never about which half matters. |
| App Store subtitle | **No change, by design** | *"Loop, slow down, learn songs"* is the acquisition layer (§6). |
| App Store description | **Fixed** 2026-10-24 | Opens on the studio and on *tomorrow starts where today stopped*. Its pricing lines were also stale (they said free; ADR 0256 reversed that); the file's banner says what is history. |
| Beta guide (`docs/beta/user-guide.md`) | **Fixed** 2026-10-24 | It said *"Everything else in the app exists to support that"* of the loop. |
| Onboarding (ADR 0149) | **Open, not re-checked** | *"We are choosing not to teach exercises, routines, or the planner this way."* Proposal stands: a deferred fourth beat at the second session, where the saved loop becomes a block. Not in the first ninety seconds. |
| Landing page | **Open — separate repo** | Auto-deploys on every push; not touched from here. Needs: *studio*, *adds up*, and a routines/memory card (it has six feature cards and none for either). `docs/site/index.html` here is a stale local copy, re-worded only so the vocabulary doesn't drift. |
| Story page | **Open — separate repo** | Closest to the position already. |
| Price | **Fixed in the listing copy; verify elsewhere** | ADR 0256 (one plan) superseded ADR 0237 (free). Anywhere still saying *free* or *nothing to buy* is wrong. |

## 8. Who this is for

`docs/design-brief.md:20` carries the only audience line in the repo, and it is one
clause: *"guitarists who think seriously about practice."* Promoted here:

**The self-taught player who has already tried and abandoned a practice schedule.** They
own their material, learn from four places at once, and have a folder of half-learned
songs. They have tried an organiser and felt judged by it; they have tried a slow-downer
and it forgot everything the moment they closed it. They do not want a curriculum —
they want the thing they already do to add up.

That is who the story page is written by and for, and the no-shame principle is what
they respond to. Note what it excludes: beginners with no material of their own (ADR
0001 makes the app nearly empty for them), and players wanting to be told what to
practise (AxeLog and Yousician serve them better, deliberately).

## 9. Considered and rejected

- **Re-opening `AccessPolicy.freeTasteRoutineSlugs`** (empty,
  `Pocket/Core/Monetization/AccessPolicy.swift:115`) to make Morning Routine free
  forever, as a way to demonstrate the routine half before purchase. **Rejected.** ADR
  0144 deliberately made that seam inert — one app, one price — and a free month
  already covers the demonstration. Recorded so it is not re-raised.
- **Competing on features.** The differentiation argument was previously being made
  from features, which is the one axis where Moises and Soundslice win. Dropped in
  favour of the intersection.
- **"Routines are our differentiator."** Dead as of 2026-08-16. Nine organisers ship
  routines; one of them ships them free.
