# 0022 — Beat grid & downbeat snap

- **Status:** Accepted
- **Date:** 2026-06-19 (`pocket-025-beat-grid-snap`)

## Context

ADR 0021 shipped plain snap: a released loop edge or tap-seek catches a nearby
marker or saved-loop boundary. Its "out of scope" note deferred the richer
cousin — **beat-grid / downbeat snap** — on purpose, because snapping to the
pulse needs more than a marker list: it needs the song's **tempo** *and* a
**phase anchor** (where bar 1 lands). BPM alone gives the beat *interval* but not
the *phase*, so a song with lead-in silence (almost all of them) would draw a
grid that drifts against the music.

The substrate is now all in place — accurate envelope (0017), still/zoomed
window (0010, 0020), every loop & marker drawn (0018), and the snap plumbing
(0021) that already sources candidates and scales a tolerance to the zoom. Beat
snap is a candidate *source* plus a thing to *draw*; it slots straight into that.

## Decision

- **The grid needs both a tempo and a downbeat anchor; we never guess the
  phase.** `Song` already has `bpm: Int?`. We add `downbeatSeconds: TimeInterval?`
  — the seconds at which a bar-1 downbeat lands. The grid exists only when **both**
  are set; with either missing, nothing is drawn or snapped to. (Anchoring at song
  start was rejected — see Alternatives — because lead-in silence makes phase-0
  wrong for most songs.)
- **The grid math is one pure type.** `BeatGrid.beats(bpm:duration:downbeat:
  beatsPerBar:)` steps outward from the anchor in both directions at `60 / bpm`
  seconds and returns every beat inside `[0, duration]` as a song fraction, each
  flagged `isDownbeat`. `beatsPerBar` (default **4** — assume 4/4) groups them, so
  every 4th beat from the anchor is a downbeat. Non-positive bpm/duration → `[]`;
  a runaway-dense grid (> `maxBeats`) → `[]`. Kept in the UI-free, unit-tested
  `BeatGrid` alongside `WaveformGesture` / `TempoMath` / `AudioMath`.
- **Snap candidates gain the beats.** `WaveformPracticeModel.snapCandidates`
  appends `beatGrid.map(\.fraction)` to the markers and loop edges it already
  feeds `WaveformGesture.snap`. So the three ADR-0021 release points
  (`endDragSelection`, `endMoveHandle`, `seekSnapping`) now catch the pulse too —
  no new release wiring, same zoom-scaled `snapTolerance`, same light haptic.
  Downbeats are not weighted above ordinary beats: they're a subset of the same
  candidate list, so the nearest beat wins regardless.
- **The grid is drawn, faintly, behind everything.** Consistent with 0021's "snap
  to what you can see": `WaveformView` takes `beats: [BeatGrid.Beat]` and draws a
  thin vertical line per beat at the back of the canvas — bar-start downbeats
  brighter/heavier, ordinary beats fainter. The draw is **density-aware**: sub-beats
  drop out once they'd sit under ~5 pt apart at the current zoom, and the whole grid
  is skipped once even the downbeats would crowd, so a zoomed-out view never smears
  into a wash.
- **The anchor is set on the song edit sheet** (`SongEditSheet`) as a decimal
  "Downbeat (s)" field next to BPM, mirroring how the other metadata is edited
  (ADR 0012). Empty clears it.

## Consequences

- With BPM + a downbeat set, the waveform shows the bar/beat structure and new
  loop edges / seeks lock to the pulse — so loops start and end on the beat
  without pixel-hunting, the natural finish to the snap interaction.
- `Song` gains one optional field (`downbeatSeconds`, declaration-defaulted `nil`
  for SwiftData lightweight migration per ADR 0012); no other schema change.
- `BeatGrid` is new pure logic (11 unit tests). `WaveformView` gains a defaulted
  `beats` input so the many component previews/call sites that don't need it are
  unaffected.

## Out of scope (follow-ups)

- **Set the downbeat from the playhead.** Typing seconds is precise but unmusical;
  a "set downbeat here" control on the practice transport (capture the live
  playhead) is the ergonomic way to anchor it, and the obvious next slice.
- **Configurable time signature.** We assume 4/4 (`beatsPerBar` defaults to 4 but
  is already a parameter). A stored per-song signature for waltzes/odd meters can
  come later without touching the math.
- **A snap-strength / grid on-off toggle**, and snapping in the minimap overview
  (still un-snapped, as in 0021).

## Alternatives considered

- **Anchor the grid at song start (phase 0), no anchor UI.** Rejected: lead-in
  silence/count-ins make beat 1 ≠ t=0 for most real songs, so the grid would look
  and snap wrong exactly where precision matters. A nullable anchor that simply
  hides the grid until set is honest about not knowing the phase.
- **Designate an existing marker as the downbeat.** Reuses markers, but overloads
  what a marker means and forces a marker to exist just to anchor a grid. A
  dedicated optional field keeps the two concepts separate.
- **Weight downbeats as stronger snap targets.** Rejected for now: the tolerance is
  already tight on screen, and biasing toward bar starts would fight a user trying
  to land on an off-beat. Every beat is an equal candidate; revisit if practice
  shows people overwhelmingly want bar starts.
- **Draw the grid on top of / instead of the bars.** Rejected: a back-of-canvas
  faint grid reads as structure without competing with the waveform or the amber
  loop fills; on-top lines muddied both.
