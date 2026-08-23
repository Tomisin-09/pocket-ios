# ADR 0182 — what it is using

- **Status:** Accepted
- **Date:** 2026-08-23 (`pocket-284-what-it-is-using`)
- **Relates to:** ADR 0148 (Red Moon owns its song copies — **amended**, not reversed, see §6), ADR
  0069 (practice takes, and the retention story whose sweep this finally runs), ADR 0151 (a take
  outlives its loop), ADRs 0179 + 0180 (routine blocks record takes, which widens who writes them),
  ADR 0152 (a link you can correct), ADR 0181 (the screen this lands on), ADR 0162 (the Settings
  hub), ADR 0165 (the manual quotes the app)
- **Schema:** none. One new `UserDefaults` key (`songsInBackup`), already covered by the privacy
  manifest's CA92.1 declaration. No `@Model` changed.

## Context

ADR 0148 §8 promised it in as many words: **owning a player's files means owing them honesty about
the disk those files take.** That promise was unkept for four months, and while it was, a blind-spot
review on 2026-08-22 found two real leaks running behind it.

**Deleting a song leaked its audio.** `LibraryView+GroupedList` held the app's only song-delete path
and it was a bare `context.delete(song)`. Every song any player has ever removed left its full-size
copy in the container — silently, permanently, and with no way to see it or reclaim it.

**The orphan sweep was dead code.** `SongFileStore.orphanedFiles` and `RecordingStore.orphanedFiles`
have existed since ADR 0148 and ADR 0069, along with `filesOnDisk` on both. All four were
unit-tested. **None had a production caller.** `docs/architecture.md` described the retention story
as though it ran; it did not, and the same absence meant a `.trimtmp.m4a` stranded by a crash
mid-trim — which `TakeTrimmer` deliberately keeps the `.m4a` suffix on *so a sweep would catch it* —
was never caught by anything.

And there was no way to see any of it. No storage figure anywhere in the app.

## Decision

**`Settings ▸ Your data` gains a Storage section: what the app is using, broken down; a backup
choice; and a sweep that reclaims what nothing points at.**

### D1 — the figure is measured, not estimated, and it is comparable

`StorageUsage` sums `Songs/` and `Recordings/` through the two stores' existing `filesOnDisk` and
`fileSize`, plus the SwiftData store and its `-wal`/`-shm` siblings. Pure and `Sendable`, with the
one impure function taking its `FileManager` by argument so a test can point it at a throwaway
container and get real numbers back.

`.file` count style, which is what the platform's own Storage screens use — so a player comparing
Red Moon's number against *Settings ▸ General ▸ iPhone Storage* is comparing two figures computed the
same way. That comparison is the only check a player can actually perform, and it is worth not
breaking.

The `-wal` is counted rather than hidden. Between checkpoints it can hold a real fraction of the
database, and a figure that ignored it would sit quietly below the system's for a reason nobody could
discover.

**The store URL comes from the live `ModelContainer`'s configuration**, never from a guessed
`Application Support/default.store`. That keeps `StorageUsage` free of SwiftData and keeps the
measurement right if the store ever moves.

### D2 — the two leaks are fixed, and one of them got its own file to be fixed in

`SongDeletion.perform` is a six-line seam that deletes a song's audio and then its row. It exists as
a separate testable type rather than two lines in the view because **the bug was an absence**, and an
absence passes every build and every existing test. It can now be neutralised and watched to fail.

Safe without a reference check: `SongImporter` mints a fresh `sourceID` per import and the leaf is
named for it, so a file belongs to exactly one song even when the same source is imported twice.
Safe against Undo: `RowDeletionCoordinator` defers `perform` until the undo window closes, so an
undone delete never reaches it.

`OrphanSweep.run` composes the two pure sweeps, measures **before** deleting (afterwards there is
nothing left to measure), and reports what it freed. It is offered as *Reclaim space*.

⚠ **The referenced set is built from every row, never from one owner's relationship.** A take
outlives its loop by design (ADR 0151) and routine blocks record takes now too (ADRs 0179/0180), so a
narrower set would classify real recordings as rubbish and delete them. This is the one way this
feature could destroy a player's work, and it is the only thing here with a test written from the
destructive direction.

"Nothing to reclaim" is phrased as the good answer it is. A sweep that finds nothing means the app
has not been leaking; wording it as a failure would teach players to keep pressing a button with
nothing to do.

### D3 — backup exclusion is a **toggle defaulting on**, not a default

*Keep songs in backup*, default **on** — which is exactly today's behaviour, so nothing changes for
anyone who does not touch it.

This is the whole shape of the decision. ADR 0148 traded bigger backups for song custody **on
purpose**, and says so in its own Consequences: *"a backup exclusion would defeat the entire ADR."*
That reasoning still stands. What has changed is only that the trade is now visible and the player
can take the other side of it knowingly. See §6.

**Takes are never excluded.** They are irreplaceable — `TakeTrimmer`'s own doc says *"a take has no
source to regenerate from"* — and `Song.recordings` nullifies rather than cascades (ADR 0151) for
exactly that reason. A song's audio came from a file the player still has and can point Red Moon at
again; a recording of them playing came from a moment that is gone.

The exclusion is set on the **directory**, so it covers copies imported after the switch was flipped.
Per-file would leave every subsequent import in the backup and make the setting quietly untrue.

The written value is **read back off the filesystem**, not assumed. A resource-value write can fail
quietly, and a switch that lies about where a player's audio is going is worse than one that never
moved.

### D4 — one byte formatter, in one place

`SongAudioSection` and `TakeDetailView` each called `ByteCountFormatter` with identical arguments.
Both now call `StorageUsage.formatted`, and `ByteCountFormatter` appears exactly once in the app.

### D5 — two sentences the app was saying that were not true

Both predate this ADR, both get worse the moment anyone turns D3's toggle off, and both are owed
regardless.

**`AudioUnavailableNotice` claimed one cause for two states.** It told every player with missing
audio that their song *"was added before Red Moon kept its own copy"*. That is true only for a
pre-0148 song still resolving through a bookmark. For every song imported since, the copy **existed
and is gone** — and telling that player their song is old sends them hunting the wrong problem. It
now takes `hadOwnCopy` and says which of the two happened. Both endings are identical, because the
repair and what survives it don't depend on the cause. `FAQEntry`'s *"My song stopped playing"*
answer carried the same stale claim and now names both routes.

**`SongAudioLabel.describe` could not express "the copy is gone".** With `audioFileName` set but the
file absent, `fileSize` returns `nil` and the label reported the format as though everything were
fine. `SongAudioResolver` has always fallen through to the bookmark when the copy is absent, so the
label was contradicting the thing that actually decides what plays. It now takes `copyExists` and
mirrors the resolver exactly. The old test that pinned the wrong behaviour is amended in place, with
a note saying so, and two tests are added for the state the old signature could not describe.

## §6 — amendment to ADR 0148, not a reversal

ADR 0148 weighed this exact trade and came down against a backup exclusion, in strong terms. That
judgement is **not** overturned, and this ADR should not be read as overturning it:

- **The default is unchanged.** Songs stay in the backup. A player who never opens this screen is in
  precisely the position 0148 put them in.
- **What is added is the choice**, and the information to make it: the ⓘ copy states the cost in the
  same breath as the benefit — a restored device needs each song pointed at its file again.
- **The reason 0148's argument still holds** is that the cost it named is real. That is also why the
  relink dead ends below are called out rather than waved past.

⚠ **Before the exclusion is ever made a *default*, the relink door has to be widened.** `LoopRunView`
and `SongPlayAlongView` are dead ends when audio is missing — a disabled button and a caption, with
no repair path; relink is reachable only from the waveform screen and `SongDetailsSheet`. With the
toggle defaulting on this stays rare, so it is not blocking, and it is in `docs/backlog.md`. It
becomes blocking the moment the default moves.

## Alternatives considered

**Sweep automatically, on launch or in the background.** Rejected for now. A sweep deletes files, and
a delete that a player did not ask for and cannot see is the wrong first version of this — especially
while the referenced-set rule is only as good as the fetch that feeds it. A manual *Reclaim space*
makes the operation observable before it is made automatic.

**Exclude takes from backup too, since they are the largest category.** Rejected, and this is the one
that would have looked most reasonable and been most damaging. They are the largest *and* the only
irreplaceable category.

**Show the figure on the Settings hub only.** Rejected: a single total with no breakdown tells a
player their app is big and gives them nothing to do about it.

**Fix the delete leak inline, in the view.** Rejected — D2. A missing side effect is exactly the kind
of defect that survives a green build, so it wanted a seam a test could neutralise.

**Also count the app bundle, caches and `tmp/`.** Rejected as noise. The categories here are the ones
a player recognises as *theirs*; the rest is the system's business and the system reports it.

## Consequences

- **`docs/architecture.md`'s retention description is now true.** It described a sweep that never
  ran; the line is corrected and the sweep exists.
- **Deleting songs now frees space, which changes what the library costs over time.** Nobody's
  existing leaked files disappear on upgrade — *Reclaim space* is how those come back, and on a
  long-used install it may free a great deal at once.
- **The storage total and the export size are the same measurement**, which is why both live on one
  screen (ADR 0181 D1).
- **`songsInBackup` is a new default that must be bound to `AppSettings.songsInBackupDefault`
  everywhere**, never re-typed as a literal — the `@AppStorage` literal is what SwiftUI uses for an
  unset key and it does not consult the accessor.
- **Two ⓘ strings joined `SettingsInfo`**, so `check-manual.py` requires them quoted byte-for-byte in
  `docs/manual/reference/settings.md`.
- **The relink dead ends are now a named blocker on a specific future change**, rather than a general
  untidiness. If the exclusion ever becomes a default, they are the work that has to come first.
