# ADR 0158 — the app arrives with a song

- **Status:** **PARKED 2026-08-11**, the day it was written and before anything was built. See *Parked* below for what it would take to revive it, and for the two parts that were lifted out and kept.
- **Date:** 2026-08-11
- **Would reverse:** ADR 0148 §7 (the bundled demo song was dropped). ADR 0148's *mechanism* — songs are copied into the container, not bookmarked — stands untouched either way.
- **Would reopen:** ADR 0144 D3's free-taste seam, on a **new third axis** — see §4 for why this is not the one-file change D3 promised
- **Relates to:** ADR 0001 (local audio only) · ADR 0112 (gate at read time) · ADR 0041 (the A/B span)

## Parked

**The demo song is not coming back for now** (decision, 2026-08-11). Everything below was written
before that call and is left intact, because the analysis is the expensive part and none of it is
wrong — it is simply not being acted on.

**Two parts did not depend on the demo song, and have been lifted out into ADR 0149 as a dated
amendment rather than left to sleep here:**

- **§3's narrowing** — the walkthrough is three beats on the waveform (loop it, slow it, keep it),
  not a three-step practice method, and §3's four-item checklist goes with it. The argument for
  shortening never rested on there being a demo song; it rested on a first run being the wrong place
  to teach a method.
- **§5's tips page** — the long-form method moves to the public website, drafted by
  `docs/beta/user-guide.md`.

**What is parked with this ADR:** §1 (bundling and copying the song), §2 (the first-launch trigger),
and §4 (the free song axis). **ADR 0149 §2's first-import trigger therefore stands unchanged** — with
no song at launch, its original reasoning returns in full and was never contradicted by anything
except the demo song's existence.

**What would need to be true to revive it:** a decision that the cold-start problem — a player with
no DRM-free audio meeting a practice app they cannot practise with — is worth ~2.6 MB in every
download and a new free-taste axis in `AccessPolicy`. Nothing about that calculation has changed;
it simply wasn't taken.

**Two findings below survive independently and are already recorded elsewhere**, so they are not
lost with this ADR: ADR 0148 §7's content-rights justification was factually wrong (corrected in
0148), and ADR 0149 §10's marker-auto-naming prerequisite never existed (corrected in 0149).

## Context

ADR 0148 §7 removed the one song the app shipped with, and the library has started empty ever
since. ADR 0149 then built its entire trigger decision on that emptiness: guidance fires on the
first successful *import*, because "the library ships with no song at all… so step 1 is literally
impossible at first launch."

Two things have changed since.

**The stated reasons for removing it do not hold up.** §7 gave four. One was factually wrong and
has already been corrected in that ADR: the track was never third-party content, so there was no
Content Rights declaration to carry and no permission to keep straight — it is the author's own
composition. A second is now moot: §7 objected to "a second code path holding a bookmark to a
file — the very mechanism this ADR exists to retire", but ADR 0148 *itself* replaced bookmarking
with **copying into the container** via `SongFileStore`. A bundled song copies down that same
path on first run. There is no second mechanism and no bookmark.

Two reasons survive, and this ADR has to answer them rather than pretend they went away: **~2.6 MB
in every download**, and **every player receives a song they did not choose**.

**The cold start is the app's worst moment.** A player who installs Red Moon, has no DRM-free
audio to hand, and cannot use their streaming library (ADR 0001) meets a practice app they cannot
practise with. Every route to the centre of the product runs through a file they may not have.
The closed-beta plan had to add a starter-track download to work around exactly this
(`docs/plans/beta-testing-plan.md`), which is a strong signal that the empty library is not a
neutral default.

**And the song is ours in a way that matters.** It carries its influences openly — Frank Ocean,
John Mayer — but it was written and recorded by the author. A demo track is normally filler. This
one is a statement about what the app is for: practising music somebody actually made.

## Decision

### 1. The app ships with the demo song again, and it is copied, not bookmarked

The track is bundled and copied into the container on first run through the existing
`SongFileStore` path — the same code an imported song takes. No bookmark, no second file-access
mechanism, nothing for ADR 0148's sweep to treat specially.

On the two surviving objections from §7:

- **The 2.6 MB is accepted**, knowingly, as the price of the app being usable on first launch by
  someone with no audio of their own. Encode it as economically as the material allows; do not
  ship a lossless master.
- **"A song they didn't choose" is answered by it being a demo, not a fixture.** It is
  deletable like any other song, it holds no privileged position in the library, and nothing
  breaks when it is gone. The failure mode §7 feared — every player's library looking identical —
  only bites if the song is permanent. It isn't.

### 2. Guidance fires at first launch, on the demo song

**This reverses ADR 0149 §2.** That section chose the first-import trigger and named the reason:
there was nothing to guide before then. With a song guaranteed present from launch, the
constraint is gone, and the argument §2 made against an install-time trigger goes with it.

The division of labour §2 drew — *"getting the first song in is the empty state's problem, knowing
what to do with it is the flow's problem"* — collapses into one problem with one answer, because
the first song is now already there.

ADR 0149 §4 survives unchanged: the flow is **offered** to players who report substantial
experience on the intake's "Where are you with the guitar?" question and **started** for everyone
else, dismissible at every step, and dismissal stays permanent and silent.

### 3. The walkthrough is short, and it is about the waveform screen

**This narrows ADR 0149 §1.** The three-step method — listen whole, mark sections, create loops —
is a *practice method*, and a first launch is the wrong place to teach one. What a new player
needs first is to see what this screen can do.

The walkthrough is therefore three beats on the waveform screen, and ends:

1. **Loop it.** Tap Loop at the start of a passage, tap Loop again at the end. The span closes and
   repeats immediately (ADR 0041). This is the centre of the app and the only step that is not
   negotiable.
2. **Slow it down.** Take the speed to roughly half. Pitch is held.
3. **Keep it.** Save as loop, so the player leaves the walkthrough owning something.

**Markers are deliberately not in it.** They are the method's second step, not the screen's
headline capability, and every step spent is a step nearer to the "theme park ride" ADR 0149 §5
warns against. They belong on the tips page (§6).

ADR 0149 §3's four-item checklist goes with the long flow — three beats do not need a progress
indicator. §5's single ceremony at the first completed loop **stays**, and now lands on beat 3.

### 4. The demo song is free, and that needs a new axis

A walkthrough at first launch runs headlong into ADR 0144 D4: the Song library and the practice
screen are Pro-gated, so a brand-new player would be walked into a paywall mid-guidance. That
would be worse than no walkthrough at all.

So the demo song and its walkthrough are **free**. This is the free-taste line ADR 0144 D3
deliberately preserved a seam for — and D3's reasoning applies exactly: a player should be able to
reach the centre of the app before deciding whether to pay for it, which is also the strongest
trial pitch the product has.

**Be precise about the cost, though.** D3 promised a future free line would be "a one-file
change", and for exercises and routines it is: `freeTasteSlugs` and `freeTasteRoutineSlugs` are
sitting empty in `AccessPolicy` waiting to be filled. **There is no song axis.** Songs are gated at
the Home destinations (`HomeGate.library`, `HomeGate.song`), not through `AccessPolicy` at all. So
this is a *new* allowlist following the established pattern, plus a change at the Home gate to let
the demo through — small, and consistent with the seam's design, but not free and not one file.

Everything else stays locked. Free means *this song, on the practice screen*. Importing a second
song, the library at large, the planner, authoring and routines are all untouched.

### 5. The long-form method moves to the website

The three-step method ADR 0149 §1 described is good, and it is not lost — it becomes a public
**tips page** on the `.co.uk` site. The closed-beta guide already written
(`docs/beta/user-guide.md`) is its draft.

This is the right home for it: it can be long, it can be revised without a binary, and a player
reaches it when they want it rather than in their first ninety seconds. ADR 0149 §6's rule holds —
the in-app steps link out rather than explaining themselves inline.

### 6. ADR 0149 §10's prerequisite does not exist, because the thing already does

§10 states that markers do not name themselves on drop and that this must land first. **That is
incorrect.** `WaveformPracticeModel+Actions.dropMarkerAtPlayhead()` has called
`AutoName.next(prefix: "Marker", existing:)` since it was written, producing "Marker 1", "Marker
2", and the doc comment above it says so. Verified in the running app.

There is no prerequisite. Nothing blocks the walkthrough on this axis — and since §3 drops markers
from the walkthrough anyway, it is doubly moot.

## Consequences

**A fresh install is no longer empty**, and several surfaces that were written for an empty
library will now see one row on first launch: the library's own empty state, Home's "Jump back
in" card, and the count-aware library subtitle. None of these break; all of them should be looked
at on device, because each was designed for a case that is now rarer.

**The first-run sequence gains a step.** Intake → paywall → Home is now intake → paywall →
Home → walkthrough. That is three interruptions before a player has done anything, and the
walkthrough is the third. ADR 0156's paywall budget lands in the same release and should be
sequenced *before* this, so the wall it has to share a launch with is already the quieter one.

**Free means a real hole in the wall, and holes need watching.** ADR 0144 D3's own defence was
that the gates keep working behind D4 as defence in depth. That is what makes this safe: a player
who walks from the free demo song into the library or the planner still meets a gate. Test that
boundary specifically — walking *out* of the free song is exactly where a free line leaks.

**Existing installs are unaffected.** Seeding is idempotent per-seeder; a player who already has a
library does not need this song and should not be handed one. Gate the copy on a first-run flag,
not on "the library is empty" — a player who deleted everything is not a new player.

**The beta's starter-track download becomes a fallback.** It stops being a hard dependency the
moment this ships, which also unblocks the closed beta, currently waiting on that file.

**Not device-verified.** Nothing here is built. The copy-on-first-run path, the free-song gate and
the walkthrough all need device testing — and the free-song boundary needs it most.
