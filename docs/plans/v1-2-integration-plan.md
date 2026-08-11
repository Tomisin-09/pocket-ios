# v1.2 integration plan — the beta build and what rides in it

Written 2026-08-11 as a coordination pass, not an implementation. Four workstreams landed in
parallel and interact in ways none of them can see alone: three ADRs written in a concurrent
session (0155, 0156, 0157 — all **Proposed, all unbuilt**), the closed-beta programme
(`docs/plans/beta-testing-plan.md`), and a decision to bring the demo song back.

**Nothing here is built. Nothing is committed.** This exists so the session that does the
building starts with the interactions already worked out.

---

## Decisions taken this pass

- **The demo song comes back**, and it is the author's own composition — influences from Frank
  Ocean and John Mayer, but his. That provenance is the point: it speaks to what the product is
  for, in a way a licensed stock track never could.
- **The guided walkthrough fires at first launch, on the demo song.** This *reverses* ADR 0149
  §2, knowingly. §2 chose the first-import trigger because the library shipped empty and step 1
  was therefore impossible at launch; a guaranteed demo song removes that constraint entirely.
- **The walkthrough is short**, and it is **about the waveform screen** — the centre of the app —
  not the full three-step method. It shows a player what they can *do* on that screen.
- **The long-form method guide moves to the website** as a public tips page. The closed-beta
  guide already written (`docs/beta/user-guide.md`, ported to the unlisted beta route) is the
  draft of it.
- **Testers get lifetime access** as the thank-you. See the open question below — the app has no
  mechanism for this today.

---

## The four interactions that matter

**1. The demo song dissolves ADR 0148's own objection to it.** §7 removed the bundled song partly
for "a second code path holding a bookmark to a file — the very mechanism this ADR exists to
retire." That objection is dead: ADR 0148 *itself* established that songs are **copied into the
container** via `SongFileStore`. A bundled demo can be copied on first run down that same path,
with no bookmark and no second mechanism. Of §7's four stated reasons, one was factually wrong
(the content-rights burden — corrected in the ADR on 2026-08-09, the track was never
third-party), one is now moot (the bookmark), and two survive and must be answered honestly in
the new ADR: **~2.6 MB in every download**, and **every player gets the same song they didn't
choose**. The second is the real one, and the answer is that it is a *demo* — present to be
practised on and then ignored or deleted, not to be the player's library.

**2. ADR 0149 §10's prerequisite does not exist — the thing is already built.** §10 claimed markers
don't name themselves on drop and that it must land first. Wrong: `dropMarkerAtPlayhead()` has
always called `AutoName.next(prefix: "Marker", existing:)`. Confirmed in the running app, corrected
in 0149, and doubly moot now that ADR 0158 §3 drops markers from the walkthrough. **Nothing is
blocked on this.**

**3. The beta cannot validate ADR 0156.** Testers hold Pro (sandbox grant now, lifetime later),
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

### Slice 2 — the demo song, and the short waveform walkthrough
**ADR 0158, written.** The largest user-facing win and the one that unblocks the beta's cold start.
Build order:
1. The audio asset, bundled, copied to the container on first run through `SongFileStore`, gated on
   a first-run flag (**not** on "the library is empty" — someone who deleted everything is not a new
   player).
2. The free-song axis in `AccessPolicy` plus the Home-gate change (0158 §4). Do this *before* the
   walkthrough, or the walkthrough is untestable — it walks into a paywall.
3. The walkthrough: loop it, slow it, keep it.
4. Retire the beta guide's starter-track download to a fallback — it is currently a hard dependency
   on a file that does not exist.

**Sequence 0156 before this**, per 0158's consequences: first launch already spends an intake and a
paywall before the walkthrough gets its turn, and 0156 is what makes that wall the quieter one.

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
deliberately excluded (ADR 0158 §3). The long-form three-step method moves to a public tips page on
the website, drafted by `docs/beta/user-guide.md`.

**The demo song and its walkthrough are free** (ADR 0158 §4) — otherwise a first-launch walkthrough
walks a new player straight into ADR 0144 D4's paywall. This reopens D3's free-taste seam on a
**new song axis** that doesn't exist yet; `freeTasteSlugs` covers exercises, `freeTasteRoutineSlugs`
routines, and songs are gated at the Home destinations instead.

## Still open

**Nothing blocking.** The largest remaining unknown is how the free-song boundary behaves in
practice — walking *out* of the demo song into the library or planner is where a free line leaks,
and it needs device testing rather than a decision.

---

## Housekeeping

The concurrent session worked in **this same working tree, on branch
`pocket-250-beta-programme`**, so ADRs 0155–0157 and the beta programme are currently interleaved
as one uncommitted change set. They are cleanly separable — the ADRs are docs-only and touch no
file the beta work touches — but they should be committed as **separate commits**, and 0155–0157
arguably belong on their own branch, since they are decisions for v1.2 rather than part of the
beta programme.
