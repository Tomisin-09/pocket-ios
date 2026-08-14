# Home and the Song library

## Home

The whole map. There is no tab bar: every screen opens from here and comes back here.

<!-- shot: reference/home | role: screen
     | alt: The Home screen with the greeting, Start today's session, Jump back in, the Practice section and the Your stuff section
     | state: seeded library, Home, one song recently practised -->

**Top bar.** A gear on the left opens [Settings](settings.md); the label is `Settings`. A green **+**
on the right is `Add a song` and opens the file picker.

**The greeting** changes with the time of day and, once you have given one, carries your artist name.
Under it, `Ready to practice?`.

**A trial countdown** sits here while one is running — see [subscription](../subscription.md).

**`Start today's session`** is the filled teal card, and the primary action. It builds a session from
your goals. Without Red Moon Pro it draws a padlock and opens the paywall instead.

**`JUMP BACK IN`** appears once you have practised a song, and carries that song, its artist, when
you last played it and its mastery. Tapping it reopens the [song player](song-player.md).

**`Practice`** — one card, subtitled `Your exercises & training runs`, opening the
[Practice hub](practice.md). **`Metronome`** sits beside it, subtitled
`Standalone click & tempo trainer`, and opens over the whole screen.

**`Your stuff`** holds three more: **`Song library`** with its song count, **`Journal`**
(`Your notes & practice takes`) and **`Toolkit`** (`Tuner, your chords & a glossary`).

**`Recent routines`** is a horizontal rail of routines you have played, each showing its block count.

Of those, only Journal and Toolkit are outside Red Moon Pro. The rest draw a padlock without it.

### The first run

A fresh install asks a short set of optional questions before anything else — your name and how you
play — and then, once you have practised, may ask about anonymous usage counts depending on where
you are. Both are covered in [getting started](../getting-started.md) and [privacy](../privacy.md).
The library starts empty; Home shows no `JUMP BACK IN` card and no rail until there is something to put
in them.

## The Song library

Reached from `Song library` on Home.

<!-- shot: reference/library | role: screen
     | alt: The Song library grouped into lettered sections, each row showing title, artist, loop and marker counts, collections and mastery
     | state: seeded library, Library, sorted by title -->

**Top bar.** The sort control on the left is `Sort by`, and its glyph states the current order.
Beside it, `Filter by collection`. On the right, `Import songs`.
Underneath, a search field prompting `Songs and artists`.

**A row** carries the title, the artist, its loop and marker counts, any collections it belongs to,
and its mastery out of five. Tap it to open the [song player](song-player.md).

**Sections** group the list under whatever you are sorting by — initial letters under `Title`,
bands under `Mastery` — and each header carries a count. Sections collapse.

### Sort

The sort control opens a menu of `Title`, `Artist`, `Album`, `Genre`, `Mastery` and
`Recently Added`, plus `Ascending` / `Descending`. The chosen key is what the sections are built
from, so changing it re-groups the list as well as re-ordering it.

### Filter

`Filter by collection` opens the facets you have actually used — collections, and the other
descriptive fields a song can carry. Within one facet the choices widen the result; across facets
they narrow it.

### The row's hold menu

Hold a row for `Details`, `Edit` and `Delete`. There is no delete swipe here, and no favourite.

<!-- shot: reference/library-row-menu | role: detail
     | alt: The hold menu on a song row offering Details, Edit and Delete
     | state: seeded library, Library, a row held -->

### `Song details`

A read-only summary, with `Edit` in its toolbar.

<!-- shot: reference/song-details | role: screen
     | alt: The Song details sheet showing the title and artist, notes, key, tempo, mastery, length and the audio file section
     | state: seeded library, Little Wing, Details from the row hold menu -->

- The title, artist, and album with its year.
- `Notes` — free text about the song, with `Edit notes`.
- `Key`, `Tempo`, `Mastery` (with its ⓘ) and `Length`.
- **`Audio`** — the `File` row, which reads *Missing* when the audio no longer resolves, and
  `Replace audio file…` beneath it. The app's own words for what that does: *Points this song at a
  different file — for a song whose audio is missing, or one linked to the wrong track. Your loops,
  markers, takes and practice history all stay with the song.*
- `Collections`.
- **`Exercises for this song`** — drills linked to it, with `Link exercises` and
  `Build a routine for this song`. Empty, it reads *No drills linked yet — link the exercises that
  help you play this song.*
- **`Practice stats`** — counts of `Loops`, `Markers` and `Annotations`.

### `Edit song`

<!-- shot: reference/song-edit | role: screen
     | alt: The Edit song sheet with title, artist, album, genre, year, BPM, downbeat and the major/minor key picker
     | state: seeded library, Little Wing, Edit from the row hold menu -->

`Cancel` discards, `Done` keeps. It carries:

- **`Details`** — `Title`, `Artist`, `Album`, `Genre`, `Year`, `BPM` and `Downbeat (s)`.
- **`Key`** — a `Major` / `Minor` switch and the twelve roots, with `Clear` to unset it.
- **`Collections`** — `Add a collection`.
- **`Notes`**.
- **`Practice stats`**, read-only, as above.

### Importing

`Import songs` opens the system file picker; you can choose several at once, and a progress
indicator runs while they are read. Files are copied into the app, so the original can move without
breaking the song. The empty library offers **`Import a song`** and **`Try the demo`** instead.

Procedure for all of this is in [songs](../songs.md).
