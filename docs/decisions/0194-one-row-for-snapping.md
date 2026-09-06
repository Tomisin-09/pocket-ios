# ADR 0194 — one row for snapping, and it does not flatten the gesture

- **Status:** Accepted
- **Date:** 2026-09-06 (`pocket-301-resume-and-snapping`)
- **Relates to:** narrows **ADR 0080**'s tap-vs-scrub candidate split without collapsing it; scoped
  to seeking, so **ADR 0099**'s neighbour-aware loop-edge yielding is untouched. Sources the
  candidates ADR 0021 and ADR 0022 established. Fifth control on the screen ADR 0162 D2 named and
  ADR 0163 gave a second door. Picked up from `docs/directions-2026-09.md` §5b / §6 Tier 1 item 3.
- **Schema:** none. One `UserDefaults` key, `seekSnapping`.

## Context

Snapping on the waveform is not one behaviour, and a plain on/off toggle would have made it one.

**ADR 0080 already split it.** A *tap* means "take me to that structure" and catches the full set —
markers, loop edges and beats. A *scrub* means "put the playhead exactly here" and drops the dense
beat grid, keeping only the sparse landmarks, so a deliberate drag between beats lands where the
finger lifts. `snapTolerance` scales with the viewport, so the catch zone stays a constant size on
screen at any zoom.

The question that decides the shape of the setting: do players want this because they **think in
time rather than structure** — a preference — or because they **cannot land it exactly** — a
precision problem, which wants a fine-adjust gesture and not a global switch?

The honest answer is that we have evidence for the first and none for the second. Nobody has
reported being unable to place the playhead; what the app has is a considered rule that suits most
songs and can be wrong for a particular one — a song with a dense grid where every tap lands on a
pulse whether you meant it or not. That is a preference, so it gets a preference, and the
fine-adjust gesture stays unbuilt until something asks for it.

## Decisions

### D1 — Three values, on one row

`SeekSnapping`: **`Structure and beat`** (today, and the default) · **`Structure only`** ·
**`Off`**, as `Snap when seeking` in `SongPlayerSettingsView`.

The middle value is the one that makes this worth doing: it makes a **tap** behave the way a scrub
always has, which is precisely the complaint a dense grid produces, and it is unreachable by any
on/off toggle.

**Rejected: a pile of toggles** — snap to markers, snap to beats, snap to loop edges. Three switches
for a thing that has three sensible states, and eight combinations of which five are nonsense.

**Rejected: on/off.** It flattens ADR 0080's distinction into the setting, and the flattened version
loses the case players actually hit.

### D2 — The mode narrows the gesture split; it does not replace it

`SeekSnapping.includesBeats(scrubbing:)` takes the **gesture**, and is not a stored flag. A scrub
drops the grid at every setting that snaps, because that is ADR 0080 and it stays true; the setting
decides only whether a *tap* also drops it. So the tap/scrub difference survives everywhere except
`Off`, where there is nothing left to differ about.

`seekSnapping(_:scrubbing:)` reads the mode straight off `AppSettings` at release, the way
`zoomFollowsPlayhead` is read at pinch. The two rules are pure and unit-tested on the enum; the
model's branch is those two rules and nothing else.

### D3 — Scope: seeking, on both surfaces that seek

⚠ **Loop editing is untouched.** `loopEdgeSnapTarget` and its ADR 0099 neighbour-aware yielding are
what stop a tight neighbour hijacking a handle; if `Off` reached them, loops would become hard to
place at all — a setting about where the playhead lands would quietly degrade the app's core
authoring gesture. This is decided explicitly here rather than inherited from wherever the branch
happened to sit.

**The minimap is in scope**, and it is the one place worth stating. `seekMinimapSnapping` already
excludes beats — the full-song strip packs them too densely to land on — so *Structure only* changes
nothing there and *Off* is the only value that reaches it. A seek is a seek whichever surface it is
made on, and a preference governing one of the two is a preference the player has to discover twice.

### D4 — Unrecognised degrades *towards* snapping

`resolvedSeekSnapping` falls back to `.structureAndBeat` for a missing key or a raw value written by
some later build. The direction matters: a playhead that will not line up with a marker is a worse
failure than one that lines up when you meant it not to, and it is the behaviour every existing
install already has. Mirrors `resolvedTempoWarning`; the default is bound to one named constant
because the literal an `@AppStorage` declares is what SwiftUI uses for an unset key and it does not
consult the accessor.

## Consequences

- The Song player screen carries five controls, and the ADR 0163 hold sheet carries them too — one
  view, both doors, so there is no second copy of the labels to drift. Five rows still fit the
  medium detent.
- It is a **`Picker` in its own section with a footer**, not a fifth toggle: three values with a
  longest label of *Structure and beat* would be three unreadable segments, and the menu form is
  what keeps the "row states its current value on the right" reading the hub trained.
- `reference/settings.md`, `reference/song-player.md` and `gestures.md` all state the count of these
  controls and all three are updated in this commit. `gestures.md`'s waveform section now says what
  a tap and a drag each catch, which it had never said.
- **Not covered:** a fine-adjust gesture. If someone reports *I cannot land it exactly* rather than
  *it keeps catching*, that is the other diagnosis in §5b and this setting is not its answer.
