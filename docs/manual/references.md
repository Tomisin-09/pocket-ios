# Where you learned it

Red Moon does not teach you the material. Somebody else does — a video, a tab page, a course, a
teacher — and what this app is for is the stretch between watching that and being able to play it.

So exercises, songs, loops and routines each hold pointers back to wherever they came from. Either a
**link** you paste, or a **file** you keep here — a screenshot, a photo of the page, the PDF you
downloaded, an ASCII tab in a `.txt`, your own notes in a `.md`. Whichever it is, it sits with the
thing it explains, and every one you keep is also in **References**, in the Toolkit — including the
ones you saved before you'd made the thing they're for.

A song's section is also a good home for the artist's own pages: their Instagram, their YouTube
channel, wherever they post. The note under the section says so.

## Where the section is

**Where you learned it** appears on four things, always on the screen where you *choose* what to
practise:

| On | How you get there |
|---|---|
| An exercise | Its **ⓘ** detail sheet ▸ **References** — from the run screen's header, or **Details** on a library row |
| A song | **Details** ▸ **References**, from the library row menu or by holding the title in the player |
| A loop | **Edit loop** ▸ **References**, from holding a row in the Loops panel |
| A routine | Open it from the Routines library: its **References** section. Readable straight away; **Edit** is what lets you add or remove one, and **Save** keeps the change |

<!-- shot: references/section | role: panel
     | alt: The "Where you learned it" section on an exercise's References screen, listing two links with their sites underneath, one of them carrying a note under its site, then a picture row with a thumbnail, and the "Add a link" and "Add a file" buttons
     | state: seeded library, an exercise detail sheet ▸ References, with two links and one picture saved, one link carrying a note -->

A routine having one is the point of the whole feature. A course belongs to a *session*, not to a
single drill, and until now a routine built around week three of something had nowhere to say so.

## Adding a link

**Add a link** opens three fields.

<!-- shot: references/editor | role: screen
     | alt: The Add a link sheet showing the Link field with a Paste button beneath it, then the Name field, then the Note field
     | state: seeded library, an exercise detail sheet, Add a link tapped -->

- **Link** — the address, with **Paste** underneath it so getting a video address in is one tap.
  Red Moon does not look at your clipboard until you tap that button; nothing here reads it in the
  background, and you will never be asked to allow it.
- **Name** — optional. Leave it empty and the row shows the site instead.
- **Note** — optional, and the one worth writing. The name says what the source *is*, which you can
  usually work out from the address a week later. The note says what you took from it — *the
  down-up bit starts about four minutes in*, *only the chorus voicings are useful* — which you
  cannot. It shows on the row itself, under the site, so it is there while you are deciding what to
  practise.

It has to be a web address — something beginning `http://` or `https://`. Leave the scheme off and
Red Moon assumes `https://`, so pasting `youtube.com/...` works. Anything else is refused with a
message saying so, because a link that cannot be opened is worse than no link.

## Adding a file

**Add a file** offers **Choose a photo** and **Choose a file**. The first opens your photo library,
the second opens Files. There is no camera here: Red Moon never asks for camera access, and the shot
you want is usually already in your library.

Four kinds go in, and each is shown the way it is meant to be read:

| What you attach | How it opens |
|---|---|
| **A picture** — screenshot, photo of a page | Full width, at a size a phone can show |
| **A PDF** — the tab you downloaded | All of it, pageable and zoomable. Nothing is flattened or dropped |
| **A `.txt`** — ASCII tab | Fixed-width and **not** wrapped, scrolling sideways, because that is the only way the strings line up |
| **A `.md`** — your own written notes | Wrapped like prose, with **bold** and *italic* shown as formatting rather than asterisks |

That last split is worth knowing when you save something: **`.txt` is treated as a grid and `.md` as
prose.** Paste ASCII tab into a `.md` and it will wrap and stop lining up — save it as `.txt`
instead.

Whatever you attach is **copied into Red Moon**, so it stays even if you later delete the original.
Pictures are made smaller on the way in — a screenshot arrives at roughly the size it was, a
full-resolution photo is cut down to what a phone screen can show. Documents are never rewritten: a
PDF is stored exactly as it arrived. Anything over 25 MB is refused, and says so.

**Five files per exercise, song, loop or routine.** At five, **Add a file** stops offering and the
footer says so; remove one and it comes back. Links are not capped — they cost almost nothing to
keep, and a file does.

Once you have picked one, the same fields a link gets open over it, with the file itself at the top
so you can see what you are naming. A file has no address, so there are two rather than three:

- **Name** — optional, and it is what VoiceOver reads. Leave it empty and the row just says what
  kind of file it is.
- **Note** — optional. What it shows you, or which bit of it matters.

The button out of that is **Skip**, not Cancel, and it means what it says: the file was copied in the
moment you chose it, so skipping declines the describing and nothing else. If the right words turn up
later, hold the row and choose **Edit details**.

## Using them

**Hold a row** and you get **Edit link** — **Edit details**, on a file — and **Remove**, the same
menu every other list in the app puts behind a hold. Editing opens it back up with everything you
typed, so a name you'd change or a note you didn't write at the time is one gesture away. Swiping
the row right opens the editor too; swiping left removes.

**Remove takes it off this place, and nothing you kept is lost.** If nothing else uses it, it moves
to **Not filed** in References, with its note and its file. If the same link or file is on something
else too, only this use goes, and the note you wrote here with it; it stays in References through
the other place, and a file keeps the copy Red Moon holds. Deleting for good happens in
[References](#the-references-library), and only there.

Tap a link row and the source opens **in its own app** — YouTube in YouTube, a tab site in your
browser. Red Moon does not show it inside itself, and it never fetches anything from the address: no
titles, no previews, no thumbnails, no requests of any kind. What is stored is what you typed.

Tap a file row and it opens **inside Red Moon**, with your note beside it. A file is the one kind of
reference that does not take you out of the app — which is the whole reason it is worth keeping one
here rather than a link to it. See [Privacy](privacy.md).

On a routine, where the list is already in edit mode, you can also drag a reference into a
different order. A reference you add and then remove before tapping **Save** was never kept, so it
goes rather than moving to Not filed.

## The References library

**Toolkit ▸ References** lists every reference you keep, wherever it is filed. A search at the top
looks through the names, the sites, your notes and the names of the places they're used. Under it:

<!-- shot: references/library | role: screen
     | alt: The References library with a search field, a Not filed section holding two links and a PDF, each with its site or kind and when it was saved, then an Everything section whose rows each say On and the drill, song or routine they are filed on in its colour
     | state: seeded library, Toolkit ▸ References, three references not filed and four filed -->

- **Not filed** — the ones no exercise, song, loop or routine holds yet, newest first, with how many
  there are. A lesson you found before you'd made the drill for it waits here, and so does anything
  left behind when you deleted what it was on.
- **Everything** — the rest, newest first.

Each row is one source: its name, then the site or the kind of file and when you saved it, then
*On Triad climb · Morning routine* in each place's colour, then the first line of your note. **A link
used in two places is one row here**, though each place keeps its own note. So is a file you've
attached in two places with **Also attach to…**: it is one file. Two files you picked separately are
two rows, even if they hold the same thing.

**＋** offers **Add a link**, **Choose a photo** and **Choose a file**, the same fields and pickers
as on an exercise. What you add is kept for later, under Not filed. There is no five-file limit here:
that is per exercise, song, loop or routine.

### One source

Tap a row and it opens on its own:

<!-- shot: references/source | role: screen
     | alt: One reference's screen, with its name and site at the top, Open link, What you took from it with a note, Where it's used reading Not filed yet, a wide Start an exercise from this button with its caption, Attach to, and Delete
     | state: seeded library, Toolkit ▸ References, a link not filed tapped -->

- **Open link** — or **Open PDF**, **Open picture**, and so on for a file — as tapping it anywhere
  else does.
- **What you took from it** — your note, when the source isn't filed anywhere. If you kept the same
  link more than once, each note is here.
- **Where it's used** — each place, what it is, and the note that place keeps. A use that is kept for
  later shows as **Kept for later**, with its own note. A source nobody has filed yet says **Not
  filed yet**.
- **Start an exercise from this** — the big button while a source isn't filed. New exercise opens as
  it does in Practice, and the drill it makes already has this link or file attached, with your note.
  Once the source is filed somewhere, the button reads **Start another exercise from this**, and the
  new drill gets the link or file with a note of its own.
- **Attach to…** — files it on an exercise, routine, song or loop, with its note. Once it's filed, it
  reads **Also attach to…**: the same link or file goes in one more place, with a fresh note, and
  stays where it was. A file in two places is still one file, so it takes no more room.
- **Delete** — for good. It always asks first and names every place it will come off; once it is in
  two places the button itself says **Delete from both places…**. A file's copy goes with it.

### Choosing where it goes

**Attach to…** opens a list of places. **Recent** comes first: whatever you practised most lately.
**Show everything** lists every exercise, routine, song and loop, by kind, and the search at the top
looks through their names, and through the song a loop is in or a song's artist. Tap one and the
reference is there; the list closes. A place it's already on is ticked, and greyed out. So is one
that already holds five files, when what you're filing is a file.

Without the plan, the list holds songs and loops, and says *Exercises and routines come with the
plan*. **Start an exercise from this** shows what the plan adds, as New exercise does anywhere else.
If you've had the plan before, exercises and routines are still offered, with a lock: the reference
goes on, and the drill opens again with the plan.

**Edit** at the top changes the name and the link everywhere the source is used, since it is one
source, and the note of one place only. When it's used in more than one place, Edit asks which.

## Saving from another app

In YouTube, your browser, Photos, Files, or any app with a share button, tap **Share** and choose
**Red Moon**. If it isn't in the row of apps, scroll to the end of that row, tap **More**, and add it.

**Save to Red Moon** opens over the app you're in:

- **What you're saving**, at the top: the link, or the file. Its name is whatever the app sent with
  it, or the site, and you can change it. Under it, **What you took from it**, which is optional.
- **Where it goes.** **Keep for later** is chosen to start with, so **Save** on its own puts it under
  Not filed in References. Or choose a place: **Recent** lists what you practised most lately, **Show
  everything** lists every exercise, routine, song and loop, and the search looks through all of
  them. It offers what **Attach to…** offers: without the plan, songs and loops; if you've had the
  plan before, exercises and routines too, with a lock.
- **Save** keeps it and closes, and you're back in the app you were in. It's in Red Moon the next time
  you open it.

It takes one thing at a time: one link, one picture, one PDF, or one `.txt` or `.md` file, the same
files **Add a file** takes. Red Moon only appears in the share sheet for those, so it doesn't show up
for several photos at once or a video. Shared text works too, if there's a link in it: Red Moon keeps
the first web address it finds, and if there isn't one it says *There's no link in this to save.*

As everywhere else, nothing is fetched from the address: no title, no preview. Pictures are made
smaller when Red Moon next opens, as they are when you add one here, and a document over 25 MB is
refused before you can save it.

**Nothing you save is lost.** If the place you picked has gone by the time Red Moon opens (you
deleted that song in between), or it already holds five files, the reference goes under **Not
filed** instead, and you can attach it from there.

The list of places comes from Red Moon itself, the last time it was open. Until you've opened Red
Moon once after installing it, there's only **Keep for later**.

## Three things it deliberately does not do

**There are no links on a run screen.** Not on a loop run, not on an exercise run, not mid-session.
Tapping a lesson link while you are practising takes you out of the app, which is the one thing the
run screen is built to prevent. Read the source before you start or after you stop.

**There is no reading of your files.** Red Moon shows you a tab; it does not try to turn one into an
exercise. Nothing is scanned, no text is recognised, nothing is uploaded, and no file ever leaves the
device except in an export you ask for.

**Deleting the thing keeps its references.** Where you learned something outlives what you made from
it, so deleting an exercise, song, loop or routine leaves its links and files, with their notes, in
References under Not filed, as notes and takes are left. The undo toast says so: *Its 2 references
stay in References*. See [Journal and Practice log](journal-and-practice-log.md).

## Next

- [Write down what happened](journal-and-practice-log.md)
- [Put exercises in an order and play them](routines.md)
- [Where your data lives](privacy.md)
