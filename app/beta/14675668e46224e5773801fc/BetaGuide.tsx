'use client'

import { useEffect, useState } from 'react'

/* The site's established form endpoint — same one the contact form on `/` posts to. Using it keeps
   this branch at zero new dependencies and zero API routes. Acceptances and confusion reports both
   arrive as email, distinguished by their `_subject`. */
const FORMSPREE = 'https://formspree.io/f/mbdweqar'

const ACCEPT_KEY = 'rm-beta-accept-v1'
const CHECK_KEY = 'rm-beta-checklist-v1'

const STARTER_TRACK = '/redmoon/beta/starter-track.m4a'

type Step = { id: string; label: string }

/* A callout drawn *around* a control rather than on top of it.
 *
 * The figure renders a 640px-wide screenshot at ~300px, so anything sized in CSS pixels is roughly
 * twice as big against the image — a 26px dot covers 55px of screenshot, which is the size of the
 * control it is supposed to be pointing at. Hence a ring: the target stays visible inside it, and
 * the number hangs off the corner.
 *
 * All six values are percentages of the image box, so the callout tracks the shot at any width.
 * `x`/`y` are the centre of the target; `w`/`h` its size; `round` for circular controls.
 */
type Pin = { n: string; x: number; y: number; w: number; h: number; round?: boolean; title: string }

/* Screenshots already live in `public/redmoon/` for the marketing pages — referenced rather than
   copied, so there is one file to replace when the UI moves on. */
function Shot({
  src,
  alt,
  pins = [],
  caption,
}: {
  src: string
  alt: string
  pins?: Pin[]
  caption: string
}) {
  return (
    <figure className="rm-beta-figure">
      <div className="rm-beta-shot">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={src} alt={alt} />
        {pins.map((pin) => (
          <span
            key={pin.n}
            className={pin.round ? 'rm-beta-ring rm-beta-ring-round' : 'rm-beta-ring'}
            style={{
              left: `${pin.x}%`,
              top: `${pin.y}%`,
              width: `${pin.w}%`,
              height: `${pin.h}%`,
            }}
            title={pin.title}
            aria-hidden="true"
          >
            <b>{pin.n}</b>
          </span>
        ))}
      </div>
      <figcaption>{caption}</figcaption>
    </figure>
  )
}

/* Section order, in one place, so the contents list and the per-section footers cannot disagree
   about what comes next. Ids are frozen for the same reason the checklist ids are: a tester who
   writes "I'm stuck at #make-the-loop" is orphaned by a rename. */
const SECTIONS: { id: string; title: string }[] = [
  { id: 'before-you-start', title: 'Before you start' },
  { id: 'what-this-is', title: 'What this is, and what it isn’t' },
  { id: 'first-session', title: 'Your first session' },
  { id: 'holds', title: 'Hold anything for a moment' },
  { id: 'build-a-drill', title: 'Build your own drill' },
  { id: 'planner', title: 'Let it plan the session' },
  { id: 'the-rest', title: 'The rest of it' },
  { id: 'feedback', title: 'Telling me what happened' },
  { id: 'checklist', title: 'Where you’re up to' },
]

/* The seven features inside "The rest of it" — listed in the contents because that is what someone
   hunting one of them actually searches for. */
const FEATURES: { id: string; label: string }[] = [
  { id: 'routines', label: 'Routines' },
  { id: 'journal', label: 'Journal' },
  { id: 'progress', label: 'Progress' },
  { id: 'toolkit', label: 'Toolkit' },
  { id: 'metronome', label: 'Metronome' },
  { id: 'settings', label: 'Settings' },
  { id: 'help-faqs', label: 'Help & FAQs' },
]

/* The checklist. Ids are stable — they travel with every confusion report, so renaming one orphans
   the reports already collected against it. */
const STEPS: Step[] = [
  { id: 'install', label: 'Installed from TestFlight' },
  { id: 'import', label: 'Got a song in' },
  { id: 'listen', label: 'Listened the whole way through, and wrote a note' },
  { id: 'mark', label: 'Marked the bit I can’t play' },
  { id: 'loop', label: 'Made a loop and slowed it down' },
  { id: 'drill-scale', label: 'Built a Scale exercise' },
  { id: 'drill-chord', label: 'Built a Chord progression' },
  { id: 'plan', label: 'Let it plan a session' },
]

export default function BetaGuide() {
  const [accepted, setAccepted] = useState(false)
  /* Undefined until the effect runs, so the first paint on the server and the first paint on the
     client agree — reading localStorage during render would hydrate-mismatch. */
  const [ready, setReady] = useState(false)
  const [done, setDone] = useState<Record<string, boolean>>({})

  useEffect(() => {
    try {
      setAccepted(localStorage.getItem(ACCEPT_KEY) === 'yes')
      setDone(JSON.parse(localStorage.getItem(CHECK_KEY) || '{}'))
    } catch {
      /* Private browsing, or storage disabled. The guide still works; it just forgets. */
    }
    setReady(true)
  }, [])

  function toggle(id: string) {
    setDone((prev) => {
      const next = { ...prev, [id]: !prev[id] }
      try {
        localStorage.setItem(CHECK_KEY, JSON.stringify(next))
      } catch {
        /* ignore */
      }
      return next
    })
  }

  if (!ready) return null
  if (!accepted) return <AcceptGate onAccept={() => setAccepted(true)} />

  const completed = STEPS.filter((s) => done[s.id]).length

  return (
    <>
      <nav className="rm-beta-toc" id="contents" aria-label="Contents">
        <h2>What&rsquo;s in here</h2>
        <ol>
          {SECTIONS.map((section) => (
            <li key={section.id}>
              <a href={`#${section.id}`}>{section.title}</a>
              {/* The seven features live as h3s inside one section — a tester hunting the tuner
                  looks for "Toolkit", not for the section that happens to contain it. */}
              {section.id === 'the-rest' && (
                <ul className="rm-beta-toc-sub">
                  {FEATURES.map((feature) => (
                    <li key={feature.id}><a href={`#${feature.id}`}>{feature.label}</a></li>
                  ))}
                </ul>
              )}
            </li>
          ))}
        </ol>
      </nav>

      <section className="privacy-section" id="before-you-start">
        <h2>Before you start</h2>
        <p>You&rsquo;ll need:</p>
        <ul>
          <li>
            An iPhone on <strong>iOS 17</strong>{' '}or newer. An iPhone specifically &mdash; it will
            install on an iPad, but in phone-compatibility mode, and I&rsquo;ve never tested it
            there.
          </li>
          <li>The <strong>TestFlight</strong>{' '}app, and the invite link I sent you.</li>
          <li>Headphones, or somewhere you can hear the click over your playing.</li>
          <li><strong>One piece of music you own as a file.</strong>{' '}See below.</li>
        </ul>

        <h3>About that file</h3>
        <p>
          Red Moon slows music down, loops a bar of it and puts a click over it. To do that it needs
          the actual audio &mdash; which means a file on your phone or in iCloud Drive. Spotify and
          Apple Music won&rsquo;t work: that audio is encrypted, and no app can reach inside it.
          That&rsquo;s not a limitation we chose, it&rsquo;s the wall every app hits.
        </p>
        <p>So you need one of:</p>
        <ul>
          <li>A track you <strong>bought</strong>{' '}as a download.</li>
          <li>A <strong>backing track</strong>{' '}you own.</li>
          <li>
            <strong>Something you recorded yourself.</strong>{' '}Thirty seconds of you playing into
            Voice Memos is genuinely enough to test with.
          </li>
          <li>
            <strong>The starter track</strong>{' '}&mdash;{' '}
            <a href={STARTER_TRACK} download="Binta - Jack Trader.m4a">
              download &ldquo;Binta&rdquo;
            </a>
            . I wrote and recorded it, so you&rsquo;re clear to use it. It&rsquo;s about a minute
            and a half &mdash; short on purpose, and plenty to loop. Grab it if you have nothing
            else to hand.
          </li>
        </ul>
        <p>
          Get one of your own in there too, if you can. How the import feels on <em>your</em>{' '}
          music is a big part of what I&rsquo;m trying to learn.
        </p>
        <SectionNav id="before-you-start" />
      </section>

      <section className="privacy-section" id="what-this-is">
        <h2>What this is, and what it isn&rsquo;t</h2>
        <p>
          Red Moon is a practice room, not a music player. You bring a song you&rsquo;re trying to
          learn, mark the bar that keeps beating you, slow it right down, and loop it against a click
          until it stops beating you. Everything else exists to support that.
        </p>
        <p>
          <strong>It will never score your playing.</strong>{' '}Nothing listens and grades you, and
          nothing ever will. When you see a rating, you put it there. Your recordings stay on your
          phone.
        </p>
        <SectionNav id="what-this-is" />
      </section>

      <section className="privacy-section" id="first-session">
        <h2>Your first session</h2>
        <p>Three steps, in order. They build on each other.</p>

        <h3>1 &mdash; Get the song in, and listen to it</h3>
        <Shot
          src="/redmoon/shot-home.png"
          alt="The Red Moon home screen, with a green plus button in the top right corner."
          pins={[{ n: '1', x: 89.2, y: 4.3, w: 10.3, h: 5.2, round: true, title: 'Add a song' }]}
          caption="① is the button. Everything else on this screen can wait."
        />
        <p>
          Tap <strong>+</strong>{' '}on the home screen and pick your file. Then play the whole thing
          through at full speed, without touching anything.
        </p>
        <p>
          This feels like a wasted step. It isn&rsquo;t &mdash; you&rsquo;re deciding what you
          actually want out of this song before you start dismantling it. Then write it down: open
          the <strong>Journal</strong>, tap <strong>&#xFF0B;</strong>, and note what you&rsquo;re
          after. One line is fine.{' '}
          <em>&ldquo;The turnaround at 1:20 &mdash; I keep rushing it.&rdquo;</em>
        </p>
        <StepControls step={STEPS[2]} done={done} toggle={toggle} />

        <h3>2 &mdash; Mark the bit you can&rsquo;t play</h3>
        <p>
          Drop the speed to around <strong>0.85&times;</strong>{' '}and play through again. The pitch
          doesn&rsquo;t change when you slow it down &mdash; it&rsquo;s still in the same key.
        </p>
        <p>
          When you reach something you want to come back to, drop a <strong>marker</strong>{' '}on it.
          Do that a few times. You&rsquo;re building signposts, not being precise.
        </p>
        <StepControls step={STEPS[3]} done={done} toggle={toggle} />

        <h3>3 &mdash; Make the loop</h3>
        <p>This is the one. Here is the whole screen, with the three things you need on it:</p>
        <Shot
          src="/redmoon/shot-loops.png"
          alt="The practice screen: a speed row at the top, the waveform in the middle, the transport bar below it, and a list of saved loops at the bottom."
          pins={[
            { n: '1', x: 87.5, y: 52.3, w: 10.9, h: 5.5, round: true, title: 'The Loop control' },
            { n: '2', x: 29.8, y: 17.2, w: 15.0, h: 3.8, title: 'Speed' },
            { n: '3', x: 12.3, y: 62.5, w: 13.4, h: 3.4, title: 'Saved loops' },
          ]}
          caption="① the Loop control — the green ↻ circle. Tap to start the loop, tap again to close it. (The magenta ▼ next to it drops a marker, which is a different job. You can swap which side each sits on in Settings.) · ② speed, with 0.50× one tap away · ③ where a loop lands once you keep it"
        />
        <p>
          Play up to the start of the passage that&rsquo;s giving you trouble and{' '}
          <strong>tap Loop</strong>. That drops your start point. Play through to the end of the
          passage and <strong>tap Loop again</strong>{' '}&mdash; it closes the loop and starts
          repeating it immediately.
        </p>
        <p>
          Now take the speed down to about <strong>50%</strong>{' '}and let it go round. Play along.
          Stay there longer than feels necessary. When it&rsquo;s comfortable, nudge the speed up and
          stay there. Then again.
        </p>
        <p>
          To keep the loop, tap <strong>Save as loop</strong>. If you don&rsquo;t want it, tap{' '}
          <strong>&#10005;</strong>{' '}and the song plays on through.
        </p>
        <div className="rm-beta-callout">
          <p><strong>That&rsquo;s it. That&rsquo;s the app.</strong></p>
          <p>
            Everything else &mdash; the drills, the routines, the planner, the tuner &mdash; is
            scaffolding around that one move. If you only ever do this, you&rsquo;re using it right.
          </p>
        </div>
        <StepControls step={STEPS[4]} done={done} toggle={toggle} />
        <SectionNav id="first-session" />
      </section>

      <section className="privacy-section" id="holds">
        <h2>Hold anything for a moment</h2>
        <p>
          Now the thing you&rsquo;d otherwise never find. Across the whole app:{' '}
          <strong>a tap does the thing, a hold edits the thing.</strong>{' '}Press and hold for about
          half a second and you&rsquo;ll usually get more. Once you know the rule you don&rsquo;t
          need the list &mdash; but some of these are genuinely hidden, so here it is.
        </p>

        <h3>On the practice screen</h3>
        <Shot
          src="/redmoon/shot-loops.png"
          alt="The practice screen again, with the tempo readout, the song title, a loop row and a panel header marked."
          pins={[
            { n: '1', x: 76.1, y: 12.3, w: 10.6, h: 5.0, title: 'Hold for the tempo editor' },
            { n: '2', x: 25.2, y: 3.4, w: 23.8, h: 3.6, title: 'Hold for song details' },
            { n: '3', x: 12.3, y: 62.5, w: 13.4, h: 3.4, title: 'Hold to multi-select' },
            { n: '4', x: 39.4, y: 67.6, w: 42.2, h: 4.9, title: 'Tap plays, hold edits' },
          ]}
          caption="Same screen, different secrets. ① hold the BPM readout for the tempo editor — tap along, type it, or let it guess, plus the 1 and the time signature. It doesn't change what you're hearing: for that, tap the speed on the far left and type an exact one · ② hold the title for song details · ③ hold the panel header to select several · ④ tap a loop to play it, hold it to edit"
        />
        <div className="rm-beta-table-wrap">
          <table className="rm-beta-table">
            <tbody>
              <tr><td><strong>Tap the speed</strong>{' '}&mdash; the 1.00&times; on the far left</td><td>Type an exact speed. The slider is too short to land on 0.85&times;</td></tr>
              <tr><td><strong>Hold the BPM number</strong></td><td>The tempo editor: tap along to the song, type the BPM, or have it guess from the audio &mdash; plus where the 1 falls and the time signature. This tells the app what the <em>song&rsquo;s</em>{' '}tempo is; it doesn&rsquo;t change what you&rsquo;re hearing</td></tr>
              <tr><td><strong>Hold the song title</strong></td><td>Song details</td></tr>
              <tr><td><strong>Hold a loop</strong>{' '}in the panel below</td><td>Edit it (a tap just plays it)</td></tr>
              <tr><td><strong>Hold a marker</strong></td><td>Edit it (a tap jumps there)</td></tr>
              <tr><td><strong>Hold a panel header</strong></td><td>Select several at once, to delete or edit in bulk</td></tr>
              <tr><td><strong>Double-tap</strong>{' '}the restart button</td><td>Jump to the previous marker</td></tr>
              <tr><td><strong>Hold</strong>{' '}the skip button</td><td>Choose how far it skips</td></tr>
              <tr><td><strong>Hold &ldquo;Loop controls&rdquo;</strong>{' '}&mdash; the status line under the speed bar, beside Follow and Grid</td><td>This screen&rsquo;s four switches, opened over the waveform so you can watch them take effect: which side the Loop button sits on, the whole-song strip, marker labels, and what pinch-to-zoom holds still. A <em>tap</em>{' '}still shows the gesture cheatsheet</td></tr>
              <tr><td><strong>Pinch</strong>{' '}the waveform</td><td>Zoom, centred where your fingers are</td></tr>
            </tbody>
          </table>
        </div>

        <h3>Everywhere</h3>
        <div className="rm-beta-table-wrap">
          <table className="rm-beta-table">
            <tbody>
              <tr><td><strong>Hold a &minus; or + button</strong></td><td>It repeats, and speeds up the longer you hold. Don&rsquo;t tap forty times</td></tr>
              <tr><td><strong>Hold any row</strong>{' '}in a list</td><td>Its menu, including Favourite and Delete</td></tr>
              <tr><td><strong>Swipe a row</strong></td><td>The same actions, faster</td></tr>
              <tr><td><strong>Hold &ldquo;insert rest&rdquo;</strong>{' '}when building a routine</td><td>Places rests between <em>every</em>{' '}block at once</td></tr>
              <tr><td><strong>Drag a block</strong>{' '}in a routine</td><td>Reorder it</td></tr>
            </tbody>
          </table>
        </div>
        <p className="rm-beta-aside">
          If you use VoiceOver, all of these are announced as actions &mdash; you don&rsquo;t need
          this page.
        </p>
        <SectionNav id="holds" />
      </section>

      <section className="privacy-section" id="build-a-drill">
        <h2>Build your own drill</h2>
        <p>
          Beyond songs, you can build practice drills from scratch:{' '}
          <strong>Practice &rarr; Exercises &rarr; +</strong>. Pick a template and it gives you the
          right surface for that kind of practice &mdash; a fretboard for scales, a chord grid for
          progressions, a strum lane for rhythm. There are fourteen: Basic, Strumming, Scales,
          Arpeggios, Chords, Chords &amp; Strum, Picking, Legato, Fingerstyle, Rhythm, Warm-up, Ear
          training, Theory and Freeform.
        </p>
        <Shot
          src="/redmoon/shot-exercise.png"
          alt="A scale drill running: the fretboard with the notes of A minor pentatonic, and a five-stage tempo ramp underneath reading warm-up, command, reach, back off."
          caption="A Scale drill mid-run. The tempo ramp underneath is the point — warm-up, command, reach, back off — and the board walks along with it."
        />
        <p>
          <strong>Freeform</strong>{' '}is worth knowing about: a duration and a box for your own
          instructions. Sight-reading, transcribing, whatever your teacher set you &mdash; practice
          that&rsquo;s real but that the app doesn&rsquo;t model.
        </p>
        <p>
          <strong>Guitar or bass is decided on this screen</strong>, by the control at the top
          &mdash; not in Settings. Settings &rarr; You only sets which one the screen <em>opens</em>{' '}
          on; whatever you pick here is what the drill is, and what its notes get named in. Pick{' '}
          <strong>Bass</strong>{' '}and you get a four-string neck, bass tuning, and a chord
          vocabulary a bassist would actually play &mdash; roots and fifths, octaves, the major and
          minor tenth, two shell shapes for further up. Strumming and Chords &amp; Strum aren&rsquo;t
          offered for a bass drill, because a down/up strum lane isn&rsquo;t a bass technique.
        </p>
        <p>
          <strong>The board moves while it plays.</strong>{' '}The walking highlight &mdash; the one
          that walks a scale along the fretboard, or the strokes along the strum lane, in time
          &mdash; is on out of the box. If you&rsquo;d rather it didn&rsquo;t, Settings &rarr;
          Practice has the switch, and Reduce Motion turns it off everywhere.
        </p>
        <p>
          <strong>For the beta, please build at least two:</strong>{' '}one <strong>Scale</strong>{' '}
          and one <strong>Chord progression</strong>. They&rsquo;re the two richest editors and the
          two I most need eyes on.
        </p>
        <StepControls step={STEPS[5]} done={done} toggle={toggle} />
        <StepControls step={STEPS[6]} done={done} toggle={toggle} />
        <SectionNav id="build-a-drill" />
      </section>

      <section className="privacy-section" id="planner">
        <h2>Let it plan the session</h2>
        <p>
          <strong>Home &rarr; Start today&rsquo;s session.</strong>{' '}Set a goal, pick a length, and
          it builds a session out of <em>your</em>{' '}library. What it chooses leans on how long
          since you last practised something, how well you&rsquo;ve rated yourself on it, which goal
          you set and how high you weighted it, and the genres you picked when you first opened the
          app.
        </p>
        <Shot
          src="/redmoon/shot-planner.png"
          alt="Today's session setup: a Quick / Focused / Full length picker, an Away from your instrument switch, and one goal listed underneath."
          caption="What you tell it: how long you have, and what you're aiming at. Away from your instrument builds listening work instead — for a commute, or a room where you can't make noise."
        />
        <Shot
          src="/redmoon/shot-routine.png"
          alt="A generated session: seven numbered blocks, including two rests, each showing its drill and command tempo."
          caption="What comes back. Seven blocks, rests included, each with the tempo it's asking for — and you can still edit any of it before you press Start."
        />
        <p>Two honest notes:</p>
        <ul>
          <li>
            <strong>It draws only on what you&rsquo;ve built.</strong>{' '}On a fresh install
            that&rsquo;s six drills, so early sessions feel thin. It gets meaningfully better once
            you have a dozen &mdash; which is why this is worth trying in week three, not day one.
          </li>
          <li>
            <strong>Rating something 5 out of 5 retires it.</strong>{' '}The planner reads that as
            <em>done</em>{' '}and stops offering it. Nothing decays it back on its own &mdash; if you
            want it in rotation again, lower the rating yourself. The app won&rsquo;t quietly change
            a number you set.
          </li>
        </ul>
        <StepControls step={STEPS[7]} done={done} toggle={toggle} />
        <SectionNav id="planner" />
      </section>

      <section className="privacy-section" id="the-rest">
        <h2>The rest of it</h2>

        <h3 id="routines">Routines</h3>
        <p>
          String drills into a session you can replay. Rests allowed. They look exactly like the
          planned session above &mdash; same block list, same Start button &mdash; the difference is
          only who chose the blocks.
        </p>

        <h3 id="journal">Journal</h3>
        <p>
          Every note and recording, newest first. Tap the caption on an entry to jump back to what it
          was about. A note doesn&rsquo;t have to be <em>about</em>{' '}anything: the &#xFF0B; writes
          one that belongs to no loop, drill or routine.
        </p>
        <Shot
          src="/redmoon/shot-journal.png"
          alt="The Journal, newest first: a note, a recorded take and a session entry, with All, Notes and Takes filters across the top."
          pins={[
            { n: '1', x: 75.9, y: 4.4, w: 6.9, h: 3.5, round: true, title: 'Progress is behind this' },
            { n: '2', x: 90.0, y: 4.4, w: 6.9, h: 3.5, title: 'Write a note about nothing' },
            { n: '3', x: 22.0, y: 31.0, w: 33.0, h: 2.7, title: 'Captions are links' },
          ]}
          caption="Two of these are easy to miss. ① the ⋯ menu — Progress lives behind it, along with sort order · ② the ＋, for a note that belongs to nothing · ③ every gold caption is a link back to the loop, drill or session the entry came from"
        />
        <Shot
          src="/redmoon/shot-journal-note.png"
          alt="The Quick note sheet over the Journal: a What just happened? field, four tags — Goal, Breakthrough, Struggle, Note — and a line saying it attaches to nothing."
          caption="The ＋ sheet says it out loud: saves straight to your Journal, not attached to any loop or exercise. That's the one you want for “left hand tired today”."
        />

        <h3 id="progress">Progress</h3>
        <p>From the Journal toolbar. Your week, your month, your all-time hours.</p>
        <Shot
          src="/redmoon/shot-progress.png"
          alt="The Progress screen: this week's minutes as a bar per day, this month as a calendar heat map, and an all-time total underneath."
          caption="Three windows on the same log. Nothing here grades you — it counts minutes, and that's all it claims to do."
        />

        <h3 id="toolkit">Toolkit</h3>
        <p>Tuner (guitar and bass), saved chords, glossary. Free forever, no subscription.</p>
        <Shot
          src="/redmoon/shot-toolkit.png"
          alt="The Toolkit: rows for My chords, Tuner, Glossary and Help and FAQs."
          caption="Four doors. None of them are behind the paywall, and they never will be."
        />
        <Shot
          src="/redmoon/shot-tuner.png"
          alt="The tuner, showing E2 in tune: a large green note dial, a needle, and the six strings across the bottom."
          caption="Tune by ear or by mic. Tap a string to hear it — useful when the room is too loud for the mic to hear you."
        />
        <Shot
          src="/redmoon/shot-my-chords.png"
          alt="My chords: four saved voicings as fretboard diagrams, each with its own name."
          caption="Chords you built, kept under the name you gave them. The ＋ opens the same fretboard editor you get inside a Chord drill."
        />

        <h3 id="metronome">Metronome</h3>
        <p>
          Standalone click with ramps and a tap-tempo. The <strong>pencil</strong>{' '}in its toolbar
          writes a note that carries the click you wrote it to &mdash; tempo, time signature,
          subdivision, any withdrawal &mdash; so weeks later it still says what it was clean{' '}
          <em>at</em>.
        </p>
        <Shot
          src="/redmoon/shot-metronome.png"
          alt="The metronome at 90 BPM in 4/4, with the automator set to add 5 BPM every 4 bars up to 110."
          caption="The automator is the part worth finding: add 5 BPM every 4 bars, up to 110, and stop. You set it once and stop thinking about the number."
        />

        <h3 id="settings">Settings</h3>
        <p>
          Grouped by what you&rsquo;re changing rather than by which screen it affects &mdash; so
          the click lives under <strong>Sound &amp; feel</strong>, count-in under{' '}
          <strong>Practice</strong>, and everything about the waveform screen under{' '}
          <strong>Song player</strong>. If you used an earlier build and something has moved, it has
          probably moved here.
        </p>
        <Shot
          src="/redmoon/shot-settings.png"
          alt="The Settings hub: You and Red Moon Pro at the top, then Appearance, Sound and feel, Practice, Routines and Song player, then Privacy and Help and About."
          caption="Most switches also sit where you use them — holding “Loop controls” on the practice screen opens that screen's four switches over the waveform. This is the other door to the same settings, not a different set."
        />

        <h3 id="help-faqs">Help &amp; FAQs</h3>
        <p>
          In the Toolkit, and in Settings &rarr; Help &amp; About. Eighteen answers to the questions
          that actually come up. Start there before you email me.
        </p>
        <SectionNav id="the-rest" />
      </section>

      <section className="privacy-section" id="feedback">
        <h2>Telling me what happened</h2>
        <p>
          <strong>Use TestFlight.</strong>{' '}Take a screenshot inside the app, then share it to
          TestFlight &mdash; you can scribble on it and add a note. That comes straight to me with
          your device and build details attached, which saves us both a round trip.
        </p>
        <p>
          There&rsquo;s also a <strong>Contact Support</strong>{' '}row in Settings &rarr; Help &amp;
          About. It used to open Mail &mdash; and do nothing at all if you had no Mail account set
          up &mdash; but it&rsquo;s a form now: your email, your message, Send. It works whether or
          not Mail is configured. Three details ride along, and they&rsquo;re printed in the sheet
          above the Send button so you can see exactly what you&rsquo;re sending: the app version,
          your iOS version and your device model. Nothing from your library goes with it &mdash; not
          your songs, recordings, notes or artist name.
        </p>
        <Shot
          src="/redmoon/shot-contact.png"
          alt="The Contact support sheet: an email field, a message field, and a Sent with your message box listing the app version, iOS version and device model."
          caption="The three details are printed in the sheet, above Send, so you can read exactly what goes with your message before you send it."
        />
        <p>
          Either channel reaches me. TestFlight is still the better one for anything visual, because
          the screenshot comes attached.
        </p>
        <p>
          And on this page, every step has an <strong>&ldquo;It didn&rsquo;t do that&rdquo;</strong>{' '}
          button. Press it the moment something goes sideways &mdash; a note written while
          you&rsquo;re confused is worth ten written a week later.
        </p>
        <h3>What I&rsquo;m actually after</h3>
        <p>Not &ldquo;it&rsquo;s nice&rdquo;. This:</p>
        <ul>
          <li>Where did you stop, and what did you try next?</li>
          <li>What did you expect to happen that didn&rsquo;t?</li>
          <li>What did you open it for the last time, and what made you put it down?</li>
        </ul>
        <p>The confusing parts are the useful parts. Send those.</p>
        <SectionNav id="feedback" />
      </section>

      <section className="privacy-section" id="checklist">
        <h2>Where you&rsquo;re up to</h2>
        <p className="rm-beta-progress">{completed}{' '}of {STEPS.length} done</p>
        <ul className="rm-beta-checklist">
          {STEPS.map((step) => (
            <li key={step.id}>
              <label>
                <input type="checkbox" checked={!!done[step.id]} onChange={() => toggle(step.id)} />
                <span>{step.label}</span>
              </label>
            </li>
          ))}
        </ul>
        <SectionNav id="checklist" />
      </section>
    </>
  )
}

/* ---- Per-section footer: where you are, and the two ways out ---- */

/* The guide is read two ways — front to back as a walkthrough, and jumped into from the contents
   for one feature. Prev/next serves the first, "Contents" the second. Empty spans hold the grid
   columns at the ends so "Contents" stays put rather than sliding to the edge. */
function SectionNav({ id }: { id: string }) {
  const index = SECTIONS.findIndex((section) => section.id === id)
  const previous = index > 0 ? SECTIONS[index - 1] : null
  const next = index >= 0 && index < SECTIONS.length - 1 ? SECTIONS[index + 1] : null

  return (
    <nav className="rm-beta-sectionnav" aria-label="Section">
      {previous
        ? <a className="rm-beta-sectionnav-prev" href={`#${previous.id}`}>&larr;{' '}{previous.title}</a>
        : <span />}
      <a className="rm-beta-sectionnav-top" href="#contents">&uarr;{' '}Contents</a>
      {next
        ? <a className="rm-beta-sectionnav-next" href={`#${next.id}`}>{next.title}{' '}&rarr;</a>
        : <span />}
    </nav>
  )
}

/* ---- Per-step controls: tick it off, or report that it didn't behave ---- */

function StepControls({
  step,
  done,
  toggle,
}: {
  step: Step
  done: Record<string, boolean>
  toggle: (id: string) => void
}) {
  const [open, setOpen] = useState(false)
  const [text, setText] = useState('')
  const [sent, setSent] = useState(false)
  const [failed, setFailed] = useState(false)

  async function send() {
    if (!text.trim()) return
    setFailed(false)
    const body = new FormData()
    body.append('_subject', `Red Moon beta — confusion report (${step.id})`)
    body.append('step', step.id)
    body.append('step_label', step.label)
    body.append('what_happened', text)
    try {
      const res = await fetch(FORMSPREE, { method: 'POST', body, headers: { Accept: 'application/json' } })
      if (!res.ok) throw new Error('rejected')
      setSent(true)
    } catch {
      /* Never swallow this silently — a tester who thinks they reported something and didn't is
         worse than one who knows the button failed. */
      setFailed(true)
    }
  }

  return (
    <div className="rm-beta-step">
      <label className="rm-beta-step-check">
        <input type="checkbox" checked={!!done[step.id]} onChange={() => toggle(step.id)} />
        <span>{step.label}</span>
      </label>

      {!open && !sent && (
        <button type="button" className="rm-beta-report" onClick={() => setOpen(true)}>
          It didn&rsquo;t do that
        </button>
      )}

      {sent && <p className="rm-beta-sent">Got it &mdash; thank you.</p>}

      {open && !sent && (
        <div className="rm-beta-report-form">
          <label htmlFor={`report-${step.id}`}>What happened instead?</label>
          <textarea
            id={`report-${step.id}`}
            rows={3}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="What you tapped, and what the app did."
          />
          <div className="rm-beta-report-actions">
            <button type="button" onClick={send} disabled={!text.trim()}>Send</button>
            <button type="button" className="rm-beta-cancel" onClick={() => setOpen(false)}>Cancel</button>
          </div>
          {failed && (
            <p className="rm-beta-error">
              That didn&rsquo;t send. Please put it in a TestFlight note instead so it isn&rsquo;t
              lost.
            </p>
          )}
        </div>
      )}
    </div>
  )
}

/* ---- The gate ---- */

function AcceptGate({ onAccept }: { onAccept: () => void }) {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [agreed, setAgreed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [badEmail, setBadEmail] = useState(false)

  const valid = name.trim() && email.trim() && agreed

  /* Deliberately loose — enough to catch "xxx.com", not enough to argue with anyone's real
     address. Formspree does the authoritative check; this exists so the common typo is caught
     here, with an accurate message, instead of coming back as a generic server error. */
  const looksLikeEmail = (value: string) => /\S+@\S+\.\S+/.test(value.trim())

  function letThemIn() {
    try {
      localStorage.setItem(ACCEPT_KEY, 'yes')
    } catch {
      /* Private browsing. They'll be asked again next visit; not worth blocking on. */
    }
    onAccept()
  }

  async function accept() {
    if (!valid || busy) return
    if (!looksLikeEmail(email)) {
      setBadEmail(true)
      return
    }
    setBadEmail(false)
    setBusy(true)

    const body = new FormData()
    body.append('_subject', 'Red Moon beta — ground rules accepted')
    body.append('name', name)
    body.append('email', email)
    body.append('accepted_at', new Date().toISOString())

    try {
      await fetch(FORMSPREE, { method: 'POST', body, headers: { Accept: 'application/json' } })
    } catch {
      /* Swallowed on purpose. Recording the acceptance is worth something; it is not worth
         locking a tester out of the guide because a third-party form endpoint was unreachable.
         They have read the rules either way — that is what the screen is actually for. */
    }
    letThemIn()
  }

  return (
    <section className="privacy-section">
      <h2>First, the ground rules</h2>
      <p>
        Thanks for doing this. Three things, and then we&rsquo;ll get to the music.
      </p>
      <ul>
        <li>
          <strong>Don&rsquo;t share the build.</strong>{' '}The TestFlight link is yours. Apple&rsquo;s
          terms say the same thing, but it&rsquo;s worth saying in plain English.
        </li>
        <li>
          <strong>Don&rsquo;t post screenshots</strong>{' '}or talk about it publicly yet.
        </li>
        <li>
          <strong>Tell me when it&rsquo;s bad.</strong>{' '}Politeness is the enemy here. If something
          confused you, that&rsquo;s the most useful sentence you can send me &mdash; more useful
          than anything you liked.
        </li>
      </ul>

      <div className="rm-beta-gate">
        <label htmlFor="beta-name">Your name</label>
        <input id="beta-name" value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" />

        <label htmlFor="beta-email">Your email</label>
        <input
          id="beta-email"
          type="email"
          inputMode="email"
          value={email}
          onChange={(e) => {
            setEmail(e.target.value)
            if (badEmail) setBadEmail(false)
          }}
          autoComplete="email"
        />
        {badEmail && (
          <p className="rm-beta-error">
            That doesn&rsquo;t look like an email address &mdash; it needs an @.
          </p>
        )}

        <label className="rm-beta-agree">
          <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} />
          <span>I&rsquo;ve read the three rules above and I&rsquo;ll stick to them.</span>
        </label>

        <button type="button" onClick={accept} disabled={!valid || busy}>
          {busy ? 'One moment…' : 'Open the guide'}
        </button>

      </div>
    </section>
  )
}