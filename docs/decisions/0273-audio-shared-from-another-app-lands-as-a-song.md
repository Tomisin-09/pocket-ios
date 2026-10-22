# ADR 0273 — Audio shared from another app lands as a song

- **Status:** Accepted. Built 2026-10-22 on `pocket-387-share-audio-in-as-a-song`. Checked on the
  simulator end to end from Files' share sheet, and on the phone from Voice Memos; **Mail, Messages,
  AirDrop and WhatsApp are still to check** (see §Build notes).
- **Date:** 2026-10-22
- **Amends:** ADR 0188 — **D3**: the door opens a third type, and the first the app doesn't own:
  `public.audio`, at `Alternate` rank. 0188 kept the zip out of the Open-with list because a folder of
  holiday photos is not something Red Moon opens. Every audio file is something it practises with,
  which is the test D3 sets. **D9's preview** isn't asked for a shared audio file (D2). The rest of
  D3, and D1, D2 and D4 to D8, stand.
- **Relates to:** 0264 D8 (unchanged: *Save to Red Moon* still takes only links, pictures, PDFs and
  text, and now stays off for audio by a test) · 0148 (a shared song is copied in like any import) ·
  0001 (local files are what the engine practises on) · 0236 D4 (`prepareReceived`, the import this
  reuses) · 0186 D6 (a mailbox from outside the app to Home) · 0272 (leaving a routine asks first,
  which is why a song never pushes past one) · 0149 (a first import arms the walkthrough) · 0111 (a
  recording that goes with a drill is a song linked to it).
- **Schema:** none.

## Context

Tomisin, 2026-10-22, from Voice Memos' share sheet on a phone: *"we need to find a way to share mp3
files directly into the library! And maybe as attachments/references side but I think this
essentially builds a bridge into the app that didn't exist before!"* The sheet offered Voice Memos,
Uber, Chord ai and More. Red Moon wasn't in it.

The app had two doors for things from other apps, and neither took audio. *Save to Red Moon*, the
share extension (0264 D8), turns on only for links, pictures, PDFs and text, by design: Red Moon
appears only for what it keeps. The Open-with door (0188 D3) declared only Red Moon's own two file
types, `.redmoonpractice` and `.redmoonpack`. So a recording made in a lesson or a rehearsal could
reach the practice engine only through **+** and the Files picker, and only if it was in Files at
all. A voice memo isn't.

Decided the same day: **song only**, and **ahead of release 1.4**.

## Decision

### D1 — The Open-with door, for every audio type

`Info.plist` gains a third `CFBundleDocumentTypes` entry: `public.audio`, rank `Alternate`, role
`Viewer`. That puts Red Moon in the app row of a share sheet for any audio file, and tapping it opens
the app with a copy in its inbox, through the same `.onOpenURL` host every received file uses
(`PracticeReceiveHost`). The host tells audio apart by type (`SharedAudio.isAudio`), before it tries to
read a practice file.

- **`public.audio`, not a list of codecs.** A sharing app may call its recording by a type of its own,
  and anything it calls audio conforms to `public.audio`. A list would have to guess Voice Memos', and
  missing it would miss the reason this exists. The in-app picker already offers exactly this type, so
  the two doors take the same files and refuse the same files.
- **`Alternate`**, so Red Moon is offered and never becomes the default for audio. **`Viewer`**: the
  app reads the file and keeps a copy, and never writes the original.
- **Not the share extension.** It can't open its app (0264 D8), so a song shared through it would
  wait in the inbox until Red Moon was next opened, and its waveform would be drawn then. A recording
  shared to a practice app is one the player wants to play now. The system also copies the file before
  the app sees it, so a long recording costs the extension nothing, against an extension's tight
  memory limit. And the extension stays off for audio, which `ShareActivationRuleTests` pins, so the
  sheet never shows two Red Moon icons side by side.

### D2 — It lands as a song, with no preview

The file is copied in and read the way a pack's song is (`SongImporter.prepareReceived`, then
`persist`): Red Moon's own copy (0148), a waveform, and the file's name as the title, as **+** gives it.
The progress overlay **+** uses shows while it's read.

There's no *Add this song?* step. 0188 D9's preview exists because a file somebody else made asks for
a yes before it changes the library. Here the player chose Red Moon in the share sheet, which is the
yes, and the preview would have nothing to show but a name.

**Audio is never a reference.** A teacher's recording of a lick is worth more as a song, where it
loops and slows down, and a song is linked to the drills that serve it already (0111). An audio
reference kind would need a player in the reference viewer, and 0167's 25 MB file ceiling, which a
long recording passes, to be rethought. Not decided here: whether it ever becomes one.

### D3 — It opens if Home can take it, and otherwise the alert offers **Open**

If Home is the screen showing, with nothing of its own over it or on its way, the song opens on its
waveform, the way **+** opens a single import. The screen appearing is the confirmation.

Anywhere else, a routine running or a song already open, nothing moves. The song is in the library
and the alert says *"“AUDIO-2026-10-11-04-53-45” is in your songs."*, a pack's words, with **Open**
and **OK**. Pushing past a running routine is the leave 0272 makes the player confirm, and a file
arriving is not the player choosing to leave. Tapping **Open** is.

**Open shows the song player as a full-screen cover over the screen the player was on.** Its back
chevron dismisses, which inside a cover closes the cover, so Back puts the player where they were. A
cover and not a sheet, because the song player rotates (0042) and holds a keep-awake lease, and
neither survives a sheet (0172). It doesn't navigate Home's stack: most of Home's doors are
`NavigationLink`s that Home can't pop, so opening from anywhere by navigation would mean rebuilding
Home's navigation on a path. Tomisin, on seeing the alert on the phone: *"is there any way we could
make it less work than it seems for example providing an option in the alert that can take you to
the song?"*

The host imports, and Home owns the stack the waveform is pushed on, so they meet through
`SharedSongArrival`: Home writes whether it can open a song, and the host hands one over or says it
landed with **Open** on its alert (`SharedSongCover`). Home knows it's on top from `onAppear` and `onDisappear` on its stack root, since every door on
Home pushes, and from its own flags for its covers and imports.

## Consequences

- **Red Moon appears for every audio file in every share sheet that lists Open-with apps**, including
  formats it then can't decode. Those say *"That audio file couldn’t be read."* This is the same set
  **+** offers and refuses, so it adds no new refusal.
- **A song shared twice is two songs**, as a file picked twice through **+** is.
- **The alert has the root host's limit.** An alert at the app's root may not present over a
  full-screen cover. The song is still kept. This is the limit a pack's *Added* already has.
- **App Store Connect shows the new document type.** It's a type the app exercises on every share, so
  AGENTS.md's rule on declared capabilities is met.

## Alternatives rejected

- **Widening *Save to Red Moon* to audio.** See D1: it can't open the app, and a song wants playing now.
- **Both doors at once.** Two Red Moon icons in one share sheet, doing different things.
- **An audio reference kind.** See D2.
- **The preview sheet first.** See D2.
- **Always opening the song**, wherever the player is. See D3.
- **Opening it from the alert by navigation**, popping Home's stack and pushing. See D3: Home's
  `NavigationLink` doors can't be popped without moving Home onto a navigation path.
- **A list of audio types** instead of `public.audio`. See D1.

## Build notes

- **Built:** `SharedAudio` (what counts as audio, the two messages), `SharedSongArrival` (the mailbox),
  the host's `openAudio`, `HomeView+SharedSong` (`canOpenSharedSong`, `openSharedSong`), the
  `Info.plist` entry, and `SharedAudioSeed` behind `-receiveSharedAudio` for the UI test.
- **Tests:** `SharedAudioTests` (what's audio, Red Moon's own types aren't, the title, the declaration
  read out of the built app, the owned types still owned), `ShareActivationRuleTests` (the extension
  stays off for audio), `SharedAudioUITests` (a shared tone opens on its waveform with no alert; and,
  over the song library, the alert's **Open** shows the player, which turns to landscape in its cover
  and whose Back leaves the library showing). The second test uses `-receiveSharedAudioOnReturn`,
  which hands the file over on the app's first return from the background, as a share does.
- **On the phone, 2026-10-22:** shared from Voice Memos with Red Moon away from Home, the song landed
  and the alert showed, which is what prompted **Open**.
- **Seen on the simulator, 2026-10-22** (iPhone 17, iOS 26.5), by a throwaway UI test that drove the
  Files app and was then deleted: an `.m4a` in *On My iPhone*, held, **Share**. The sheet's app row
  held **one** Red Moon, then More. Files described the file as *Audio Recording*, the words Voice
  Memos' sheet used. Tapping Red Moon opened the app on the recording's waveform, titled
  *AUDIO-2026-10-11-04-53-45*, with nothing in between. That is the real path: the system's copy into
  the inbox, `.onOpenURL`, the import, and Home's push.
- **A test note.** `UITestCase.launchApp` waits for Home's seeding marker, which a song opened over
  Home at launch takes out of the tree, so `SharedAudioUITests` launches the app itself.
- **Owed, on a device** (no kept UI test can drive another app's share sheet, 0264 D10.6):
  1. Mail and Messages attachments, and AirDrop. (Voice Memos, the case this ADR began from, is
     done: see *On the phone* above.)
  2. A WhatsApp voice note, usually `.opus`, and whether the decoder reads it.
  3. Sharing while a routine runs: the song is kept and the alert appears, or the alert doesn't
     present over the routine's cover (Consequences).
