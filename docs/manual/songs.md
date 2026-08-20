# Songs

Your library is the material you practise against. This page covers getting audio in, describing it
well enough to find later, and repairing a song whose audio has gone missing.

## What you can import

Any DRM-free audio file you can reach from the Files app — downloads you own, rips of your own
discs, backing tracks, bounces of your own recordings, anything in iCloud Drive. Streaming services
are the exception, and the reason is the audio itself rather than a policy choice.

**See Help & FAQs: "What audio can I practise with?"**

## Importing

Tap **+** on Home, or open **Song library** and use **Import a song**. You can select more than one
file at once; a progress indicator appears while they are read.

<!-- shot: songs/import-progress | role: band
     | alt: The import progress indicator over the library while files are being read
     | state: seeded library, Library screen, multi-file import in progress -->

Each import does three things: it copies the file into Red Moon's own storage, reads the whole file
once to draw the waveform, and takes the title from the file name. So a file called
`take-3-final.m4a` arrives as a song called *take-3-final*, which is worth renaming while you know
what it is.

Because the app keeps its own copy, moving, renaming or deleting the original file afterwards does
not affect the song in your library.

### The empty library

Before you have imported anything, the library offers **Import a song** and, under it, **Try the
demo** — a short built-in track with loops and markers already on it, there to have something to
poke at before committing your own music.

<!-- shot: songs/empty-library | role: screen
     | alt: The empty song library showing "No songs yet", Import a song, and Try the demo
     | state: fresh install, Song library, no songs -->

## Finding a song again

A search field sits at the bottom of the library and matches **songs and artists**, which is the
quickest route when you already know what you are after.

### What a row tells you

Each row carries the title and artist, a count of the loops and markers you have saved on it, its
collections as chips, and a five-dot mastery reading. A song you have never rated shows no filled
dots rather than a zero score.

<!-- shot: songs/library-row | role: detail
     | alt: A single library row showing title, artist, loop count, collection chips and the five-dot mastery reading
     | state: seeded library, Library screen, row "Feels" -->

### Sections and sorting

The library groups songs into sections, and you choose what the sections are. The toolbar's sort
control shows the current choice — **↑ Title** by default — and opens a menu offering **Mastery**,
**Recently Added**, **Title**, **Artist**, **Album** and **Genre**, each either **Ascending** or
**Descending**.

<!-- shot: songs/sort-menu | role: panel
     | alt: The library's sort menu open, listing Mastery, Recently Added, Title, Artist, Album and Genre with an ascending and descending choice
     | state: seeded library, Library screen, sort menu open -->

Each section header carries a count and a chevron, and tapping it folds that section away — which is
what makes a library of sixty songs navigable when you only care about one artist today.

### Collections

A collection is your own label — *blues*, *needs-work*, *set list*, whatever is useful. A song can
be in as many as you like, and you add them when you edit a song.

The filter control then narrows the library to the collections you tick. Ticking two collections
shows songs in **either** of them, not only songs in both — so the more you tick, the more you see.

<!-- shot: songs/filter-menu | role: panel
     | alt: The library's filter menu open with several collections listed and two ticked
     | state: seeded library, Library screen, filter menu open, two collections ticked -->

If a filter leaves nothing on screen, the library says so and offers **Clear filter** rather than
looking empty.

## Describing a song

Hold a song's row for **Details**, **Edit** and **Delete** — or open the song and hold its title to
reach the same details.

Songs have no favourite. Exercises, routines and saved loops do, and those you can pin; a song is
found by searching, sorting or filtering instead.

**Details** also carries **Where you learned it** — the transcription, tab page or cover breakdown
you worked from. See [Where you learned it](references.md).

**Edit song** carries **Title**, **Artist**, **Album** and **Genre**, a **Collections** section
where you add your own labels, a key picker, and a **Notes** field for anything you want to tell
yourself later — a tuning, a capo position, what to listen for.

<!-- shot: songs/song-edit | role: screen
     | alt: The Edit song sheet showing Title, Artist, Album and Genre fields with the Collections section beneath
     | state: seeded library, song "Little Wing", edit sheet open -->

The song's **details** show what the app knows and what it has worked out: **Tempo**, **Mastery**
and **Length**, along with your practice stats for it. Mastery here is derived from the loops
underneath it rather than set directly — see [the app's own words](terms.md).

**Exercises for this song** lists the drills you have linked to it, and each one is a way through:
tap it to run it, and the back arrow brings you back to the song. Swipe a row to unlink it —
unlinking never deletes the drill, which keeps its own place in the exercise library.

## Deleting

Swipe a song left, or use **Delete** in its hold menu. A toast appears with an **Undo**, and the
song is only really gone once the toast has passed. Deleting a song takes its loops and markers with
it.

## When a song loses its audio

A song can end up with no audio behind it — most often a library imported by an older version of the
app and carried through a reinstall or a restore from a backup. The library row looks normal; you
find out when you open the song, and the player says what happened rather than failing silently.

<!-- shot: songs/missing-audio | role: panel
     | alt: A song's player showing the audio-unavailable notice, offering Find the file and Not now
     | state: seeded library, a song whose file cannot be found, opened for practice -->

**Find the file** points the song at a file again; **Not now** leaves it as it is. Use it rather
than re-importing: a re-import creates a new song, and your loops, markers, takes and practice
history stay attached to the old one. Pointing the song at a file again keeps the row and replaces
only the sound underneath it.

There is a second door that doesn't need the audio to be broken. **Song details** ▸ **Audio** ▸
**Replace audio file…** does the same job at any time, and its **File** row reads **Missing** for a
song with nothing left to play. That is also how you fix a song pointed at the *wrong* file — worth
knowing about, because pointing a song at the wrong file succeeds quietly: it plays, just not the
song you expected. Check the audio is what you think it is afterwards.

**See Help & FAQs: "My song stopped playing — what happened?"**

## Next

- [The loop workflow, end to end](looping.md)
- [Every hold, swipe and pinch](gestures.md)
