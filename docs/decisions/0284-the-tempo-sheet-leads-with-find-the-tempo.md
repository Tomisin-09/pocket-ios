# ADR 0284 — The tempo sheet leads with Find the tempo

- **Status:** Accepted. Agreed with Tomisin on 2026-11-03 from the design canvas
  https://claude.ai/artifact/7rX1wRafACX5cHE98eaJ4U (its *Redesign* row): *"I'm happy with this
  design and direction."*
- **Date:** 2026-11-03 (`pocket-402-tempo-sheet-find-it-first`)
- **Amends:** ADR 0024, on the sheet's two modes: *Tap* and *Manual* stop being a segmented choice
  and become two of the ways to set a tempo, listed under the estimate (D5), and tapping moves to a
  page of its own (D6). Tap tempo, `preciseBPM`, the peak-snapped 1 and *Set the 1 on the waveform*
  stand. Also ADR 0283 D1, on the click's switch: it shows only once there's a tempo and a 1, and
  the strip says what's missing instead (D3); a tempo found, tapped or typed turns it on (D3). The
  preview, Cancel putting the song's click back, and Done keeping the switch stand, as do D2, D3
  and D4.
- **Relates to:** 0004 (rung 2 now leads the sheet; an estimate still never commits itself), 0166
  (the *Tap along* page keeps its disclosure), 0281 (*Tap through the song* and *The beats*), 0282
  (Half and Double)
- **Schema:** none.

## Context

ADR 0283 gave the tempo sheet a click and a way to count the bar, and on the device it worked. The
look didn't: *"It feels very reminiscent of the early days of the app before we had a theme."* A
restyle was drawn first, on the canvas. Then Tomisin asked for the layout itself to be reset:

> Right now, there seems to be an emphasis on the tapping, making it seem like the default method.
> And I think estimate from audio should be the first option and the tempo settings should flow
> from this point. The tap/manual pills don't feel like they capture the options.

The order was build history. ADR 0024 built rung 3 of ADR 0004's chain, tap or type, first, as two
modes of the sheet. The estimate, rung 2, came later as a button lower down. B1 and B3a then made
it exact enough on a steady song that it's now the best first move, and it was still the third
thing on the sheet.

Two smaller things came up on the way. The click's switch sat greyed out until there was a tempo
and a 1, with nothing saying why. Tomisin asked whether a tap that did nothing was the switch
waiting for a tempo (on that occasion it wasn't). And the sheet reported the 1 three ways: a
*Downbeat* row, a *Not set* warning, and the section's footer.

## Decisions

**D1. The sheet opens on Find the tempo.** On a song with no tempo, the first thing under the strip
is one wide teal button, **`Find the tempo`**, with what it does: *Listens to the song for its beat
and the 1*. It's ADR 0004's rung 2 under a name that says what it's for. While it runs, the button
reads *Listening to the song…*. When it hears no steady beat it says so and points to the other
ways. *Estimate from audio* is retired as a name.

**D2. One reading at the top, saying where it came from.** Once there's a tempo, a card replaces
the button. It shows the tempo, large, and above it where the tempo came from: *Estimated from the
song*, *From your taps*, *Typed in*, or *This song's tempo* for one the song already had. Under it
is one line for the bar and its 1 (*4 beats a bar · the 1 at 0:02*), then **Half** and **Double**,
each with the tempo it gives.

- **Half and Double work on any tempo.** On an estimate they count the same reading again, so it
  stays exact and the 1 is placed again (ADR 0282 D5). On any other tempo they multiply it and
  leave the 1 where it is. A tapped tempo can be double time as easily as an estimate.
- **A song with a beat map** opens on *The beats* (ADR 0281) in place of the card. A tempo chosen
  on such a song gets a card that says Done replaces the beats.
- **An estimate is still only a proposal** (ADR 0004). Nothing reaches the song until Done.

**D3. A tempo turns the click on, and the strip says why it can't.** Finding, tapping or typing a
tempo turns the sheet's click on whenever there's a 1 to count from, so pressing Play is the whole
check. ADR 0283 D1 still holds: the click plays values not yet saved, Cancel puts the song's click
back, and Done keeps the switch as the sheet left it. So Done after finding a tempo leaves the
song's click on, which is what the player just heard. The **Click** chip shows only once there's
something to click. Until then the strip says what's missing: *The click comes with a tempo*, or
*Mark the 1 to hear the click*. A greyed-out switch is gone.

**D4. The 1 appears once there's a tempo.** The section keeps ADR 0283's two questions and its two
ways to place the 1. *Beats in a bar* becomes three pills, and the chosen beat of *Which beat is
the 1?* fills green, the player's colour for what's chosen. The *Downbeat* row, its clear button
and the *Not set* warning go: the card's summary line says where the 1 is, or *no 1 yet*. The
footer keeps the remedy for drift (ADR 0283 D4).

**D5. The other ways, each saying when it's the one.** Under the 1, one card lists the rest, headed
*Or set it yourself* before there's a tempo and *Other ways to set it* after:

- **`Tap along`**: *Tap with the song as it plays*. Opens a page (D6).
- **`Type a tempo`**: *When you already know it*. Opens a field in place, with **`Use`**.
- **`Tap through the song`**: *For a song that speeds up or slows down*. Opens ADR 0281's screen.
- **`Find the tempo`** again, when the tempo shown didn't come from it.

The *Tap* and *Manual* segments are gone. They were never modes, only alternatives, and a segment
can't say when you'd want it.

**D6. Tap along is a page of its own.** A large reading, the ADR 0166 line (*the reading follows
your last few taps*), a pad that fills the page, **`Reset`**, and **`Use 89 BPM`**, which sets the
sheet's tempo and comes back. Taps change nothing until Use. While the song is paused the pad asks
for Play, as *Tap through the song*'s does. **The click is quiet** on this page and on *Tap through
the song*: it would play the tempo being replaced, and a click at your own tapped tempo pulls the
next tap towards it.

**D7. The sheet wears the player's look.** The app's background, cards in `surfaceStandard`,
Futura, teal on what you press and green on what's chosen. This is the speed bar's split, whose
presets fill green and whose metronome button is teal.

**Not decided here:** estimating the tempo at import, so a song arrives with the card already
showing. Tomisin wants to come back to it (2026-11-03). It's in the backlog with what it would cost.

## Alternatives considered

- **Restyle the sheet and keep its order** (the canvas's first two rows). It fixes the look, and
  tapping still reads as the default.
- **Three segments: Find, Tap, Type.** Segments put the three on an equal footing and hide that one
  is where to start. Each would also have to show the result.
- **Find the tempo as the sheet opens.** It spends a full decode on every open, including on songs
  whose tempo is already right.
- **The click follows the taps live**, as Tap mode's did (ADR 0283). It drags the player's taps
  towards the click.
- **Keep the switch, greyed out, with a caption.** The caption is the useful part, and a control
  that can't be used shouldn't take the place of one that can.

## Consequences

- The manual's tempo editor section is rewritten, and its figure is stale (reshoot notes).
- `TempoMath.manualBPM` goes. `TempoDraft` holds the sheet's tempo and its source, with
  Half, Double and the typed-tempo rule, unit-tested. Typing the whole number of the tempo shown
  keeps it exact, so ADR 0282's rounding can't come back that way. The estimate no longer passes
  through a text field at all.
- `TempoMath`'s "the Manual field" comments now describe *Type a tempo*.
- `BPMSheet` keeps its inputs and `bpmSheet(_:)` is unchanged, so the model, the commit and the
  click preview are untouched.
