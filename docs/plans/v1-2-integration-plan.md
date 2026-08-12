# v1.2 integration plan — the beta build and what rides in it

Written 2026-08-11 as a coordination pass, not an implementation. Four workstreams landed in
parallel and interact in ways none of them can see alone: three ADRs written in a concurrent
session (0155, 0156, 0157 — all **Proposed, all unbuilt**), the closed-beta programme
(`docs/plans/beta-testing-plan.md`), and an amendment to ADR 0149's guided flow.

**Nothing here is built.** This exists so the session that does the building starts with the
interactions already worked out.

> **Revised the same day.** The first draft was written around bringing the demo song back. That was
> **parked** a few hours later (ADR 0158), and this plan has been rewritten to match. What survived
> the parking is the *narrowing* of ADR 0149's guided flow, which never depended on the demo song.

---

## Decisions taken this pass

- **The demo song stays out, for now.** ADR 0158 was written and parked the same day. Its analysis
  is intact and revivable; nothing is being built from it.
- **ADR 0149's trigger is unchanged** — guidance fires on the player's first successful import.
  With no song at launch, §2's original reasoning stands.
- **The walkthrough is short**, and it is **about the waveform screen** — the centre of the app —
  not the full three-step method. Three beats: loop it, slow it, keep it. It shows a player what
  they can *do* on that screen. §3's four-item checklist goes with the long flow.
- **The long-form method guide moves to the website** as a public tips page. The closed-beta
  guide already written (`docs/beta/user-guide.md`, ported to the unlisted beta route) is the
  draft of it.
- **Testers get hand-renewed offer codes**, not a lifetime product. Recorded in ADR 0144.

---

## The interactions that matter

**1. Parking the demo keeps the paywall out of the walkthrough.** This is the quiet virtue of ADR
0149 §2's original trigger, and it is worth naming because the alternative nearly cost a new axis in
`AccessPolicy`. A walkthrough at *first launch* would have walked a brand-new player straight into
ADR 0144 D4's wall, which forced ADR 0158 §4 to make the demo song free — and there is no song axis
in `AccessPolicy` to make it free *with*. Triggering on **import** sidesteps all of it: a player who
has reached the library is already in trial or subscribed, or they never got here. No free-taste
seam is reopened, and `freeTasteSlugs` stays empty.

**2. ADR 0149 §10's prerequisite does not exist — the thing is already built.** §10 claimed markers
don't name themselves on drop and that it must land first. Wrong: `dropMarkerAtPlayhead()` has
always called `AutoName.next(prefix: "Marker", existing:)`. Confirmed in the running app, corrected
in 0149, and doubly moot now that the walkthrough drops markers anyway. **Nothing is blocked on
this.**

**3. The beta cannot validate ADR 0156.** Testers hold Pro (sandbox grant now, offer codes later),
so `isPro` is `true`, so the launch wall and all ~18 gates are skipped by the same check. The
paywall-cadence question — *"I don't want users feeling like the next pop up is crawling around
the corner"* — gets **no tester data at all**. 0156 must be verified by the author on a sandbox
device against its own three rules. Recorded here so it isn't discovered late and mistaken for a
gap in the beta.

**4. ADR 0157 changes what every tester sees.** `exerciseAnimates` defaulting to **on** means the
walking highlight is visible the first time anyone runs a fretboard or strum drill. That lands
squarely on the beta's Week 2 template testing, and it is the cheapest item here. It should be in
the beta build or the Week 2 read is of the wrong app.

---

## Sequencing — cheapest and safest first

### Slice 1 — ADR 0157, the walk moves by default
Smallest change on the board: one default value that "lives in seven places, and all seven change
together", no schema, no new surface, an existing player's explicit choice preserved. Ships in the
beta build. **Also owed:** ADR 0131 §3a and ADR 0132 both *cite* the off default as a reason and
need correcting whichever way this goes — 0157 says so itself.

### Slice 2 — the short waveform walkthrough (ADR 0149, as amended)
**The demo song is parked** (ADR 0158, parked 2026-08-11 the day it was written). What survives is
the narrowing: guidance still fires on the player's **first successful import**, and the flow is
three beats on the waveform — loop it, slow it, keep it. No checklist, no markers, and the
long-form method goes to the website instead.

Build order:
1. The three beats, triggered from the first import. Everything they touch already exists — the A/B
   span (ADR 0041), the speed control, Save as loop.
2. §5's single ceremony on beat 3.
3. The public tips page on the `.co.uk` site, drafted by `docs/beta/user-guide.md`.

**No paywall interaction, and no free-song axis needed.** Because the trigger is an import, the
player has already reached the library — so they are either in trial, subscribed, or they never got
here. That was the quiet virtue of ADR 0149 §2's original trigger, and parking the demo restores it.

**Note what parking the demo costs the beta.** The starter-track download in the tester guide goes
back to being a **hard dependency on a file that does not exist yet** — it was going to become a
fallback once a demo song shipped. Supplying that track is once again on the critical path for the
closed beta.

### Slice 3 — ADR 0155, a note that belongs to no unit
Self-contained. `isStandalone: Bool?` is an **additive optional**, which the 2026-08-07 schema
freeze audit already established stays safe post-freeze — only retypes were now-or-never. Two
doors (Journal space and the Metronome, §8). One doc follow-on: the beta guide's Journal section
gains a line.

### Slice 4 — ADR 0156, a paywall you can predict
Largest surface — a pure policy type, persisted state, and wiring at `PaywallHost` plus ~18 gate
call sites. Last because it is the biggest and because, per interaction 3, no tester feedback is
coming to inform it. It supersedes ADR 0144 D4's "once per launch" clause narrowly; the rest of D4
stands.

---

## Settled since first draft (2026-08-11)

**Tester comp: hand-renewed offer codes.** Chosen over a non-consumable "lifetime" product, which
would reopen the one-price model ADR 0144 settled and add a permanent third product for eight
people. Recorded in 0144's consequences. Manual work every year, accepted deliberately. The
TestFlight sandbox grant covers the beta period, so nothing is needed now.

**The walkthrough's steps: loop it, slow it, keep it.** Three beats on the waveform screen, markers
deliberately excluded. Recorded as a dated amendment in ADR 0149, not in the parked 0158, so it
survives the demo song's absence. The long-form three-step method moves to a public tips page on the
website, drafted by `docs/beta/user-guide.md`.

**The demo song is parked** (ADR 0158). With guidance triggering on import rather than launch, no
free-taste seam is needed and `freeTasteSlugs` stays empty.

## Still open

~~**One thing, and it is on the critical path for the beta: the starter track.**~~ **Closed
2026-08-12.** The track exists: *Binta*, the user's own recording, committed to the site repo at
`public/redmoon/beta/starter-track.m4a` on branch `redmoon-beta-guide` and linked from the guide's
"About that file" section. It is about ninety seconds — short on purpose, and long enough to loop. A
tester with no DRM-free audio of their own can now reach the core loop.

**What is actually left is not in either repo.** Both remaining blockers are manual App Store
Connect work: create the **Closed Beta** group with its Beta App Review information, and confirm the
rejected 1.1 metadata submission does not hold up Beta App Review for the 1.2 build. Neither can be
done from here.

**Note on sequencing that was not obvious.** Slices 1 and 3 (ADRs 0157 and 0155) both shipped, but
slices 2 and 4 — the walkthrough and ADR 0156 — were **deferred past v1.2** rather than built in
order. The beta therefore runs on a build with neither, which is correct for slice 4 (interaction 3
above: testers hold Pro, so 0156 was never going to get tester data) and is the entire *point* for
slice 2 (0149 is unbuilt, and this round is the manual version of it that produces its spec).

---

## Housekeeping

ADRs 0155–0158 and the beta programme were written across two sessions in the same working tree and
landed together in **PR #235** (squash `72c4aac`), as three commits: the beta programme, two
corrections to the record, and the v1.2 decisions. `main` is the base for implementation.
