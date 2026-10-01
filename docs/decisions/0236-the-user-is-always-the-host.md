# ADR 0236 — The user is always the host: takes, songs, routines with their songs, and tabs leave as files

- **Status:** Accepted. To be built on `pocket-342-export`, in the five slices of the build order.
- **Date:** 2026-10-01 (decided 2026-09-30 and 2026-10-01; the design sketch is the artifact
  *Red Moon Export*)
- **Supersedes:** ADR 0150 — its parked proposal is decided. Export is accepted on the tool-not-host frame
  (D1), without the legal review it waited on. Its proposed points 1 (export only, hosting closed),
  2 (a share action on the take rows), 4 (one take at a time) and 5 (mic-only) are taken as written.
  Point 3, the speaker-bleed warning at export, is dropped for a single take (D2).
- **Amends:** ADR 0181 — **§7**: per-take sharing is no longer parked (D2). **D5**: its `.forUploading`
  zip is written for a second file, the pack (D8). The archive itself is unchanged: it still carries
  takes and reference pictures, not song audio, and its speaker-bleed line stays.
- **Amends:** ADR 0188 — **D3**: a second file type, `.redmoonpack`, for practice that carries audio
  (D8). `.redmoonpractice` is unchanged and stays JSON. **D4**: song and loop blocks travel with their
  songs when *Include the songs* is on (D6), and arrive as today's placeholders when it is off. Its
  last paragraph (no take crosses in a routine) stands. **D8**: the zip reader reads a second file we
  wrote, so the pack's zip method is part of its format too. D1, D2, D5, D6, D7 and D9 stand.
- **Amends:** ADR 0232 — **D12**: the Export tab is no longer waiting on a legal review. A song's tab
  exports as text or PDF (D9). No hosting, no importing, and never inside a routine file all stand;
  the last now stands because a song sent in a routine carries no pieces (D4). D12 cited the
  support-message ADR for "carries no song titles", which was a wrong number.
- **Amends:** ADR 0113 — *the profile never leaves the device without an explicit, later, opt-in
  decision of its own*: this is that decision, for the artist name only (D7). It goes in a file the
  player sends, and the send screen shows it first. Sound, influences, goal and minutes stay on the
  device.
- **Relates to:** 0064 (unchanged: no hosting, no community library; a file handed to the share sheet is
  not its rail) · 0001 (Apple Music is DRM, so it can't export) · 0148 (the song copy we keep is what
  exports) · 0069 (mic-only takes) · 0235 D9 (a tab stores order, not lengths) · 0209 (payload kinds) ·
  0161 D3 (show what gets sent) · 0120 (one pinned dependency) · 0090 (uids) · 0189 (additive schema) ·
  0165 (the manual quotes the app).
- **Schema:** none. No `@Model` changes. The shared file gains two **optional** fields, `songs` and
  `senderName`, and a third kind, `song` (D4, D7). Optional is load-bearing: a Codable default does not
  survive a missing key, and every `.redmoonpractice` already sent has neither field.

## Context

ADR 0150 asked whether a take could leave the device, and parked the answer pending legal advice. Two
later ADRs routed around it. 0181 exported a whole-library backup and said in §7 that it "does not
unpark per-take sharing". 0188 handed routines over as files, but turned every song and loop block
into a named placeholder because "audio never leaves the device". 0232 D12 parked a song's tab behind
the same review.

On 2026-09-30 the owner decided the question on a different footing. The audio in Red Moon is the
player's own file. Red Moon has no part in how it reached the phone, and it plays the files the way a
DAW does. When a file leaves through the share sheet, wherever it lands holds it. **The user is always
the host.** No legal review happened, and this ADR is not evidence that one did. The decision is the
owner's, as the 0181 self-export decision was.

## Decisions

### D1 — A tool, not a host and not an inducer

Red Moon stays a **tool** as long as it does neither of two things:

- **Host.** Hold a file and serve it to other people. That is ADR 0064's rail and it stays closed: no
  account, no shared library, no Red Moon copy of anything a player exports.
- **Induce.** Sell export as a way to share music. So the words are always about taking your own work
  somewhere to work on it:

| Say | Never say |
|---|---|
| *Export take…* | *Share this song* |
| *Send this song…* | *Share with friends* |
| *Export audio file only…* | *Post* |
| *Send this routine* | *Download songs* |
| *Take it into your DAW*, *send it to your teacher* | *Add a song from a link* |

Three limits hold whatever the frame:

- **Apple Music can't export.** It is DRM-protected and never reaches Red Moon as a file (0001).
- **No import from a link.** App Review 5.2.3 forbids saving media from third-party sources. Songs come
  in from Files and nowhere else.
- **The privacy line holds.** *"The app has no audio upload path"* stays true: a share sheet transmits
  nothing, and the app never learns where the file went.

### D2 — A take

**Export take…** (`square.and.arrow.up`) on a take's hold menu, in the Journal and on a loop's Takes
sheet, and in the take's own *Take actions* menu (0174), each time above Delete. It hands the share
sheet the take's file as it is: no re-encode, and a trimmed take sends what the trim kept.

- **Its name says where it came from:** the take's title if it has one, otherwise its owner caption,
  then the date. `Slow Bend · Chorus · 1 Oct 2026.m4a`. A standalone take with no title is
  `Take · 1 Oct 2026.m4a`. Characters a file name can't hold are replaced.
- **The file is staged only when a destination is picked.** A copy goes into `tmp/` under that name at
  that moment, not on every pass of the view. The take in `RecordingStore` is never renamed or moved.
- **No speaker-bleed warning.** 0150 asked for one because a take recorded over a speaker carries the
  song. Under D1 that is no longer a reason: the song itself exports (D3), and a take with the song
  faintly behind it carries less of it than that. 0181's line on the archive screen is a fact about
  recordings, and it stays.
- **One take at a time** (0150 point 4). No batch export.

### D3 — A song's audio file

**Export audio file only…** in Song details › Audio, under *Replace audio file…*. It hands over the
copy Red Moon keeps (0148) in the format it was imported in, named for the song: `Slow Bend.mp3`.
Only the audio leaves. This is the DAW door: a DAW can't read loops.

Only the copy Red Moon keeps exports. A song whose audio is missing has no row, and neither does an
older song still linked to a file outside the app (0148's bookmarks): it gets a copy of its own the
first time it plays, and exporting through the bookmark would mean holding its security scope open
until the share sheet had read the file, which nothing can promise.

### D4 — Send a song, with its loops and markers

**Send this song…** in the same section, above D3's row, opens a send screen and then the share
sheet. A song goes to another Red Moon with what's needed to practise it, and none of the sender's
practice:

| Goes with it | Stays with the sender |
|---|---|
| the audio file | the song's pieces and tab (every loop's transcription, kept versions too) |
| title, artist, album, genre, year, key | mastery and the speeds reached (`mastery`, `masteryAtSpeed`, `lastPracticedSpeed`, `commandTempo`) |
| tempo and beat grid (BPM, downbeats, meter) | takes and journal notes |
| every loop: name, start, end, speed, repeats, type, tags, colour, ramp and automator settings, repeat reach | when it was last practised, snags, span changes |
| every marker, with its sections and *same as* | collections, favourites, skills, reference links, linked exercises |

**There is no loop export.** A loop is a start and an end on its song, a speed and a ramp. It is not
audio, so it travels inside its song and nothing is rendered. A loop on its own, or an audio clip of
one, is not offered.

**The receiver always gets a new song.** Every uid is minted fresh (0188 D1: a receive never
collides), the audio is copied in as an import is (0148), and the received song's mastery starts
empty. The title follows D5. A received song is an imported song from then on: the same gates, the
same relink.

It travels as kind `song` in a pack (D8): one `SongRecord` in `songs`, with its audio in `songs/`.

### D5 — The receiver's copy is named so it can be told apart

When the receiver already has a song with the same title, the new one is named
**`<title> - <sender's artist name> copy`**. With no name in the file: **`<title> - copy`**. If that
name is taken too, it is numbered, the way Finder numbers copies: `Low Road - Tomisin copy 2`.

**The match is on the title**, trimmed and ignoring case. A song's `sourceID` is minted fresh on every
import (`SongImporter`), so the same recording has a different id on every phone and can't be matched.
Since a copy is made either way, the title only decides the name. Audio is never compared.

The preview says what will happen before **Add**: *You have a song called Low Road. This one goes
beside it.*

### D6 — A routine, with its songs

The routine's share button opens a **send screen** before the share sheet. It holds an **Include the
songs** switch:

- **Shown only when the routine has a song or loop block,** and **on** by default there. A routine with
  neither goes straight to the share sheet as today.
- **On:** every song a block plays travels as D4 sends it, with all its loops and markers, not only
  the ones the blocks use. The blocks are bound to the arrived loops and songs. The file is a pack (D8).
- **Off:** the blocks arrive as today's named placeholders (0188 D4), and the file is a
  `.redmoonpractice`, byte for byte the shape it is today apart from D7's name.

The screen also lists what goes and what stays, and says how much the songs add.
**No take crosses in a routine**, whichever way the switch is set (0188 D4's last paragraph).

The receive preview gains a **Songs** section, one row per arriving song under its D5 name.

### D7 — The sender's name travels, and is shown first

The file carries `senderName`, the player's artist name (`Profile.artistName`, Settings › You), or
nothing when they have none. The send screen shows it at the top, *Sent as Tomisin*, before anything
is sent (0161 D3: show what gets sent, don't only disclose it). The receive preview says *Sent by
Tomisin from Red Moon 1.3 on …*, and D5 names copies with it.

Only the artist name. Sound, influences, goal and minutes stay on the device (0113).

### D8 — The pack: one file, with a zip inside

A song, or a routine with its songs, is several files: the practice JSON, and an audio file per song.
They have to arrive as one, because the receiver taps one file and the system hands Red Moon only
that one.

**`.redmoonpack`** (`click.decooperations.pocket.pack`, *Red Moon practice pack*) is a zip:

```
Tuesday warm-up/
├─ practice.json      SharedPractice: the routine or song, songs, loops, markers, sender's name
└─ songs/
   ├─ <audioFileName>
   └─ <audioFileName>
```

- **Both halves already exist.** It is written by `ArchiveWriter`'s `.forUploading` zip (0181 D5) and
  read by `ZipArchiveReader` (0188 D8). No dependency is added (0120).
- **Its own type, because `.redmoonpractice` is declared as JSON** (`Info.plist`), and a zip isn't. It
  conforms to `public.data`, not `public.zip-archive`, so the system treats it as a Red Moon file rather
  than something to unpack. It is added to `UTExportedTypeDeclarations` and `CFBundleDocumentTypes`,
  and both receive doors (the tap and *Receive a routine…*) accept both types.
- **`.redmoonpractice` is unchanged.** An exercise, and a routine sent without its songs, stay JSON.
  Every file already sent still opens.
- **The zip method is part of the format** (0188 D8), now for two files. The reader's tests read a
  pack the current writer wrote.

**Rejected:**

- *Separate files* (the JSON plus loose audio). The receiver taps one and the app gets only that one;
  Messages and Mail show the rest as loose attachments to find by hand.
- *Audio inside the JSON as base64.* One file, but a third bigger, and held in memory whole.
- *Apple Archive.* iOS reads and writes it both ways, but nothing outside Apple's systems opens it, and
  zip already works here.
- *A zip package from outside.* 0188 D8 refused it, and nothing has changed.
- *Turning `.redmoonpractice` into a zip.* It would change a format already in people's hands, and an
  exercise has no audio to carry.

### D9 — A tab, as text or PDF

Both kinds of tab: one written in **My tabs** (0235) and a song's tab from **Map the song › Tab**
(0232 D10). The tab's reading screen gets an **Export** menu (`square.and.arrow.up`) with **Plain text**
and **PDF**.

- **Plain text and PDF only.** A tab stores the order of its notes, not their lengths (0235 D9), so the
  export is evenly spaced, and MusicXML or Guitar Pro would have to invent the rhythm.
- **One pure formatter** turns a tab into lines of text. It reuses `TabLine`'s strings and marks and the
  rows `PieceStaff` and `SongTabLayout` already lay out, so the file reads like the screen. The PDF draws
  those lines in a fixed-width font on A4, or US Letter where the locale measures in inches.
- **A song's tab carries the song's title and artist** at the top, its sections with their bar ranges,
  chord symbols and by-ear names on their own lines above the strings. A written tab carries its title
  and its instrument and tuning.
- **Never hosted, never imported, never inside a routine file** (0232 D12).

## What stays out

- Hosting, a shared library, any account (D1, 0064).
- Import from a URL, a streaming service or another app's library (D1).
- A loop on its own, an audio clip of a loop, audio rendered at practice speed (D4).
- Pieces and tab in a sent song (D4), and tab import of any kind (D9).
- Batch export of takes (D2).
- MusicXML, Guitar Pro, MIDI (D9).
- Analytics for any of it. No event is added.

## Build order

Each slice stands on its own and is shippable alone; the last two share the pack.

1. **Takes (D2).** Export take… on both hold menus and the take's own screen; the pure file-name rule;
   the staged copy.
2. **A song's audio file (D3).** Export audio file only… in Song details › Audio.
3. **Tabs (D9).** The pure text formatter for both sources; the PDF renderer; the Export menu on My
   tabs' reading screen and on Map the song's Tab view.
4. **The pack and Send this song (D4, D5, D7, D8).** The `.redmoonpack` type and its declarations; the
   pack writer and reader; kind `song`; the send screen; the receive preview's Songs section; the D5
   naming rule (pure, tested); `senderName`.
5. **A routine with its songs (D6).** The send screen in front of the routine's share button; the
   switch; binding blocks to arrived loops and songs.

## Consequences

- **The privacy texts stay true and must be re-read.** *No audio upload path* holds (D1). Any line that
  says the artist name or profile never leaves the device needs *unless you send it*, in the manual
  and in the live policy (`uk-site`).
- **The manual changes** (0165): the Journal and Takes hold menus, Song details › Audio, the routine
  share flow, receiving, My tabs and Map the song. Each slice updates its pages.
- **Figures go stale** for the same screens. They join the one reshoot that is still owed.
- **The file format grows a second container.** Anything that reads `.redmoonpractice` must keep
  reading it unchanged; the pack is additive.
- **A teacher can now send a whole lesson**: a routine with its backing tracks and the loops already
  cut, ready to practise. That was the job 0188 described and could only half do.
