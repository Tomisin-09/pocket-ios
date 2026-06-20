# Changelog

All notable changes to Pocket are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project is pre-release.

## [Unreleased]

### Added
- **Beat grid & snap to the beat** — give a song a **BPM** and a **downbeat** (the
  seconds where bar 1 lands, set on the song's edit sheet next to BPM) and the
  waveform draws a faint **beat grid** — thin lines per beat, brighter on the bar
  starts. Releasing a drawn loop edge, a Fine handle, or a tap-seek then **catches
  the nearest beat** as well as markers and loop edges, so loops start and end on
  the pulse. The grid thins out automatically when you zoom out so it never smears.
  No downbeat set ⇒ no grid (we don't guess where bar 1 is). Assumes 4/4. ADR 0022.
- **Loops and seeks snap to what you can see** — when you release a drawn loop edge,
  drag a Fine handle off a blue dot, or tap to seek, the boundary now **catches a
  nearby marker or saved-loop edge** if you land close to one (a light haptic
  confirms the catch). The catch zone is a constant size on screen at any zoom and
  it's tight enough to assist, not hijack — land clear of a marker and nothing snaps.
  Scrubbing and the minimap stay free. ADR 0021.
- **Draw a loop right on the waveform** — in Navigate mode, **press and hold, then drag**
  to paint a loop region (a haptic confirms when the hold arms). Release and the region
  becomes a confirmable loop — auto-named and looping at once on **Y**, like a punch. A
  quick drag still scrubs and a tap still seeks; only a deliberate hold starts a selection.
  This is the direct on-waveform way to set a loop's *range* (the **Loop** button still
  punches one at the playhead). ADR 0005 (round 5).

### Changed
- **New blue look** — the waveform **bars are now blue** (anchored on `#2a6796`) on
  the near-black background, so the song reads as its own themed surface. Green is kept
  for the **live state** (playing / the loop you're capturing) and Fine-mode precision
  is cyan, so each still reads apart from the bars. ADR 0023.
- **Clearer loop confirm/discard** — when you capture a loop, the confirm/discard
  pair is now a **green ✓ and a red ✗** (was a blue/red Y/N). ADR 0023.
- **Loops and markers now sit on the borders, off the song** — the saved-loop
  indicators and markers no longer draw over the waveform bars. Markers are **purple
  inverted triangles** along the top edge; each saved loop is a **coloured line** along
  the bottom edge, **stacked into rows when loops overlap**. ADR 0023.
- **Every loop has its own colour** — saved loops are now distinguishable at a glance,
  each drawn in its own hue (the active loop heavier and full-strength, parked loops
  lighter). Overlap is still shown by row position. ADR 0023.
- **Deep zoom now shows real detail, not stretched blocks** — when you pinch in close,
  the waveform **re-reads that slice of the song from the file** and draws it at full
  resolution, so individual note onsets and transients resolve where you're working
  (it used to just stretch the whole-song envelope, so a deep zoom looked chunky). The
  refresh is debounced and cached, and falls back to the stored envelope while it
  computes. ADR 0020.
- **Zoomed waveform now reads like GarageBand** — when you pinch to zoom in, the
  window **holds still** and the **playhead sweeps across it**, paging forward when it
  reaches the edge (it used to pin the playhead to the centre and slide the whole
  waveform underneath, which stuttered and made the playhead look frozen). A **Fit**
  button appears in the corner while zoomed to snap back to the whole song. ADR 0010.
- **Loops are created instantly — no naming step, and they start looping.** Confirming
  a captured region (**Y**) now creates the loop immediately, **auto-named** ("Loop 3"),
  active, **and playing** — it loops straight away without a separate tap on ▶. Rename it
  later from its row. The pop-up naming sheet is gone. Markers still ask for a name
  (a marker *is* its label). ADR 0019.
- **Waveform reads musically** — the per-bar envelope is now **energy-based and
  transient-resistant** instead of peak: each bar takes the median of several short
  RMS sub-windows, so it tracks the sustained level of the music and steps over
  rhythmic spikes (a snare no longer dominates the picture), then normalises to a
  high percentile rather than the single loudest sample. Brick-walled masters that
  used to render as a flat block now show verses dipping and choruses swelling. The
  stored resolution also grew (240 → 512 bars) for finer detail. Songs imported
  before this **re-extract their waveform automatically** the next time you open
  them. ADR 0017.

### Added
- **Undo a delete** — deleting a loop or marker now shows a **"Deleted X · Undo"**
  toast for a few seconds; tap **Undo** to bring it back exactly as it was (same
  identity, and re-activated if it was the active loop). ADR 0019.
- **See your whole loop & marker library on the waveform** — the detail waveform and
  minimap now draw **all** saved loops and markers, not just the active one. Markers
  hang as **pins from the top**; loops sit as **brackets along the bottom**. When loops
  **overlap or nest**, they **stack into lanes** (the later one drops a row) so overlap
  reads by position — colour stays reserved for state, with the **active loop** drawn
  brighter (plus its usual fill). ADR 0018.
- **Automator — per-loop speed trainer** — each loop row now has an **"A" control**
  (replacing the old speed·repeats text). Set a **start %**, a **target %**, how many
  **steps** to get there, and how many **loops per step** — the loop then ramps its speed
  in even steps as it repeats, plays its passes at the target, and **stops on its own**
  once the ramp's last automated pass has played (then rewinds, ready to run again). It
  climbs *or* descends (target below start = a slow-down trainer), or sits **level** when
  start = target; the per-step change is shown for you ("+5% each"). The setup sheet is a
  visual **ramp** with a climbing / falling / flat graphic and **BPM** equivalents when the
  song's tempo is known; **Set ramp** arms it **and starts the loop playing** from the top,
  a full-width red **Turn off ramp** disarms, and grabbing the speed slider hands control
  back. The stepping is pure, unit-tested math (`AutomatorConfig`); the engine counts loop
  wraps in source frames so the steps stay evenly spaced across speed changes. ADR 0013.
- **Song metadata editing** — **swipe a library row → Edit** to open a metadata sheet
  (`SongEditSheet`): title, artist, **album**, **year**, key, BPM, proficiency
  (tappable stars), and progression; **collection tags** (add / swipe-to-remove); a
  free-form **note**; and read-only **practice stats** — *Loops · Markers · Annotations*
  (annotations = loops + markers). The song record is where we enrich the data that
  drives practice routines. Filename-derived suggestions, a practice **journal**, and
  collections-as-playlists are planned next. ADR 0012.
- **Loading state when opening a song** — the practice screen now dims with a
  **spinner + "Loading song…"** while the audio file opens, instead of looking frozen.
  The file open (and the demo render) moved **off the main actor**, so the UI stays
  responsive on slow/iCloud reads and the overlay also blocks taps on the half-ready
  controls until playback is ready.
- **Song library + file import** — the app now opens to a **library** of your songs
  (`LibraryView`). Import any DRM-free local/iCloud **audio file** (the `+` button, or
  the empty-state button): Pocket takes a **security-scoped bookmark** for durable
  access, **extracts the real waveform** up front (`WaveformExtractor`), and persists it
  as a `Song` you open and practice with its **actual audio**. A first-run **empty
  state** offers Import or a bundled demo, retiring the auto-seeded arpeggio. The title
  defaults to the file name; richer metadata editing is next. ADRs 0011 (Slice 2) & 0001.
- **Persistence (SwiftData)** — loops and markers now **survive relaunches**. The
  domain (`Song` / `Loop` / `Marker`) is SwiftData `@Model`s, replacing the in-memory
  `WaveformMock`; the practice screen binds to a persisted `Song` via the model context.
  A CloudKit-ready foundation for the library, routines, and sync still to come. ADR 0011.
- **Pinch-to-zoom the waveform** — pinch the detail waveform to zoom into a section.
  The view **tracks the playhead**, so you navigate by seeking (tap / scrub / minimap)
  and the waveform follows — no separate pan gesture. The minimap **viewport box
  returns**, now live, showing the visible slice. The zoom + screen↔song-fraction
  mapping is pure, unit-tested math in `WaveformGesture`. ADR 0010.
- **Region looping** — an active loop now actually loops: playback wraps from the
  loop's end back to its start continuously and **seamlessly** — gapless *and*
  click-free, via a pre-rendered loop buffer whose seam is equal-power
  **crossfaded** (`AudioMath.crossfadeGains`) and played on `.loops` (boundary math
  in unit-tested `AudioMath.loopSegment`, wrap math in `AudioMath.loopedPlayhead`).
  A loop just loops (no on/off toggle — the per-loop `repeats` count is reserved for
  the future automator); a small **✕ exit chip** by the loop name returns to
  full-song playback. Decisions in ADRs 0006 & 0008.
- **Loop edit mode is now a distinct, modal state.** While creating or adjusting a
  loop the **transport bar greys out and locks**, and the mode-instructions line is
  replaced by an **edit toolbar**: a ▶︎ **audition** button (loop the captured region
  to hear it before saving — for Tap *and* Fine loops), a state label (**"New loop"**
  / **"Editing loop"**), and a **Y/N** decision (green **Y** = save, red **N** =
  discard — letters instead of ✓/✗ so they can't be mistaken for the loop's name).
  You leave edit mode via Y/N, not by switching modes.
- **Live loop-range preview** — adjusting a loop's bounds in Fine mode auditions the
  new region on handle-release (you hear only the edited loop, not the saved one);
  discarding restores the saved bounds.

### Fixed
- **Pinch-to-zoom no longer jumps the playhead** — finishing a pinch used to fire a
  stray tap-to-seek (and the spread could scrub mid-pinch), because the tap gesture
  only knew a pinch was happening while it was *mid*-pinch. The waveform now latches
  that a pinch occurred for the whole touch and swallows the trailing seek/scrub.

### Changed
- **Naming a new loop or marker is now just a name** — no position/range readout and
  no delete button (Cancel already discards a brand-new one). A dropped marker isn't
  added until you save it. Editing an *existing* loop/marker keeps the full sheet
  (range/position, playback, delete). The transport's **Loop and Mark buttons swapped**
  positions (Loop first).
- **Waveform interaction rationalised** (after pinch-zoom surfaced gesture clashes):
  **tap now seeks everywhere** — Scroll and Tap modes collapse into one *Navigate*
  behaviour (tap = seek · drag = scrub · pinch = zoom). Capturing at the playhead moves
  to **buttons on the transport**: **Mark** (drop a marker), **Loop** (punch in/out), a
  **Fine** toggle (precise handle-editing), and a reserved **Auto** slot for the future
  automator. The **hold-to-drop-marker** gesture is gone (it raced with pinch). The
  **time ruler now follows the zoom**, labelling the visible window. ADR 0005 (round 4).
- **Transport bar slimmed further** — tighter vertical spacing/padding and a smaller
  play control, to reclaim cockpit height. The freed space is reserved for the future
  automator entry (see ADR 0009).
- **Minimap viewport box hidden** until pinch-to-zoom exists — the detail waveform
  always shows the whole song for now, so the box was static and meaningless; it
  returns (live) with zoom. (`song.viewport` data retained.)
- **Practice screen refactored to a view model** (no behaviour change): state and
  the gesture/loop handlers moved out of `WaveformPracticeView` into an
  `@Observable` `WaveformPracticeModel` (+ `…+Actions` extension). The view drops
  from the SwiftLint file-length limit (400 → ~130 lines), making room for the
  next features. Decisions in ADR 0007.
- **Transport bar simplified**: the **"+" quick-capture** and the per-loop
  **repeat/clear controls** are gone — loop creation is owned by the Tap/Fine
  gestures, and an active loop simply loops (the explicit toggle was redundant;
  real region looping lands on a later branch). When a loop is active the
  transport now shows its **name** over its time range.
- **Confirm pill** is smaller and now lives on the **mode-instructions row
  (trailing)** in every mode, instead of floating over the waveform. On a Tap
  second-punch the captured loop **stays highlighted green** while you confirm.
- **Cockpit chrome slimmed**: the speed/tempo bar is more compact (smaller `×`
  readout, tighter spacing) and the minimap is shorter. The **minimap is now
  seekable** — tap or drag anywhere on it to move the playhead (also VoiceOver-
  adjustable), reclaiming vertical space in the pinned cockpit.
- **Loop capture flow refined** (2nd round of on-device feedback): the keyboard-
  free confirm step is now an **icon-only ✓/✗ pill floating over the waveform**
  (the old bar read as if the name were editable there). **Tap mode is now punch
  in/out** — taps mark the loop at the *current playhead* and never move it; only
  dragging scrubs. Discarding the name from a **Fine** selection now **keeps the
  selection** (handles + pill return) so it can be re-adjusted. ADR 0005 updated.
- Renamed the product from "Ore" to **Pocket** (module, targets, bundle id
  `click.decooperations.pocket`, repo `pocket-ios`, all docs). Dropped the
  Yoruba "friend" etymology, which no longer applies to the new name.
- Waveform practice screen restructured into a **fixed practice cockpit**
  (song strip, speed bar, waveform, ruler, minimap, transport) over a
  **scrollable reference area** (loops, markers, song info). Song info is
  demoted to the bottom, collapsed by default. See ADR 0003.
- Temporarily launch the app straight into the waveform practice screen (reverts
  to the home/planner once navigation lands in Phase 3).

### Fixed
- `project.yml` no longer regenerates (overwrites) the hand-maintained
  `Info.plist` — the stray `info:` block was dropping the Apple Music usage
  string, background-audio mode and portrait lock on every `xcodegen generate`.

### Added
- **Waveform gesture engine — UX polish** (from on-device feedback): Scroll mode
  now **drags to scrub** the playhead (tap still jumps, hold still drops a
  marker); Tap mode **plays a preview** from the first tap, filling the loop
  region green, and stops on the second; a live **time bubble** rides the
  playhead in every mode. Loop capture is now a keyboard-free **confirm bar
  (✓/✗)** that opens a native **naming sheet** (no more keyboard hiding the
  field). Loop & marker lists are **unified** — tap a row to use it (activate
  loop / seek to marker), edit via a trailing pencil. An existing loop's range
  can be **adjusted in Fine mode** via "Adjust range" (the reference area dims to
  focus the waveform). Name fields gained a **clear (✕)** button. ADR 0005 updated.
- **Waveform gesture engine** — the three transport modes are now live on the
  waveform: **Scroll** taps to seek and holds 650 ms (amber ring) to drop a
  marker; **Tap** drags to scrub and two taps capture a loop; **Fine** drags two
  blue handles to set loop bounds. Loop capture is named inline as before. The
  pure gesture math (point→fraction, bound ordering + min width, handle
  hit-testing) lives in unit-tested `WaveformGesture`. The transport **+** button
  remains as an accessible quick-capture. Decisions in ADR 0005.
- **Waveform practice screen** (Phase 1 skeleton) — SoundCloud-style mirrored
  waveform, speed/BPM bar, time ruler, minimap, transport bar with Scroll/Tap/
  Fine mode pills, all on the design tokens. Driven by mock data; audio engine,
  gestures and the asymmetric speed scale are later iterations.
- Loops & markers panels with **named, editable** entries: tap a row to edit
  (name/speed/repeats/delete) via a native sheet; activate a loop from its
  trailing play button. ADR 0003 records the interaction decisions.
- **Naming-on-capture** — capturing a loop slides in an inline creation panel
  below the transport (name field + range + Save/Discard, with a Reduce Motion
  fallback). Capture is triggered by a transport **+** button standing in for
  the Tap/Fine waveform gesture until the gesture engine lands.
- **Empty states** for the Loops and Markers panels (with hints that teach the
  real interaction), and an **unknown-tempo** state: `Song.bpm` is now optional
  and the speed bar shows a "Set BPM" affordance when it's absent — the speed
  multiplier works regardless. BPM derivation strategy recorded in ADR 0004.
- **Audio playback engine** (`PracticeAudioEngine`): real play/pause, seek, and
  pitch-preserving speed via `AVAudioUnitTimePitch`, with a live playhead. The
  practice screen's transport, speed bar and playhead are now driven by actual
  audio. A generated arpeggio (`SampleToneGenerator`) is the dev source (real
  file import is a later piece), and the waveform is downsampled from it.
  Pure helpers in `AudioMath` are unit-tested.
- SwiftUI `#Preview`s for the screen and each component (`WaveformPreviews`).
- Project scaffold (Phase 0): repo structure, XcodeGen `project.yml`, SwiftLint
  config, GitHub Actions (lint + build + test on PR; TestFlight on merge),
  Fastlane stubs.
- `SongRef` — source-agnostic song identity (local files + Apple Music), unit-tested.
- `TempoMath` — pure tempo/speed-slider/automator math, unit-tested.
- Design tokens, app entry point, placeholder home screen.
- Governance docs: `AGENTS.md`, `PROJECT.md`, `docs/architecture.md`, ADRs 0001–0002.
- `docs/design-brief.md` — self-contained design brief + working protocol for
  designing the UI with Claude (design system contract, screen inventory,
  per-screen request template, definition-of-done).
- Infrastructure stub for the Phase 4 Claude proxy.