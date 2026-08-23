# ADR 0148 — a song you import is a file we keep

- **Status:** Accepted
- **Date:** 2026-08-07 (`pocket-242-songs-we-own`)
- **Supersedes in part:** ADR 0001's custody clause — *"imported via the Files picker and held by
  security-scoped bookmarks"*. **The source decision stands unchanged**: the practice engine is still
  built on DRM-free local and iCloud Drive files, and Apple Music is still browse/metadata only. What
  changes is who holds the file, not which files qualify.
- **Extends:** ADR 0069 §5 (`RecordingStore` — the existing pattern for files the app owns)

## Context

The StoreKit sandbox pass for ADR 0144 required a restore-on-wiped-install test: delete the app,
reinstall, confirm the Pro entitlement returns. The app has no CloudKit and no export, so the
library was backed up first by pulling the app data container off the device, and pushed back
afterwards. The store came back byte-perfect — `PRAGMA integrity_check` clean, 15 songs, 33
exercises, 12 routines, 54 loops, 30 journal entries, 26 practice runs, 3 takes.

**Not one song would play.** Every security-scoped bookmark had gone stale. A bookmark encodes
access granted to a particular installation; deleting the app revokes it, and no amount of restoring
the database brings it back. The library looked completely intact and was completely inert.

That is not an artefact of the test rig. It is the exact experience of a customer who changes phone
by restoring an iCloud or Finder backup — the single most common way people migrate. iOS restores
the app container, so the store returns in full, and every song in it is dead. The same failure
already existed in narrower forms that were easy to dismiss as user error: the file gets moved,
renamed or deleted in Files, or iCloud Drive evicts it.

Bookmarks were a defensible default. They duplicate nothing, they respect however the user has
organised their own music, and ADR 0001 was answering a question about *sources* — whether Apple
Music audio could be tapped — not about custody. The custody clause rode along unexamined.

The cost of revisiting it is lowest now. v1 is approved and held, so there are **zero users**.
Changing where song audio lives after release would mean migrating real libraries whose bookmarks
may already have gone stale — a migration that cannot reach the files it needs to copy. Before
launch it costs one additive attribute and one extra write at import.

## Decision

### 1. Import copies the file into the container

`SongImporter.prepare` already opens the picked file under its security scope and decodes it
end-to-end for the waveform. The copy happens there, while the file is open and off the main actor,
into `Application Support/Songs/`, named by the song's `sourceID` with the original extension
preserved so the decoder still recognises it.

This mirrors `RecordingStore` exactly (ADR 0069 §5): `Application Support`, not `Documents`, because
these are app-managed artefacts rather than user-facing documents; leaf filename stored on the model;
`FileManager` injected so the derivations stay unit-testable.

### 2. Resolution prefers the copy, and falls back to the bookmark

One resolver, `SongAudioResolver`, replaces three near-identical `loadImportedFile` implementations
that had already drifted apart (only two of the three refreshed a stale bookmark). Order:

1. The owned copy, if `fileName` is set and the file is on disk. No security scope needed — it is
   inside our own container.
2. The bookmark, for songs imported before this ADR.
3. Neither → the failure notice.

### 3. A legacy song adopts itself the first time it resolves

When a pre-0148 song resolves through its bookmark, the file is copied in and `fileName` recorded, so
the *next* launch takes path 1. This is the migration: it needs no schema version, it runs only when
the file is provably reachable, and a failure leaves the working bookmark untouched. The precedent is
`refreshWaveformIfOutdated`, which self-heals pre-0017 waveforms the same way.

### 4. Loops and markers never move, whatever happens to the audio

`SongRef` identity is `(id, source)` with the bookmark deliberately excluded — ADR 0001's consequence
that "local files can own loops and markers". `fileName` is excluded on the same grounds. Changing
where a song's audio lives, relinking it, or losing it entirely must never orphan the practice data
attached to it. **This is the invariant to protect if anything here is revisited.**

### 5. The bookmark is kept, not deleted

It stays as provenance — where this song came from — and it is what makes §3 possible. It is no
longer the primary resolution path.

### 6. Relink is the repair path

For a song where neither the copy nor the bookmark resolves, the player points it at a file again.
Because of §4 this preserves loops, markers, takes and practice history. It is the only route back
for libraries that predate §1 and are already broken — including every song imported before today,
where re-importing would make a *new* song and strand everything attached to the old one.

**The door is the failure itself.** "Find the file" is the primary button on
`AudioUnavailableNotice`, so the repair is offered at the moment and place the problem is
discovered, rather than filed away in a settings screen the player would have to know to look for.
`SongRelinker` splits `prepare`/`apply` exactly as `SongImporter` does, for the same Swift-6 reason:
a `Song` and a `ModelContext` are not `Sendable`, so only the `sourceID` crosses to the detached
decode.

**A relink re-extracts the waveform**, because it can legitimately point at a different encode and
drawing the old envelope over new audio would put every loop boundary in the wrong place.

**A materially different length warns and changes nothing else.** If the new file's duration differs
by more than a second it is a different recording, not a re-encode, and loops past the new end will
not play. The player is told; their loops are not deleted. Guessing that a mismatch means the loops
are worthless would destroy work to tidy up a number.

### 7. The bundled demo song is dropped

`SongPresets` seeded one curated song on first launch — *Binta* by Jack Trader, bundled and used with
the rights holder's permission. It goes, along with the file and `Documents/DemoAudio/`.

It was the app's **only** bundled third-party content, and it carried a disproportionate tail for
what it delivered: an App Store Connect *Content Rights* declaration that could no longer say "no
third-party content", a permission to keep straight for the life of the app, 2.6 MB in every
download, and a second code path holding a bookmark to a file — the very mechanism this ADR exists to
retire. In exchange, every player got the same song, which none of them chose, in an app whose entire
premise is practising the music *you* are working on.

The library now starts empty. Exercises and routines still seed; those are Pocket's own content and
are the same for everyone by design.

Existing installs keep the demo song they already have — it is a row in their library, and deleting a
user's data on their behalf is not this ADR's business.

> **Correction (2026-08-09).** This section is wrong on one point of fact, and the record should say
> so rather than be quietly rewritten: the demo track was **not third-party content**. It is the
> author's own composition, written and recorded in GarageBand. So the *Content Rights* declaration
> and the third-party permission described above were never the burden this section claims — that
> part of the rationale does not hold.
>
> **The decision still stands**, on the reasons that survive: 2.6 MB in every download, a second code
> path holding a bookmark to a file, and every player receiving the same song none of them chose, in
> an app whose premise is practising the music *you* are working on. Dropping it was right; one of
> the four reasons given for it was not real.
>
> One consequence worth recording, because it is being relied on: since the track is the author's own,
> it can be **distributed directly to closed-beta testers** as a starter file. A fresh install has no
> song and streaming audio cannot be used (ADR 0001), so without one a tester cannot reach the core
> loop at all. See `docs/plans/beta-testing-plan.md`.

### 8. Owned files are swept, like takes are

`SongFileStore` carries the same orphan sweep and size reporting as `RecordingStore`: a file with no
surviving `Song` referencing it is safe to delete. Owning files means owing the user honesty about
disk use.

## Consequences

- **Audio is stored twice** — once wherever the user keeps it, once in our container. Accepted: it is
  user data that cannot be re-downloaded, which is exactly what a backup is for.
- **Device backups grow** by the size of the library. This is the mechanism by which the fix works;
  a backup exclusion would defeat the entire ADR.

> **Amendment (2026-08-23, ADR 0182).** This line still holds and is not being walked back — but it
> now describes a **default** rather than the absence of an option.
>
> ADR 0182 adds *Settings ▸ Your data ▸ Keep songs in backup*, **on by default**, which is exactly
> the behaviour this ADR chose. A player who never opens that screen is in precisely the position
> this ADR put them in, for precisely the reasons above. What 0182 adds is the ability to take the
> other side of the trade **knowingly**: the ⓘ copy states the cost in the same breath as the
> benefit — a restored device needs each song pointed at its file again.
>
> Takes are **never** excluded, on this ADR's own logic pushed one step further: a song's audio came
> from a file the player still has and can point Red Moon at again, and a recording of them playing
> came from a moment that is gone.
>
> Two things this ADR promised and did not deliver were also found unkept and are fixed there rather
> than here, so the record of what this ADR shipped stays accurate: §8's honesty about disk use had
> no screen behind it, and the orphan sweep it introduced had **no production caller at all**.
>
> ⚠ **The exclusion must not become a default** until the relink door is widened — `LoopRunView` and
> `SongPlayAlongView` are dead ends when audio is missing. See 0182 §6.
- **Deleting the original in Files no longer breaks the song.** A behaviour change, and a welcome one.
- **Import gets slower** by one file copy, on a path that already reads the whole file.
- **This does not make songs follow you to a fresh phone.** A device set up without restoring a backup
  starts empty, and nothing short of sync changes that. Sync is Phase 4 and is not promised here.
- **Deleting the app still destroys everything**, copies included. Unchanged — it already destroyed
  the store.
