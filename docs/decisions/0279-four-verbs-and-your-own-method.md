# ADR 0279 — Four verbs, and your own method

- **Status:** Accepted. Tomisin named the pillars on 2026-10-26 and approved the listing built on them
  on 2026-10-27. Built on `pocket-391-listing-copy-1-4`.
- **Date:** 2026-10-27
- **Amends:** ADR 0276 — **D1**: the line leads with the player, not the songs. The listing's opening
  is now *"Red Moon is a practice studio for players who learn from everywhere."* *Practice studio*,
  *adds up* and *nobody is marking you* all stand, as do D2 to D4.
- **Relates to:** 0167 (where you learned it: the references this ADR's roof rests on) · 0070 (no
  grading, which is why the fourth verb is *keep it*, not *score it*) · 0132 (the click that thins) ·
  0278 (Help's first question)
- **Schema:** none.

## Context

0276 gave Red Moon a line, but the app still read as forty features. On 2026-10-26 Tomisin named what
they are: a slow-downer, a click that drives drills across scales, rhythm and the fretboard, a
structure to practise through, a record you comment on yourself, and a way to bring your own
material. *"Instead of providing a method we give you the power and tools to make your own."*

They also named the player, from being that player: self-taught from the internet, influenced by too
many teachers to pick one. They had just used the app to get two songs ready for an open mic, with a
routine built around the parts they found hard (*Symposium Oct Practice*).

## Decisions

### D1 — The line leads with the player

> **Red Moon is a practice studio for players who learn from everywhere.**
>
> It doesn't hand you another method. It gives you the tools to build your own from what you already
> learn from, and it keeps everything you do, so your practice adds up instead of starting over.
> Nobody is marking you.

0276 said *for songs you own*. That describes the input; this describes the person, and names what
sets the app apart from method apps such as Yousician and Fender Play, which hand you a course.

### D2 — Four verbs, under one roof

| Verb | What it covers |
|---|---|
| **Work it out** | The slow-downer: loop, slow down with the pitch held, count and name the notes, tab |
| **Build it up** | The click under every drill: tempo ramps, click withdrawal, the fretboard drills |
| **Run it** | Routines and Today's session: the hard parts, lined up and played through |
| **Keep it** | Takes, the journal and the practice log: the player's own commentary, never a score |

**The roof is *your sources, your method*:** references on anything, Save to Red Moon, sending a
routine. It is why the verbs are tools and not a syllabus, so it frames them rather than being a
fifth step.

- The verbs extend the beats `docs/messaging.md` already used (*work it out, build it up, keep it*)
  with the one they were missing, *run it*.
- **The first-song guide keeps its own three beats** (*Loop it, Slow it down, Keep it*). It is the
  way in, the first verb taught in detail, and it works.
- Home's spaces already map onto the verbs (Library, Metronome and drills, Practice, Journal, Toolkit),
  so the frame describes the app rather than being laid over it.

### D3 — Where it shows, and where it doesn't

- **The App Store description** is organised by the four verbs, with the roof last.
- **The subtitle and keywords stay with the slow-downer.** It's what people search for
  (`positioning.md`'s acquisition rule).
- **Screenshots** tell one song's story through the verbs. **The header and search-result assets**
  (iOS 27) follow the screenshots. Neither is decided in detail here.
- **The listing is pasted through `scripts/export-listing.py`**, which turns each field into the
  plain text App Store Connect takes, checks its limit, and checks the description for the EULA link.

### D4 — The player has something coming up

The person is described by a situation, not a demographic: a self-taught player with something on
the way, such as an open mic, a jam, a lesson or a recording. In Jobs-to-be-Done terms that date is
the trigger. *Tutorial hell* (the self-taught programmer's name for watching lessons without getting
better) is candidate language for the site and social posts. It isn't for the App Store.

## Consequences

- **Done here:** the description, `docs/messaging.md` §1, and the export script.
- **Owed:**
  - Help's two framing answers, *"What is Red Moon?"* and *"Where do I start?"*, still describe the app
    as two halves. They become the verbs in 1.4.1, because app text needs a new build and 1.4 (8) is
    ready to archive.
  - The screenshots and the iOS 27 assets.
  - The site.
  - Later, with its own ADR: the first-run intake already asks what the player is working toward, so a
    date is the natural next question.

## Alternatives rejected

- **Five pillars.** *Your own method* isn't something the player does; it's why the four things are
  built as tools. Counting it as a step would hide that.
- **Leading the listing with the five pillars, subtitle and keywords included.** The slow-downer is
  what people search for, and the listing's acquisition layer keeps doing that job.
