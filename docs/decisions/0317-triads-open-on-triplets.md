# ADR 0317 — A new Triads run opens on triplets

- **Status:** Accepted on 2026-11-24, for 1.6.1, and built on `pocket-476-triads-triplets`. Tomisin
  asked for triplets as the default, and maybe 3/4 too, then agreed to triplets on their own (D3).
- **Date:** 2026-11-24
- **Amends:** ADR 0313 — **D10**: a new Triads run opens on triplets, not eighths (D1 here). The rest of
  D10 stands: C major, G‑B‑e, the key's seven, *Stay in frets* 3 to 7, Broken.
- **Relates to:** 0313 D7 (Together takes Broken's time, and a progression's chord holds for its bars)
  · 0313 D9 (*Practice as triads* opens on D10's run) · 0121 (a rhythm change can keep the note speed)
  · 0070 (nothing here grades playing)
- **Schema:** none. A run already stores its rhythm, so nothing saved changes.

## Context

ADR 0313 D10 opened a new Triads run on eighths. Played Broken, a triad is three notes, and eighths
don't divide by three:

- **A progression's chord** holds for its bars and repeats its three notes to fill them (D7). A 4/4 bar
  of eighths is 8 notes, so each bar played R 3 5 R 3 5 R 3 and the next chord cut the last triad off.
- **One chord or the key's seven** plays each chord's three notes once. In eighths that is a beat and
  a half per chord, so every other chord started off the beat.

D7 had already noted that triplets fill a beat exactly. D10 didn't follow it.

## Decision

### D1 — A new run opens on triplets

`TriadRun`'s default rhythm is triplets, so every door that makes a new run opens on them: the New
exercise form's Triads, the shape sheet's first switch from the box to Triads, and *Practice as
triads* (0313 D9).

In triplets each chord of the key's seven is one beat, so all eight, back to the tonic, are exactly two
bars of 4/4 and the run loops on the bar line. A progression's chord fills a 4/4 bar with four whole
triads, each starting on a beat.

### D2 — A saved run keeps its rhythm

A run already stores its rhythm and every build writes it, so an exercise saved in eighths still plays
eighths. Nothing is backfilled. The Rhythm row under Advanced still offers all four rhythms.

### D3 — The meter stays the exercise's

*Decided by Tomisin: triplets on their own.* Choosing Triads doesn't set 3/4:

- Triplets already make every triad land on a beat in 4/4.
- The meter belongs to the exercise, not the run. It is set in the form's Tempo and meter section, and
  it can arrive carried from the metronome or from a song's tempo. Choosing Triads would overwrite it.
- *Practice as triads* copies a progression whose bars match a song. In 3/4 every bar is a beat
  shorter, so the copy would no longer line up with the song.
- The key's seven fills two 4/4 bars in triplets. Its eight beats don't make whole bars of 3/4.

3/4 is one tap away on the same form.

## Alternatives considered

- **3/4 as well as triplets.** Rejected in D3.
- **Eighths in 3/4.** A 3/4 bar of eighths is 6 notes, two whole triads, so this fixes a progression's
  bar too. It carries every cost D3 lists and doesn't fix the key's seven, whose chords would still
  each last a beat and a half.
- **Triplets only while Broken.** Switching *Play as* would move the rhythm with it. Rejected: 0313 D7
  says switching *Play as* never changes how long the run is, and the switch would overwrite a rhythm
  the player chose. A new run opens Broken, so the default already does what was asked.

## Consequences

- At the same BPM, triplets play 1.5 times as many notes as eighths, so a new Triads exercise is
  faster at the form's usual tempo. The form's tempo is unchanged.
- `TriadRunTests` holds the new default, the key's seven filling two bars, a progression's bar holding
  four whole triads, and a run saved in eighths staying in eighths. `PracticeAsTriadsTests` holds the
  seed's triplets.
