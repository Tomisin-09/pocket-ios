# ADR 0219 — a song before the wall

- **Status:** Accepted — **built** (2026-09-22, `pocket-323-the-free-taste-is-a-song`)
- **Date:** 2026-09-22
- **Amends:** ADR 0144 — D1's "every capability is `.pro`" gains its one exception: a single song,
  named by a frozen id (D5). D4's launch wall keeps its once-per-launch rule and gives up exactly
  one presentation (D7). D3's seam is untouched — both free-taste allowlists are still empty, and
  the exercise and routine lines do not move.
- **Amends:** ADR 0148 — §7's decision to drop the bundled demo song is reversed. Three of its four
  stated reasons no longer hold (D3, D2, D8); the fourth was already withdrawn by its own
  2026-08-09 correction. §1–§6 and §8 stand entirely: imports are still copied, not bookmarked, and
  the starter track is copied by the same call.
- **Amends:** ADR 0158 — unparked and superseded in substance. Its two surviving objections are
  answered rather than overruled (D2, D8), and its mechanism is not the one built here.
- **Amended by:** ADR 0220 — D1's "no loops **and no markers**" keeps only its first half. The
  starter track now arrives with two markers (*Chords start*, *Solo start*), a measured tempo (83)
  and downbeat (0.027 s), and grid lines on. It still arrives with **no loops**, for the reason D1
  gives. `StarterTrack.bpm` (104) was wrong and becomes 83. D2–D9 stand.
- **Relates to:** ADR 0011 (the auto-seed this does not reinstate, D2), ADR 0112 / ADR 0144 D4 (the
  wall this stands in front of), ADR 0149 (whose §2 trigger this makes fire — **unamended**, D3),
  ADR 0090 (why the destination is bool-bound), ADR 0001 (why a local file is the only option)
- **Schema:** none. No new entity, no new attribute, no migration. One `UserDefaults` key
  (`launchWallDeferred`) and one bundled resource.

---

## Context

A player who installs Red Moon today cannot open the part of it that matters.

The trial reads as a grace period and is not one. `StoreManager.resolveIsPro(entitled:debugOverride:)`
is `debugOverride ?? entitled`, and `debugProOverride` exists only under `#if DEBUG`. `trialEndsAt`
is read from a real StoreKit expiration and from nowhere else, so `TrialCountdownRow` draws nothing
until a subscription exists. **A fresh install is not "in trial" — it is simply not Pro**, and stays
that way until someone puts a card through the paywall.

What that install meets, in order: four intake questions (ADR 0113), a full-screen paywall (ADR 0144
D4), and a Home screen where **Practice**, **Song library**, **Today's session** and **Jump back in**
are all locked. Metronome, Journal and Toolkit are open, and none of them is what the app is for.

The closed-beta grant that had been papering over this was removed in full on 2026-09-10
(`7e42460`), ahead of the 1.3 submission, and 1.3 (7) was cut from `main` the same day. The
2026-08 round's finding — that testers "hardly interacted with the features" — was read for a month
as an onboarding problem. It is partly that. Underneath it is a locked door.

**No amount of guidance fixes a locked door**, which is why this ADR comes before the onboarding
work rather than inside it.

### Two things already in the repo make the fix small

**The practice screen is not gated.** `Pocket/Features/Waveform/` contains no `isPro`, no
`AccessPolicy` call and no `presentPaywall` anywhere. Looping, slowing and saving already work for
anyone who can reach the screen. Only the doors on Home are locked, so opening one door is the whole
change — no new free surface has to be designed.

**There is already a real song, and it is not the one in the code.** `Song.sample()` ships as
*"Slow Bend" by Jack Trader* with a generated arpeggio behind it (`SampleToneGenerator`), reachable
from **Try the demo** in the Library empty state — itself behind the Pro gate. It is a fabricated
metadata record that exists so previews, `ScreenshotSeed` and roughly twenty manual figures have
something stable to point at, and thirty seconds of synthesised arpeggio cannot carry *"loop the
part you want to play"*. ***Binta*** is a real eighty-one-second recording, the author's own
composition, already served to beta testers from the marketing site.

## Decision

### 1. One song ships, and it is Binta

*Binta* goes into the app bundle as `Pocket/Resources/Binta.m4a`. `StarterTrack` holds its identity
and metadata; the metadata mirrors `ScreenshotSeed`'s entry for the same recording so the track
reads identically wherever it appears.

It arrives with **no loops and no markers**. Making the first loop is the player's job — ADR 0149's
first beat — and a song that arrived pre-looped would answer the question the walkthrough exists to
ask.

### 2. It arrives by tap, never by seeding

Nothing inserts it at launch. The **Start here** card on Home adopts it on the first tap.

This is what answers ADR 0148 §7's "every player receives the same song, which none of them chose",
and it is why ADR 0011's retirement of the first-run auto-seed is left standing rather than reversed.
A player who never taps the card never acquires the song, and their library is as empty as it is
today.

### 3. It enters through the ordinary import path — there is no second audio path

`SongImporter.prepareStarterTrack()` calls **`SongFileStore.adopt(contentsOf:sourceID:)`**, the same
call every real import makes, and **`WaveformExtractor.extract`**, the same decode. The result goes
through the same `persist`. The starter track is *an import the app performs on the player's behalf*.

This is the load-bearing decision. ADR 0148 §7's strongest objection was "a second code path holding
a bookmark to a file — the very mechanism this ADR exists to retire". That objection does not survive
the file being adopted like any other import: there is one path, and 0148's own §2 resolution order
serves it unchanged.

It is also why **ADR 0149 §2 needs no amendment**. Its trigger is "the completion of the first
successful import", and tapping this card *is* one. The structural problem 0149 named — "at first
launch there is nothing to guide" — is what this ADR removes, without touching a word of its
decision.

`prepareStarterTrack` is a **sibling** of `prepare`, not a caller of it, for one reason: `prepare`
opens a security scope and a file inside our own bundle has none, so `startAccessingSecurityScopedResource()`
returns `false` and the import would throw `.accessDenied` every time.

One difference from `prepare` is deliberate. There, a failed copy does not fail the import — a song
that plays from its bookmark is worth more than no song. Here there is no bookmark to fall back on,
so a failed copy means a song that cannot play, and the throw is the honest answer.

### 4. It takes no bookmark

A security-scoped bookmark into the app bundle would resolve to a path that moves on every app
update. The track does not need one: it always has an owned copy, and `SongAudioResolver.resolve`
prefers the owned copy over a bookmark already.

This makes `bookmark == nil` mean one of two things where it used to mean one — the generated sample,
**or** the starter track. They are told apart by `audioFileName`, which the starter track has and the
sample does not. The test that actually matters, `Song.hasImportedAudio`, is
`audioFileName != nil || bookmark != nil` and was already correct; the stale doc comments on
`Song.sourceID` and `Song.ref` are corrected in this change.

### 5. One access axis, keyed on a frozen id

```swift
static func canPractiseSong(isPro: Bool, isStarterTrack: Bool) -> Bool { isPro || isStarterTrack }
```

`StarterTrack.sourceID` is `"starter-binta"` and is **frozen**: `SongFileStore` names the adopted
copy after it, and the gate reads it. Renaming it would orphan the file on disk and silently re-lock
the song for every player who already had it.

Keyed on the id and never the title, because `Song.title` is user-editable. A title-keyed gate fails
in both directions — a player could mint a free song by renaming one, or lose the starter track by
renaming it.

**One object, not a tier.** A second song, the library that lists it, Practice, routines and the
planner are all untouched. `freeTasteSlugs` and `freeTasteRoutineSlugs` stay empty, so ADR 0144 D3's
seam is exactly where it was and this does not reopen the exercise or routine lines.

### 6. The card is about emptiness, not entitlement

`HomeFeed.shouldOfferStarterTrack(totalSongs:hasStarterTrack:)` takes **no `isPro`**.

The obvious reading — this is the free taste, so the card belongs to non-Pro players — is wrong in a
way worth recording. Gating the card on entitlement would mean subscribing *removes* it, so a player
who bought Red Moon Pro halfway through the walkthrough would watch their starter song disappear
from Home mid-sentence. Entitlement is D5's question and stays narrow. The card's question is only
ever "is this library empty", which is as true of a subscriber as of anyone else — and a Pro player
with nothing imported is exactly as stuck.

The card sits **above** `Start today's session`, not below it. A player without Pro meets that CTA
as a lock; leading with it and putting the one thing they can actually do underneath would be the
screen arguing for the paywall before it has shown them anything. It retires the moment a song of
their own lands, and `resumeCard` takes the slot. The starter track exists to be outgrown.

**Two knock-ons on `Jump back in`, both found by walking the second session rather than the first.**
Practising the starter track makes it the `resumeTarget`, and neither default was right:

- Its card was **locked**, because `resumeCard`'s song branch reads `isPro` and ADR 0144 D4 gates it
  as a second door into the Song library. So Home offered a padlocked card for the one song the
  player had just spent twenty minutes inside. That branch now resolves `canPractiseSong` instead of
  `isPro`, which is the same call the entitlement axis makes — read it anywhere else and the two
  drift.
- It was **duplicated**: the starter-track card and the resume card sat stacked, same title, same
  artist. `duplicatesStarterTrackCard` suppresses the resume card while the starter-track card is
  showing the same song. The starter-track card wins because it carries the same practice state
  *and* the eyebrow that says why the song is there at all.

### 7. The launch wall defers exactly once

Dismissing the intake flips `artistIntakeSeen`, which fires `maybeShowLaunchWall()` in the same
session — so without this the first thing a new player met was still a full-screen wall, with Home's
one open door behind it. The first launch after the intake belongs to the starter track.

**One deferral, latched in `UserDefaults`, and deliberately not conditional on the card being
tapped.** A player who ignores the card must still meet the offer. A wall that waits for an action
the player may never take is a wall that can be avoided forever by doing nothing, which is not a
deferral — it is a deletion. Every launch after the first behaves exactly as ADR 0144 D4 specified.

### 8. The size objection, answered with a number

ADR 0148 §7 costed the bundled song at **2.6 MB in every download**, and that figure was real: the
source recording is 2.5 MB, eighty-one seconds of stereo AAC at 215 kbps.

It ships re-encoded at **128 kbps — 1,099,099 bytes, 1.05 MB**, a 58% reduction that is inaudible
for a practice reference track being looped and time-stretched. Stereo is kept.

The remaining megabyte is the one cost of this ADR that is real rather than dissolved, and it is
worth it: measured against an activation rate that is presently near zero for anyone who has not
subscribed, it is the cheapest megabyte in the binary.

### 9. `Song.sample()` stays exactly where it is

It is preview scaffolding, not a song. It backs 25+ previews, `ScreenshotSeed`, and about twenty
manual figures that navigate by its loop and marker names (`Verse riff`, `Chorus bend`,
`Intro turnaround`, `Tricky bend`). Nothing here replaces it, **Try the demo** is untouched, and the
two are easy to conflate and must not be — they have different audio, different provenance and
different entitlement. `StarterTrackTests` pins that they stay distinct.

## Consequences

- **ADR 0144's "one price, no free line" is no longer literally true**, and the ADR now says so. The
  defence is that this is one object rather than an axis: a player without Pro gets one song, no
  library, no drills, no routines and no planner. If that stops being true — if a second free song
  or a free routine appears — the honest description becomes "a free tier", and that is a different
  commercial decision that should be taken deliberately rather than arrived at.
- **A player can now finish the whole first-run walkthrough without paying.** That is the intent, and
  it is also the risk: the conversion argument moves from "you cannot use this" to "you have used
  this and want more than one song". That is a better argument, but it is unproven here.
- **The beta cohort is not fixed until this ships.** Testers on 1.3 (7) remain locked out, and there
  is no `betaDiagnostic` line left to ask them for — it was deleted with the grant. Until a build
  carrying this reaches them, the only route is the sandbox paywall.
  > ⚠ **Unverified, and it matters:** StoreKit's sandbox compresses subscription periods, so a
  > tester who *does* start the trial may lose it within minutes and then meet the launch wall on
  > every launch. That would match the 2026-08 round's symptom exactly and is plausibly why the
  > grant existed at all. Confirm on a real TestFlight build before drawing any conclusion from
  > tester reports.
- **The resource's presence cannot be unit-tested.** `PocketTests` is unhosted, so `Bundle.main`
  there is the xctest runner and `StarterTrack.bundledURL` is `nil` for reasons unrelated to whether
  the file shipped. A test asserting that would pass on a build that dropped the resource, which is
  worse than no test. It is covered by the build copying it into `Pocket.app` and by
  `prepareStarterTrack` throwing `.starterTrackMissing` rather than trapping. `StarterTrackTests`
  records why.
- **One more thing now depends on a frozen identifier.** `"starter-binta"` joins `Exercise.presetSlug`
  and `Routine.presetSlug` on the list of strings that cannot be renamed. It is pinned by a test that
  repeats the literal on purpose.
- **Home gained a card, so the manual's Home figures are stale.** Reshoots wait until the rest of the
  onboarding work is built rather than being taken per-slice.
