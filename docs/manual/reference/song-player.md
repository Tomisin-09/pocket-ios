# The song player

The waveform screen. Reached by tapping a song in the [library](home-and-library.md), or the
`JUMP BACK IN` card on Home. Procedure is in [looping](../looping.md); this page names the parts.

<!-- shot: reference/player | role: screen
     | alt: The song player with the title strip, the speed bar, the status line, the waveform, the transport and the Loops panel
     | state: seeded library, Little Wing, idle, Loops panel expanded -->

## The title strip

`Back to library` on the left. Beside it the song's title, artist and mastery. **Hold the title** to
open [Song details](home-and-library.md#song-details) — there is no button for it.

## The speed bar

- **`Playback speed`** — the slider that slows the song down without changing its pitch. Its
  accessibility label states the current value.
- **`Reset`**, and the shortcuts beside it, return it to full speed or jump to a fixed fraction.
- **The BPM readout** shows the song's tempo, captioned `BPM`. It reads *Tempo not set* until you
  give the song one.
- **The metronome button** turns a click on over the song. **Holding either it or the BPM readout**
  opens the tempo editor — the same sheet from two handles.
- **`Repeat the song`** loops the whole track rather than a marked span.

## The status line

The row beneath the speed bar, which changes with what you are doing.

- **`Loop controls`** — *tap* for the gesture cheatsheet, an eight-row popover reproduced in full in
  [gestures](../gestures.md). **Hold it for the player's own settings** — the four in
  [Settings ▸ Song player](settings.md#song-player), surfaced where they apply. This hold has no
  visible hint, which is why it is written down here and there.
- **`Follow`** — a chip. Off, pinch-zoom holds the spot under your fingers; on, it tracks the
  playhead.
- **`Set the 1`** — marks where the bar starts, so a click can line up with the music.

While a span is being drawn the line is replaced by the A/B strip; while you are placing the 1 it is
replaced by the downbeat bar. So those three states never overlap.

## The waveform

The drawing of the song, with a time ruler beneath it and the playhead across it.

- **Tap or drag** to seek. `Song position` is the accessible handle for the same thing.
- **Pinch** to zoom.
- **Hold and drag across it** to draw a loop directly.
- **`Marker`** drops a marker at the playhead.
- A **minimap** strip under the waveform shows the whole song; it can be turned off in
  [Settings ▸ Song player](settings.md#song-player).

## The transport

`Back 10 seconds` · **`Play`** · `Forward 10 seconds`, with **`Loop`** beside them. Hold either skip
button to change how far it jumps. Which side `Loop` sits on is a setting.

## The panels

Two collapsible lists under the transport, each headed with its name and, when collapsed, a count.

### `Loops`

One row per loop: its name, its range as times, and its mastery. Each row carries **play**, an
**adjust range** control that takes you back to the waveform to drag the ends, and a **ramp** control
that opens the loop automator.

**Hold a row** for its menu, including `Edit loop`.

<!-- shot: reference/loops-panel | role: panel
     | alt: The Loops panel expanded, each row showing the loop name, its range, its mastery and the play, adjust and automator controls
     | state: seeded library, Little Wing, Loops expanded -->

**Hold the panel header** to start selecting, then tap rows to act on several at once.

### `Markers`

One row per marker: its name and its time. Tapping a row seeks there. Holding one opens its edit
sheet. Marker names can also float over the timeline as you play up to them — a setting.

## The sheets

### `Edit loop`

<!-- shot: reference/loop-edit | role: screen
     | alt: The Edit loop sheet showing Name, Favourite, Range, and the Practice section with Mastery, Focus, Type and Command tempo
     | state: seeded library, Little Wing, loop "Verse riff" held, Edit loop -->

`Cancel` discards, `Done` keeps.

- **`Name`**, and a `Favourite` star.
- **`Range`** — the span as times, with `Adjust range on waveform` to go back and drag it.
- **`Practice`** — `Mastery`, `Focus`, `Type` and `Command tempo`, each with an ⓘ. These four are
  defined in [the app's own words](../terms.md).
- **`Train your ear`** and **`Improvise`** — the two alternative ways to run this loop.
- **`Backing track`** — marks the span as something to solo over.
- **`Journal`** — notes written against this loop, showing a count or `None`.
- **`Tags`** — your own labels, plus a row of suggestions.
- **`Colour`** — how the span is drawn on the waveform, including `Custom colour`.
- **`Delete loop`** at the bottom.

### The loop automator

<!-- shot: reference/loop-automator | role: screen
     | alt: The loop automator sheet with the Start, Target, Steps and Loops per step fields above the ramp summary
     | state: seeded library, Little Wing, automator opened on "Verse riff" -->

A ramp for one loop, expressed in percentages of the song's speed: `Start`, `Target`, `Steps` and
`Loops / step`, with a summary of the climb above them and the BPM it works out to below.
**`Set ramp`** arms it.

### The tempo editor

Two ways in — hold the metronome button or the BPM readout.

<!-- shot: reference/tempo-editor | role: screen
     | alt: The tempo sheet with the Tap and Manual segments, the tap pad, Estimate from audio, and the downbeat section
     | state: seeded library, Little Wing, tempo editor open -->

- **`Tap`** — `Tap to the beat`. The app's own explanation: *Play the song and tap along. Tapping
  reads the playhead, so a loop or slowed speed still reads the true tempo. The reading follows your
  last few taps, so on a song that drifts, keep tapping through the section you care about.*
- **`Manual`** — type the number.
- **`Estimate from audio`** analyses the track and proposes one.
- **`The 1 (downbeat)`** — `Mark the 1 at the playhead`, or `Set the 1 on the waveform`.

### The player settings sheet

Titled `Song player`, and reached only by **holding `Loop controls`**. It carries the same four
switches as [Settings ▸ Song player](settings.md#song-player): `Loop control on left`,
`Show minimap`, `Show marker labels` and `Zoom follows playhead`.

### The others

- **Marker edit** — a marker's name and position.
- **Bulk edit** — `Type` and `Focus` across every loop you have selected.
- **Journal** — notes for this loop, from the `Journal` row of its edit sheet.
- **Ear training** and **Improvise** — the two alternative run modes, opened from the same sheet.
- **The practice run** takes over the whole screen; it is covered in [practice](practice.md).

## Landscape

Turn the phone and the waveform takes the full width, with the panels moving into a drawer. The
controls are the same ones.
