# Settings

The **gear at the top left of Home**. It pushes onto the same stack as everything else, so it backs
out to where you were.

## The hub

<!-- shot: reference/settings-hub | role: screen
     | alt: The Settings hub with You and Red Moon Pro above a Preferences group holding Appearance, Sound & feel, Practice, Routines and Song player, with Your data, Privacy and Help & About in a group below
     | state: Settings open -->

Ten destinations. **Each row states its current value on the right**, so most questions are
answered without opening anything.

| Row | Holds |
|---|---|
| `Red Moon Pro` | Your subscription state, and the three things you can do about it |
| `You` | Your name, and what you play |
| `Appearance` | Theme, motion, and how notes are spelled |
| `Sound & feel` | Haptics, and which click the metronome plays |
| `Practice` | Count-in, screen, the strumming click, and reminders |
| `Routines` | How a routine moves from block to block |
| `Song player` | Four things about the waveform screen |
| `Your data` | A copy of everything, and what it takes up |
| `Privacy` | The one analytics switch |
| `Help & About` | Version, help, contact, diagnostics, and the legal links |

`Red Moon Pro` and `You` sit above the rest because they are *state* — what you have and who you
are — rather than preferences.

Most rows carry an **ⓘ**. The explanations below are those popovers, word for word: where this page
and the app differ, the app is right.

## `Red Moon Pro`

While a trial is running, a countdown row sits at the top. Then `Manage Subscription` for a
subscriber, or `Upgrade to Red Moon Pro` for everyone else, and `Restore Purchases`, which is always
offered.

Cancelling happens on Apple's own screen. There is no billing interface in the app. See
[Red Moon Pro](../subscription.md).

## `You`

<!-- shot: reference/settings-you | role: screen
     | alt: The You screen with the artist name field and the Your sound section holding instrument, experience, genres, dream and time most days
     | state: Settings ▸ You -->

- **`Artist name`** — *Your artist name greets you on the home screen. Optional, and it stays on this
  device.*
- **`Your sound`** — `Instrument`, `Experience`, `Genres`, `Dream` and `Time most days`. Its footer:
  *Shapes what the app suggests — starting tempo, session length, and what surfaces first. Optional,
  and it stays on this device. New exercises open on your instrument; each drill keeps its own, so
  changing this never rewrites one you already made.*

Every one of these is optional, and none of it leaves the device.

## `Appearance`

- **Theme** — `System`, `Light` or `Dark`, footnoted *System follows your device*.
- **`Motion` ▸ `Animate exercises`** — *A moving highlight walks the exercise in time — the notes on the fretboard, the strokes on the strum lane. Always off when your device has Reduce Motion on.*
- **`Note names`** — `Sharps (♯)` or `Flats (♭)`, used where the music does not settle it for itself.
  Where a key is known, the key wins.

## `Sound & feel`

- **`Haptics`** — *Light taps that confirm gestures like setting a loop or tapping tempo.*
- **`Metronome sound`** — `Click`, `Wood block`, `Rim` or `Beep`, each with a one-line description.
  Tapping one chooses it and plays a sample.

<!-- shot: reference/settings-sound | role: panel
     | alt: The Sound & feel screen with the Haptics toggle and the four metronome sounds, one selected
     | state: Settings ▸ Sound & feel -->

## `Practice`

- **`Count-in`** — *A count-in before a tempo climb begins, so you can settle in before playing.*
- **`Count-in length`** — how many bars, once a count-in is on.
- **`Keep screen awake`** — *Stops the screen locking while you play along hands-free.*
- **`Strumming click follows the pattern`** — *For a strumming drill, the metronome plays the pattern's rhythm (down/up/accent). Turned off, it's a plain click you strum the rhythm against.*
- **`Tempo changes`** — `Off` or `Show`, for whether a climbing ramp announces the tempo it is moving
  to.
- **`Starting point for new reminders`** — the days and the **`Time`** a *new* routine reminder
  starts from. It sets a starting position and nothing else: **nothing here sends anything**, it
  never changes a reminder already set, and there is no switch that turns reminders on. A reminder is
  switched on from the routine itself — see [Reminding yourself](../routines.md#reminding-yourself).
- **`Reminders you've set`** — every routine that currently has one, with its days and time, or
  **`None yet`**. Tap one to change its days, its time, or to switch it off, without going to the
  routine.

## `Routines`

<!-- shot: reference/settings-routines | role: panel
     | alt: The Routines settings screen with auto-start, advance automatically, rest length and loop song blocks
     | state: Settings ▸ Routines -->

- **`Auto-start blocks`** — *In a routine, each block after the first starts on its own — the first always waits for you.*
- **`Advance automatically`** — *When a block finishes, a Done screen lets you rate how it felt and jot a note. Turn this on to skip it and go straight to the next block.*
- **`Rest length`** — *The breather between blocks.*
- **`Loop song blocks`** — *A song block loops as an open jam and moves on only when you skip. Off plays it through once, then auto-advances.*

## `Song player`

The same four switches the [player](song-player.md#the-player-settings-sheet) carries behind a hold
on `Loop controls` — one setting, two doors.

- **`Loop control on left`** — *Big Loop and Marker buttons flank the transport bar while idle. Marker sits on the left and Loop on the right by default — turn this on to swap them.*
- **`Show minimap`** — *The full-song overview strip under the waveform. Off gives the waveform and loops a little more room.*
- **`Show marker labels`** — *Floats a marker's name over the timeline as you play up to it. Off keeps labels in the Markers panel only.*
- **`Zoom follows playhead`** — *Pinch-zoom normally keeps the spot under your fingers still. Turn this on to have the window re-center on the playhead as you zoom instead.*

## `Your data`

The hub row shows what Red Moon is holding on disk — your imported song files plus your recordings.
That figure is measured when you open Settings, so it is what is there now, not what was there when
you last looked.

### Export

**`Prepare a copy`** writes everything you have built into a single zip and hands it to the share
sheet, so you can put it in Files, iCloud Drive, or anywhere else you keep things.

Inside are `practice.json` — your songs, loops, markers, exercises, chords, routines, goals, journal
and practice history — and a `takes` folder with the audio of your recordings.

- **`Include recordings`** is on to start with: *Your takes are the one part of an archive nothing else can rebuild, and the largest part by far. Leave this on unless all you want is your notes and settings.* Turned off, the file is small and your takes are still described in it — their notes, their moments, and the name of the missing audio — but the audio itself is not there.
- **`Size`** is an estimate, because how far a zip compresses is not knowable until it is written.
  The exact size appears on the share row once the copy is ready.

Preparing and sharing are two taps rather than one: the file has to exist before the share sheet can
carry it, and on a large library that takes a moment.

**Red Moon cannot read an archive back in.** This is a copy for you to keep, not a restore. If a
recording's audio has gone missing from the device, the copy says how many and carries on.

A take recorded next to a playing song may have picked that song up through the mic. That is worth
knowing before you send an archive anywhere.

Nothing here uploads anything. The file is written on the device and handed to the share sheet; where
it goes after that is entirely your choice. See [your data](../privacy.md).

### Storage

What Red Moon is using on this device, measured when you open the screen, in three lines and a total:

| Line | What it is |
|---|---|
| `Songs` | The copies Red Moon keeps of the audio you imported |
| `Recordings` | Your takes |
| `Practice data` | Everything you have written — loops, exercises, routines, journal, history |

It is measured the same way **Settings ▸ General ▸ iPhone Storage** measures it, so the two figures
are comparable.

- **`Keep songs in backup`** is on to start with: *Your imported song files ride along in your device backup, so a restored phone plays them straight away. Turning this off makes backups much smaller, and means a restored phone needs each song pointed at its file again. Your recordings are always backed up.*
- **`Reclaim space`**: *Deletes audio files left behind by songs and takes you have already removed. It never touches a song or a take you still have.* It tells you how much it freed, or that there was nothing to reclaim — which is the answer you want.

## `Privacy`

One switch, **`Share anonymous usage`**: *Counts of which features get used — how often a loop gets made, which exercises get built. Anonymous and not joined up across sessions, so it can't be traced back to you. Never your audio, notes, song names or artist name.*

<!-- shot: reference/settings-privacy | role: panel
     | alt: The Privacy screen with the Share anonymous usage toggle and its footer
     | state: Settings ▸ Privacy -->

The footer under it states the position you are actually in, which differs by region. The hub row
states it too. What is counted, what never leaves the device, and which rule applies where are all
in [your data](../privacy.md).

## `Help & About`

- **`Version`** — the build you are running.
- **`Help & FAQs`** — the same screen the [Toolkit](tools-and-journal.md#help--faqs) opens, pushed
  onto this stack instead.
- **`Contact Support`** — an in-app form that posts over the internet, so it works with no Mail
  account set up.
- **`Diagnostics`** — what iOS has reported going wrong, and whether any of it travels with a support
  message. See below.
- **`Privacy Policy`** and **`Terms of Use`** — both open in the browser.

### `Diagnostics`

iOS collects crashes and freezes in the background and hands them to Red Moon about once a day, so
something that just happened will not be here yet. An empty screen the morning after a crash is
normal. Nothing on it is sent anywhere on its own.

The last five are listed, newest first, each with its date, what iOS called it, the build it happened
on, and the iOS version. Anything older than roughly three months drops off. `Clear` forgets the list
on this device; it does not stop iOS collecting more.

- **`Include in support messages`** — *Adds one line to your next support message: how many crashes or freezes there were, when, and what iOS called them. It is the line shown on this screen and nothing more — never your songs, your recordings or your notes.*

Off unless you turn it on. Turned on, the line appears under the toggle so you can read it, and it is
shown again inside the contact form before you send — the form always shows everything it attaches.

## Not in a shipping build

There is an eleventh row on the hub in development builds only. It is not present in the app you can
install, and nothing in this manual describes it.
