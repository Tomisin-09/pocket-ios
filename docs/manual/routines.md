# Routines

A routine is an ordered run of things you already have — exercises, loops, whole songs — with rests
where you want them, played through in one sitting. You build it once and start it whenever, and the
app moves you through it so you are not deciding what comes next while you are meant to be playing.

Routines are part of **Red Moon Pro**.

Find them at **Practice ▸ Routines**.

## The library

<!-- shot: routines/library | role: screen
     | alt: The Routines library listing routines, each row with a play control, a summary of its blocks and rests, and — where the routine has been run — a second line giving how many times and when
     | state: seeded library, Practice ▸ Routines, several routines saved -->

A fresh install arrives with one, **Morning Routine** — two warm-ups, a rest, alternate picking, a
rest and a scale — so there is a whole session to look at before you build your own. It is an
ordinary routine, and you can take it apart.

Each row is one routine, newest first, under a count of what is in it — **4 blocks · 2 rests**.
Once you have run one, a second line underneath says how many times and when: **Practised 11 times ·
yesterday**. A routine you have not run yet simply doesn't carry that line, rather than saying so.

The row has two halves and they do different things: **▶** starts the session, and tapping the name
opens the routine to read or edit.

Hold a row for **Play**, **Edit**, **Duplicate**, **Favourite** and **Delete**. As everywhere else,
delete waits behind an undo toast.

The toolbar's options control holds the favourites filter and **Generate a quick session**, which is
covered in [Today's session](sessions.md). Routines have a fixed order, so there are no sort keys.

## Building one

**+** opens a new routine straight into its editor. Nothing lands in your library until you save, so
a routine you start and abandon leaves nothing behind.

<!-- shot: routines/editor | role: screen
     | alt: The routine editor in edit mode, with the Name field, numbered blocks, the estimated length and the Add and Insert rest rows
     | state: Practice ▸ Routines ▸ + , three blocks added -->

- **Name it** — the field at the top. Naming is what keeps it in your routines to run again.
- **Add exercise, loop or song** opens a picker grouped by kind. It stays open as you tap, so you
  can add several in one go, and a second tap on something takes it back out again.
- **Drag** a block by its handle to reorder.
- **Swipe** a block to remove it.
- **Tap** a block to set how many times it repeats — up to nine back-to-back runs before the routine
  moves on.

<!-- shot: routines/repeat-block | role: detail
     | alt: The repeat sheet for one block showing ×3 and the stepper that sets it
     | state: routine editor, a unit block tapped, repeat set to 3 -->

While the routine is still unsaved, an **Estimated length** reads under the block list and
re-reckons as you add and remove things, so you can see whether what you are building fits the time
you actually have. It goes once the routine is saved: the estimate is there to help you decide what
to keep, and a routine you already decided on does not need telling.

**Save** commits; **Cancel** discards everything since you tapped Edit.

### Rests

**Insert rest** does two different things. **Tap** it and a rest goes on the end, which is what you
want while you are still adding blocks in order. **Hold** it and the block list turns into the gaps
between your blocks, each one tappable — which is what you want once the order is settled and you
are breaking a finished routine up.

<!-- shot: routines/rest-insert | role: panel
     | alt: The block list in rest-insert mode, showing tappable gaps between the blocks under the header "Tap where a rest goes"
     | state: routine editor, Insert rest held -->

Tap a gap and a rest goes there. You can keep going down the list. **Done placing rests** returns to
the ordinary list.

The hold is the sort of thing you would never find on your own, so the row says **Hold to place**
once there is anything to place between.

You cannot put two rests next to each other. Try it and the app says so rather than silently
refusing: two rests in a row is one longer break, and the rest that is already there is the one to
lengthen. Rest length is a single setting, under **Settings ▸ Routines**.

## Playing one

**Start** at the bottom of a routine — or **▶** on its library row — takes over the whole screen.

<!-- shot: routines/player-block | role: screen
     | alt: A routine block in play, with the progress strip across the top marked Start and Finish and the block's own run screen beneath it
     | state: seeded library, a routine playing, second block of four -->

Across the top is the **progress strip**: one segment per block, marked **Start** and **Finish**, with
**‹** to step back and **›** to skip ahead. A multi-run block shows which repeat you are on. **✕**
leaves the session.

Underneath, the block is just its own run screen. An exercise block is the exercise run screen with
its settings and its staircase; a loop block is the loop; a song block plays the song through. What
drops out is authoring and review: you cannot edit a block's shape or change its meter here, and the
takes and journal bar is not on this screen either. A routine is where you play the thing. The
**quick note** button stays, because a routine block is exactly where a note tends to be owed.

Every block gets a **3 · 2 · 1** count-in, so an auto-started block never begins mid-stride.

### Between blocks

Finish a block and you land on its own completion screen: **Nice work**, an optional mastery rating,
an optional tagged note, and — for an exercise or a loop — the offer to move its command tempo up to
what you just played, or settle it down to something you own. **Up next** names what follows.
**Continue** moves on; the last block says **Finish** instead.

<!-- shot: routines/block-done | role: screen
     | alt: The between-blocks screen showing Nice work, the five mastery dots, a note field with its tag chips, and the Up next card
     | state: seeded library, a routine mid-session, a block just finished -->

A **rest** block is a countdown with the next block named under it, and it moves on by itself.

None of that is compulsory. An unchanged rating, an empty note and an untouched tempo offer all
commit nothing.

**See Help & FAQs: "What's the difference between mastery and command tempo?"**

### At the end

<!-- shot: routines/session-complete | role: screen
     | alt: The session-complete screen listing what you practised and asking how it went, with a Done button
     | state: seeded library, a routine played to the end -->

**Session complete** recaps what you worked through — what, never how well — and offers one note
about the sitting as a whole. That is the note for the things that belong to the hour rather than to
any one block: how the hands felt, what the room was like, what you would do differently. It files
under the session rather than under whichever drill happened to be last.

## How it moves — the settings

**Settings ▸ Routines** holds four:

- **Auto-start blocks** — whether each block begins on its own. The first block always waits for a
  deliberate start.
- **Advance automatically** — whether to skip the between-blocks screen entirely.
- **Rest length** — how long a rest lasts.
- **Loop song blocks** — whether a song block repeats as an open jam rather than ending.

## Reading a routine without playing it

Opening a routine gives you the read-only view. Tapping a block there pushes a preview of it — its
content, its tempo anchors, its staircase, and an audition — so you can check what is in a session
without starting it. **Edit** is what unlocks the changes, so a routine cannot be rearranged by
accident.

A saved routine tells you three things about itself. **Estimated length** is roughly how long
running it end to end would take. **Last practised** is when you last ran it, or **Not yet** if you
never have. Under those, how many times you have practised it.

A run counts as one practice however many blocks it holds — a routine of six exercises done in one
sitting is one, not six. Two runs inside the same half hour also count as one; a morning and an
evening count as two.

<!-- shot: routines/history | role: detail
     | alt: The length and history section of a saved routine, showing its estimated length, when it was last practised and how many times
     | state: seeded history, Practice ▸ Routines ▸ Morning Routine, read-only -->

It counts and it dates, and that is all it does. There is no target to hit, nothing that goes up or
down against last week, and nothing anywhere that remarks on a gap.

A routine also carries a **Description** — what the session is for, in as many words as you like.
It is the thing that will not fit in a name: who it is for, which week of the course it covers, why
the blocks are in the order they are. It sits behind the same **Edit** gate as the blocks, so you
read it at any time and change it with Edit, and **Save** keeps it. A routine you have not described
shows no Description at all until you add one. The starter **Morning Routine** arrives with one.

A saved routine also carries **Where you learned it**, and this is the one that matters most: a
course, a teacher's assignment, a book chapter belongs to a whole session rather than to any single
drill in it. It sits behind the same **Edit** gate as the blocks — you can read the links at any
time, and adding or removing one is a change you keep with **Save**. A block's preview shows the
drill's own links too, read-only. See [Where you learned it](references.md).

## Next

- [Let the app plan a session around a goal](sessions.md)
- [Build the drills that go in one](exercises.md)
- [Every hold, swipe and pinch](gestures.md)
