# ADR 0199 — the loop floor is half a second, and narrowing is recorded

- **Status:** Accepted
- **Date:** 2026-09-08 (`pocket-305-loop-span-floor-and-history`)
- **Amends:** ADR 0005 — its Consequences state that gesture-created loops enforce a minimum width
  via `WaveformGesture.minLoopWidth`. The minimum stays; its **unit** changes from a fraction of the
  song to seconds of audio, and the constant is renamed. Nothing else in 0005 moves.
- **Relates to:** ADR 0041 (the A/B span, whose two closing calls now take a duration and whose
  Save now writes a history row), ADR 0008 (the crossfaded loop buffer — the constraint the old
  floor was mistaken for), ADR 0036 (the enum-attribute migration crash, which is why this model
  stores no enum), ADR 0151 (cascade vs nullify, the rule this relationship is argued against),
  ADR 0189 (the schema criteria this change is measured by), ADR 0152 (relinking, why the duration
  is stored on the row)
- **Schema:** additive. One new `@Model` (`LoopSpanChange`) and one new to-many relationship on
  `Loop`. No column is retyped, renamed or removed, so ADR 0189's criteria do not apply — this is
  the migration-exempt shape (CoreData 134110) that 0189 D1 calls ordinary work.

## Context

Two problems, and they are the same problem seen from either end: **the app made narrowing a loop
hard, and then forgot that you had done it.**

### The floor was in the wrong unit

`WaveformGesture.minLoopWidth` was `0.02` — two percent **of the song**. ADR 0005 introduced it for
gesture hygiene, and its own words are the whole justification: it "stops a stray double-tap or a
pinched Fine selection from making a zero-width loop." It was never an audio constraint.

The audio constraint is 130× smaller and already handled. `PracticeAudioEngine.crossfadeSeconds` is
`0.015`, and the buffer builder clamps it:

```swift
let fade = min(Int(crossfadeSeconds * sampleRate), regionFrames / 2)
```

A short region gets a shorter crossfade. The engine has no minimum loop length at all.

Being a fraction, the floor scaled with the material:

| Song | 2% floor | Bars of 4/4 at 90 bpm |
|---|---|---|
| 2:00 | 2.4 s | 0.9 |
| 4:00 | 4.8 s | 1.8 |
| 6:00 | 7.2 s | 2.7 |
| 8:00 | 9.6 s | 3.6 |

So on a four-minute song a **single bar could not be isolated at any sensible tempo**, and looping
two beats — narrowing onto the one move that is actually failing — was impossible on anything but a
short track. The floor got *worse* the longer the piece, which is backwards: long songs hold more
detail worth isolating, not less.

### The narrowing left no trace

`Loop.start` and `Loop.end` are overwritten in place. A loop reading `1:58 – 2:04` says nothing
about whether it was set there or arrived there from `1:44 – 2:18` across three sittings. The second
reading is the one worth having — isolating a passage, slowing it, and re-entering it is the shape
of deliberate practice — and unlike mastery, tags or prose it is **generated for free by using the
app**. Most players will never rate a loop or write a note. Every player who narrows one has, by
narrowing it, said something.

The two problems compound: there is little point recording that a player narrowed their span if the
app stops them narrowing it to the thing that is wrong.

## Decisions

### D1 — the floor is half a second of audio

`WaveformGesture.minLoopSeconds = 0.5`, converted to a fraction per song by
`minWidth(forDuration:)`. Half a second is ~33× the crossfade requirement, comfortably above
anything a stray tap produces, and short enough to isolate a single beat at 120 bpm.

`WaveformGesture` stays pure — it takes a duration as a number rather than reaching for a song. Both
bounds functions already had `minWidth:` as a parameter, so the change at each of the five call
sites is passing a real floor instead of accepting the default.

**`minLoopWidthFallback` (`0.02`) remains** for the one case with no duration to divide by — audio
that has not resolved yet. It is deliberately small: an unknown duration is transient, and a
too-large floor there would silently widen a span the player set.

Clamped to half the song, so a pathologically short file stays loopable rather than trapping.

**Rejected: deriving the floor from the beat grid.** One beat is the musically correct minimum, and
it is unavailable — `Song.bpm` and `Song.downbeatSeconds` are both optional and most songs have
neither. A floor that only works for players who set a grid is a floor that fails exactly the
players this ADR is for.

**Rejected: no floor at all.** The gesture hygiene reason 0005 gave is still true; a double-tap can
still land twice in the same place.

### D2 — `TakeDetailView+Trim` gets the same floor

It used the same constant. The proportional rule was only ever harmless there because takes are
short — a twenty-second take got a 0.4 s floor. It is the same latent bug, and takes will get
longer.

### D3 — a span change is a row, written at the one site that overwrites a span

`LoopSpanChange` records `changedAt`, the span after, **the span before**, the playback speed in
force, and the song's duration at the time.

`saveABSpan()` is the only place a saved loop's range is ever rewritten — creation goes through
`createLoop`, and everything else reads. So there is one write site, and it records *before* the
overwrite, which is the only moment the old bounds still exist.

**Each row is self-contained** — it carries both spans. One row answers "widen back to where it
was" without walking the chain, and a loop that predates this ADR loses nothing: its first recorded
change carries the bounds it was created with. That is also why **no row is written at creation**:
the first change's `previous` pair *is* the creation record, which keeps the write to one site.

**The speed is on the row.** The narrowing and the slowing are one behaviour, not two facts —
"narrowed and dropped to 0.72×" is the sentence worth being able to write. Reconstructing it later
from `PracticeRun` would be guesswork about which run an edit sat inside.

**The duration is on the row** so a span reads back in seconds without depending on the audio still
being linked (ADR 0152) or still being the same file.

**A save that moved nothing writes nothing.** Opening the range editor and pressing Save must not
manufacture a row claiming an edit that did not happen. The guard is float hygiene (`1e-9`), not a
meaningful threshold — every save is an explicit act, and a two-frame trim at the top of a phrase is
a small number and a deliberate one.

### D4 — no enum attribute, and the kind is derived

ADR 0036's migration crash was a **custom enum** on a `@Model`, which has no value to decode for old
rows. So `LoopSpanChange` is primitives and one relationship. Whether a change narrowed, widened or
slid is computed from the two widths by `SpanHistory.kind(...)`, a pure function.

Width is the axis that matters: narrowing is the research-relevant act, widening is its inverse and
the test of whether it stuck. **A span that keeps its width and slides along the song is neither** —
calling it either would put a false claim into everything that reads the history back.

### D5 — cascade, not nullify

`Loop.spanChanges` is `.cascade`, like `references` and unlike `journal` / `recordings`.

ADR 0151 keeps a take alive past its loop because the take is a recording of the player — it has a
life of its own. A row saying "this span narrowed from there to here" is a fact *about the span*.
With the loop gone there is no span for it to be about.

## Consequences

- A player can now isolate a single bar — or a single beat — on a song of any length. The gesture
  that the loop feature exists for finally reaches the sizes it is for.
- Narrowing accumulates a history for free, with no rating, tagging or prose asked of anyone. This
  is the input the Red Moon Oracle's reviews and summaries (ADR 0187) are worth building on, and it
  is generated by players who would never fill in a field.
- **Not built here, deliberately:** nothing reads the history back yet. The span editor section, the
  widen-back affordance and the Oracle context payload are separate slices; this one lands the floor
  and the record so the data starts accruing before the surfaces that need it exist. A history that
  only begins on the day its UI ships is a history nobody has.
- `ABSpan.tappingPlayhead` and `ABSpan.closed` take a `duration`. The type stays pure; it takes one
  more number.
- `WaveformGestureTests` was split — `LoopWidthFloorTests` holds the floor's own tests, because the
  unit change is its own subject and the original class had reached the type-body limit.
- No user-facing copy changes: the floor is a limit nobody was told about, and the history has no
  surface yet.
