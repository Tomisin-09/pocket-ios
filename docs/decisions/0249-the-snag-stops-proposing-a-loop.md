# ADR 0249 — The snag stops proposing a loop; the first loop is pointed out

- **Status:** Accepted — decided with Tomisin, 2026-10-03. Built on `pocket-360-manual-reshoot`.
- **Date:** 2026-10-03
- **Amends:** ADR 0200 — D1's *"Snag ships with `tightenToSnags` or it does not ship"* is reversed.
  The *Tighten to …* offer, `SnagCluster` and the status line's flag are removed (D1). The tap, the
  marks and everything later ADRs built on them stand.
- **Amends:** ADR 0220 — D6 kept the session's hints to the starter track. A third hint, on the kept
  loop's row, now goes on every song (D3). The click and backing-track hints stay the starter
  track's. The rule that no hint shows during the ceremony applies to the new hint too.
- **Amends:** ADR 0149 — beat 1 rings the Loop button on every song, not only at the starter
  track's scripted stops (D2). There are still three beats.
- **Relates to:** 0244 (the loop row's hold tip, whose words the new hint reuses) · 0202 · 0203 ·
  0206 (the panel, the fade and the row count that keep a snag useful) · 0070
- **Schema:** none.

## Context

Tomisin, 2026-10-03, reviewing the reshoot: *"I think we should take the suggestion of snags to
narrow a loop out. The user doesn't need this suggestion, I believe it to be confusing. As part of
the user onboarding, in terms of creating the loop, we should highlight where the loop button is and
where they can edit it after they save."*

**The offer.** When a few snags clustered inside the armed loop, the status line under the speed bar
was replaced by *3 snags close together · Tighten to 1.4s*. ADR 0200 made it the reason for snags to
exist: without it, a mark would only be data. Since then, snags have gained a panel (0202), a count on
each loop's row (0206), *Snags on this piece* and a line each (0238), and a place in the export (0205).
A mark now pays its way without the offer. The offer itself appeared just after you marked a snag,
took over the line that holds Loop controls, Follow and Grid, and proposed a loop length in seconds
while you were playing.

**The first loop.** Beat 1's words say *Tap Loop*, but only the starter track ringed the button, and
only while its script held on a marker. On your own first song nothing pointed at Loop. After you saved,
nothing said that the row is held to change the loop, because the loop row's hold tip (0244) waits for
the next time the app is opened.

## Decision

| # | Decision |
|---|---|
| **D1** | **The tighten offer is removed.** `SnagTightenBar`, `SnagCluster` (the offer was its only consumer) and `offeringSnagTighten` are deleted. Marking a snag adds a tick and a haptic, and the status line no longer changes. Nothing that reads snags changes: the panel, the fade (0203), the row count, *Snags on this piece* and the Oracle payload (0204, parked). |
| **D2** | **Beat 1 rings Loop on every song.** On any song but the starter track, the Loop button carries the ring for as long as *Loop it* is the current beat. On the starter track, the script still decides (0220 D3). |
| **D3** | **Once the loop is kept, its row is pointed at.** A new hint, *Change it later*, says *Hold \<name\> to change its name, its range or how you practise it.* and rings the new row. It is offered on every song once the ceremony has closed. It is not offered when the backing-track hint is, because that hint already says *Hold Chords*, and one lesson about the hold is enough. The new hint goes when the loop's edit sheet has been opened, on its ✕, or if the loop is deleted. It is shown once. Holding the row also retires the loop row's hold tip, as it already did. |

### Rejected

- **Keeping the offer behind a setting.** A suggestion that confuses people isn't fixed by letting
  them turn it off.
- **A fourth beat, *Edit it*.** The 0149 amendment cut five beats to three on purpose. A hint is not
  a beat: it gates nothing, and nothing waits on it.
- **Ringing the row during the ceremony.** 0220 rules it out: the moment belongs to the player.
- **Showing the hold tip straight after the walkthrough.** 0244 D3 keeps tips out of the walkthrough's
  opening, for the same reason: one guide at a time.

## Consequences

- *A snag is a tap, and it moves the loop* is no longer half true: the tap stays, and moving the loop
  is the player's own decision, made with the panel and the row count.
- `SnagClusterTests` are deleted along with the code they tested. The hint rules are unit-tested
  (`StarterTrackHintsTests`). The edit hint is also driven on a song that isn't the starter track
  (`SongWalkthroughUITests`).
- No figure showed the offer, so no figure is lost. The walkthrough has no figure.
