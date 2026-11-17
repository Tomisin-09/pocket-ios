# Your data

Red Moon has no accounts, no ads and no trackers. What you play, what you record and what you write
stays on your phone.

This page is a summary. The commitments themselves live in the
[privacy policy](../privacy-policy.md), which is the document that binds and the one to read if you
need the full statement — it is linked in the app at **Settings ▸ Help & About ▸ Privacy Policy**.
Where this page and the policy differ, the policy is right.

**See Help & FAQs: "Where is my practice data stored?"**

## Where your practice lives

On this device, in the app. Your songs, loops, markers, exercises, routines, goals, notes and takes
are stored locally — there is nothing to sign into and nothing being kept for you elsewhere.

Two consequences worth knowing before you rely on them:

- **There is no sync.** Install Red Moon on a second phone and it starts empty. Your practice does not
  follow your Apple Account.
- **A device backup includes the app's data**, and audio you keep in iCloud Drive stays in iCloud
  Drive exactly as it was before you imported it.

Imported audio is **copied into the app**, so a song keeps playing whether or not the file it came
from is still where you found it. Deleting a song from Red Moon removes Red Moon's copy and leaves
your original alone.

### Taking a copy out

**Settings ▸ Your data ▸ Export** writes everything you have built into a single zip and hands it to
the share sheet, so you can keep it wherever you keep things. Inside are `practice.json` — songs,
loops, markers, exercises, chords, routines, goals, journal and practice history — and a `takes`
folder holding the audio of your recordings, which you can leave out if you only want the writing.

Nothing is uploaded. The file is written on your device and handed to the share sheet; where it goes
after that is your choice alone, and Red Moon has no idea. **Settings ▸ Your data ▸ Restore reads one
back in**, so an archive is a real backup rather than only a copy to keep.

Two things worth knowing before you send one anywhere. It contains your notes and your recordings in
full. And a take recorded next to a playing song may have picked that song up through the
[microphone](#the-microphone).

See [Settings ▸ Your data](reference/settings.md#your-data).

A single take, a song's audio, a song sent with its loops, a routine sent with its songs, or a tab can
leave the same way, each from its own screen: the file is made on your device and handed to the share
sheet, and nothing is uploaded. A song or a routine you **send** carries your artist name, if you've
set one, so the person who opens it knows who it's from. **Send this song** and **Send this routine**
show the name before anything is sent.

## The microphone

The app asks for one system permission, and uses it in exactly two places:

- **The [tuner](toolkit.md)**, which listens to a played string while you are on that screen.
- **A [take](journal-and-practice-log.md)** you start yourself, which is saved to the device as a file.

iOS shows its own recording indicator whenever the mic is live, and Red Moon releases it as soon as
you leave the screen or send the app to the background. Nothing the microphone hears is uploaded —
there is no upload path in the app for it to take.

Red Moon does **not** ask for access to your music library, and cannot play Apple Music or Spotify
streaming audio at all.

**See Help & FAQs: "Does Red Moon listen to or send my playing?"**

## How we know the app is used

Red Moon itself does not count what you do in it. There is no analytics in the app, nothing to turn
off, and nothing sent about how you use it.

What we do see comes from Apple. If you turned on **Share With App Developers** in your iPhone's
Settings ▸ Privacy & Security ▸ Analytics & Improvements, Apple passes developers anonymous totals for
the apps you use: how many devices opened an app on a given day, how often, and how often it crashed.
That switch is Apple's and covers every app on the phone. Red Moon has no say in it.

**Red Moon does not use the advertising identifier or the App Tracking Transparency prompt, and it
never will.** That is a permanent product boundary, not a setting.

## What is never sent

Not your audio. Not your recordings. Not your journal notes, your song names, your file names, your
artist name, or anything else you have typed or chosen. There is no profile of you, here or anywhere, because there is no identifier to hang one on. The only way any of
it leaves is in a file you send yourself, from the share sheet, as
[Taking a copy out](#taking-a-copy-out) describes.

## Crashes and freezes

iOS keeps its own record of any time Red Moon crashed or froze, and hands it to the app about once a
day. That record stays on your device, and it is never sent on its own.

`Settings ▸ Help & About ▸ Diagnostics` shows you exactly what iOS reported — the last five, with the
date, what iOS called each one, and the build and iOS version it happened on. `Clear` forgets them.

One switch on that screen, **off unless you turn it on**, adds a single line to your next support
message: how many there were, since when, and what iOS called the most recent one. No call stacks, no
logs, no file paths. As everywhere else, the contact form shows you that line in full before you
send.

## What you save under "Where you learned it"

The addresses you put in **Where you learned it** are stored on the device like everything else, and
Red Moon never contacts them: it fetches no page titles, no previews and no thumbnails, so saving a
link tells the site nothing. See [Where you learned it](references.md).

Opening one is different, and worth being clear about. Tapping a link hands the address to whichever
app handles it — your browser, YouTube — and from that moment you are that app's visitor under that
app's own policy, exactly as if you had typed the address there yourself. Red Moon is not in the
middle of it and cannot be: it has no web view of its own.

**Files go no further than links do.** A picture, PDF, text or Markdown file you attach is copied
into Red Moon's own storage and stays there. It is never uploaded, never scanned, and never read for
anything — no text recognition, no analysis of any kind. Red Moon does not get access to your photo
library or your files either: the pickers that open belong to the system, hand over the one file you
chose, and show Red Moon nothing else. There is no camera in the app, so it never asks for one.

## If that ever changes

The policy is explicit about it: if a future version adds something that processes data differently —
an optional feature that sends practice history to a server, say — the policy is updated **before**
that feature ships, the processing is disclosed, and it is opt-in.

## Next

- [The full privacy policy](../privacy-policy.md)
- [What Settings holds](reference/settings.md)
- [Where your notes and takes live](journal-and-practice-log.md)
