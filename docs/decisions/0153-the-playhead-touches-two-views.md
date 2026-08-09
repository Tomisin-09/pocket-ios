# ADR 0153 — the playhead touches two views

- **Status:** Accepted
- **Date:** 2026-08-09 (`pocket-248-practice-render-path`)
- **Relates to:** ADR 0010 (page-mode), ADR 0025 (lock-screen session), ADR 0026 (in-song click)

## Context

Opening loop settings or song details on the practice screen while a song was playing made the
whole app feel sluggish. The tempo sheet was the clearest case: switching from **Tap** to
**Manual** raises a decimal keypad, and the keyboard's presentation visibly fought something.

The cost was not in presenting a sheet. `WaveformPracticeView`'s **root body** carried

```swift
.onChange(of: model.playheadFraction) { _, _ in … }
```

and the value expression of an `onChange` is evaluated during body execution, so the root body
took an observation dependency on `PracticeAudioEngine.currentTime` — written once per display
frame by `DisplayLinkTicker`, i.e. 120 Hz on a ProMotion device. All seven sheet and cover
presentations are declared on that same body, so while any of them was up, its content closure
was re-evaluated at the same rate.

`PracticeCockpit` had the same shape and made it more expensive: it read the playhead in three
places, so its whole `VStack` re-executed per frame, and inside that body it recomputed
`model.loops` (a SwiftData relationship sort), `model.markers` (a second sort plus a `map`
allocation) and `model.beatGrid` — which builds a beat for every beat in the entire song, and
was called about three times per pass because `gridAvailable` and `canUseMetronome` each
re-derive from it.

Three edit sheets compounded it on open with a whole-table `@Query` — every `Loop` in the
library to populate tag suggestions, every `Song` for collections, every `Exercise` for a picker
most openings never reach — each running on the main thread during presentation.

This was never only a settings problem. Scrubbing and the transport were paying the same tax on
every frame; the sheet just gave it somewhere to show.

## Decision

**Only a view that draws a moving playhead may read one.** Concretely:

1. The per-frame dependency lives in leaf structs — `PlayheadWatcher` (page-mode and the
   lock-screen clock, drawing nothing), `PlayheadWaveform`, `PlayheadMinimap`. Nothing that
   reads the playhead may also carry sheet presentations, derived collections or sibling
   controls.
2. Anything whose derivation costs something is computed by the enclosing body — which now runs
   only on real change — and passed down as a parameter. `PlayheadWaveform` takes its loops,
   markers and beats; it does not reach back into the model for them.
3. `beatGrid` is memoised on a value key of the four things it derives from (tempo, the 1, time
   signature, duration). Keyed rather than rebuilt by hand at each mutation site, because the
   song's tempo fields are written from outside the model too (`SongEditSheet`), and a cache
   that can be missed is worse than no cache.
4. Whole-library reads that exist only to *offer* something — suggestions, picker candidates —
   are fetched on demand through `LibraryPools`, from a `.task` or from the tap that asks for
   them, never as a standing `@Query` on a sheet. A pool that hasn't loaded costs a suggestion,
   never a correct value; where the pool must be complete (genre canonicalisation on Done) it is
   fetched at that moment instead.

None of this changes behaviour. Page-mode, the throttled lock-screen push and the click are
untouched.

## Alternatives considered

**Pause playback while settings are open.** Offered, and declined. It would have hidden the
symptom at its most visible point while leaving the same per-frame rebuild behind scrubbing, the
transport and the waveform itself — and it would have taken away something real, since hearing
the loop while adjusting its settings is the reason to open them there. Cheaper to write and
worse to use. The existing `pauseForNestedAudio` hook stays where it is, for the nested audio
modes that genuinely need the engine free.

**Rebuild `beatGrid` explicitly at each mutation site.** Rejected on the fourth call site: the
song's tempo fields are not owned by the practice model, so the list of places needing a rebuild
call is open-ended and a missed one produces a silently stale grid — which on this screen means
gridlines and a click that disagree with the music.

**Make `WaveformView` and `Minimap` `Equatable` to skip redraws.** Not the problem. Both
genuinely need to redraw when the playhead moves; the waste was everything *else* redrawing
alongside them. Trimming what the `Canvas` draws per frame remains available if measurement ever
calls for it.

## Consequences

- New screens that show a playhead must adopt the same split. `MetronomeView` already had it —
  `BeatIndicator` is a separate struct there precisely because rebuilding its parent on every
  beat dismissed an open menu — and this ADR generalises that from a local workaround to the
  rule.
- `WaveformPracticeModel` crossed the 400-line cap, so the grid and click members moved to
  `WaveformPracticeModel+Grid.swift`. `gridCache` stays in the class body (a stored property
  can't be declared in an extension) and is `internal` for the same cross-file reason the loop
  edit sheet's state already is.
- Tag and collection suggestions now appear a beat after a sheet opens rather than with it.
  Accepted deliberately: they are an offer, and the sheet arriving immediately is worth more.
