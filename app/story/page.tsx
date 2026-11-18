import type { Metadata } from 'next'
import Link from 'next/link'
import Reveal from '../_components/Reveal'
import { RedMoonFooter, RedMoonNav } from '../_components/brand'

export const metadata: Metadata = {
  alternates: { canonical: '/story' },
  title: 'Liner notes — why Red Moon exists',
  description:
    'Why Red Moon exists: learning a song you love, John Mayer on breaking music down to its smallest particle, and a practice studio built to take away the obstacle of showing up.',
  openGraph: {
    title: 'Liner notes — why Red Moon exists',
    description:
      'Break the song down to its smallest particle, then rebuild it as your own. Why the Red Moon practice app exists.',
    type: 'article',
  },
}

export default function RedMoonStoryPage() {
  return (
    <div className="rm-page rm-dark rm-story">
      <RedMoonNav current="story" />
      <header className="rm-story-hero">
        <div className="rm-story-hero-inner">
          <h1 className="rm-story-lyric">
            &ldquo;<span className="red">Red moon,</span> <b>black sky</b>
            <br />
            <span className="l2">I&rsquo;ll wait for you, <em>to rise</em>&rdquo;</span>
          </h1>
          <p className="rm-story-credit">
            <span className="dash">&mdash;</span>&nbsp; Red Moon by Tom Misch
          </p>
        </div>

        <div className="rm-story-scrollcue" aria-hidden="true">
          <span>Read</span>
          <span className="chev" />
        </div>
      </header>

      <main>
        <Reveal />
        <article className="rm-story-essay">
          <p className="rm-story-lead reveal">
            I&rsquo;d heard the song before, but it had never really grabbed me. Good enough for the
            rotation, nothing more. Then &mdash; I couldn&rsquo;t tell you exactly when &mdash; maybe on the
            10th listen towards the end of the outro solo, it hit me - <em>This is the greatest song
            I&rsquo;ve ever heard ✨</em>
          </p>

          <figure className="rm-story-listen reveal">
            <p className="rm-story-listen-cue">
              <span aria-hidden="true" className="cue-glyph">&#9654;</span>
              Hit play. Read on.
            </p>
            <div className="rm-story-listen-frame">
              <iframe
                src="https://www.youtube-nocookie.com/embed/riDSMdAH5hk?rel=0"
                title="Tom Misch — Red Moon (Official Lyric Video)"
                loading="lazy"
                allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                referrerPolicy="strict-origin-when-cross-origin"
                allowFullScreen
              />
            </div>
            <figcaption className="rm-story-listen-links">
              <span className="lbl">Listen</span>
              <a href="https://www.youtube.com/watch?v=riDSMdAH5hk" target="_blank" rel="noopener noreferrer">YouTube</a>
              <a href="https://music.apple.com/gb/song/red-moon/1809221847" target="_blank" rel="noopener noreferrer">Apple Music</a>
              <a href="https://open.spotify.com/track/7DXnpSVdUIRQ5gAfucmQIv" target="_blank" rel="noopener noreferrer">Spotify</a>
            </figcaption>
          </figure>

          <p className="reveal">
            That moment happens a couple of times a year to me if I'm lucky. But that&rsquo;s the beautiful
            thing about music. You don&rsquo;t choose what moves you or when. Sometimes it isn&rsquo;t
            even love at first listen. But when you connect with a song, it&rsquo;s like magic. It suddenly
            becomes the soundtrack to a certain time and place in your life &mdash; no matter from how long ago.
            I&rsquo;m still rediscovering old Neptunes tracks that take me back to 2003.
          </p>

          <p className="reveal">
            When you&rsquo;re a musician it goes further, because learning a song adds a whole new dimension
            to loving it. Grammy award-winning artist and guitar virtuoso John Mayer put it better than I can:
          </p>

          <blockquote className="rm-story-pull reveal">
            <p>
              &ldquo;If you study it incorrectly, you sound just like it. If you study it correctly, you
              actually don&rsquo;t. You break it down to its smallest particle, then rebuild it &mdash; and
              nobody, not even yourself, will notice it came from anywhere. It&rsquo;s not really the chords or
              the lyrics. It&rsquo;s some other little intent.&rdquo;
            </p>
            <span className="rm-story-attrib">John Mayer</span>
          </blockquote>

          <p className="reveal">
            That&rsquo;s the whole craft, right there: break the song down to its particles, then rebuild it
            as your own. It's like alchemy. Greater musicians than me have spent lifetimes in happy pursuit of this goal.
          </p>

          <p className="rm-story-turn reveal">
            But the first step is <em>breaking it down</em> and that is, for so many, where the trouble starts.
          </p>

          <p className="reveal">
            It&rsquo;s a great time to learn how to play the guitar. With YouTube channels such as{' '}
            <a href="https://www.youtube.com/@activemelody" target="_blank" rel="noopener noreferrer">Active Melody</a>,{' '}
            <a href="https://www.youtube.com/@BOOMBLISS" target="_blank" rel="noopener noreferrer">Boombliss</a>,{' '}
            <a href="https://www.youtube.com/@GuitarZero2Hero" target="_blank" rel="noopener noreferrer">GuitarZero2Hero</a>, there's
            a whole world of guitar content in the palm of your hand. In fact, most of my time learning was spent watching countless YouTube tutorials.
            A cover of <em style={{ marginRight: '0.12em' }}>Frontin&rsquo;</em>{' '}today, some blues licks tomorrow...
            maybe check out that modes video if the thumbnail looks interesting enough.
            We've all come across that clip promising to &ldquo;100x your playing in 30 days.&rdquo;
            Don&rsquo;t get me wrong, as someone with no background in music, those videos were invaluable and I got a lot out of them.
            But there is so much freedom of choice it&rsquo;s hard to find what works for you and shape it into a consistent routine.
          </p>

          <p className="reveal">
            And when you do find a working routine? You encounter obstacles everytime you set up to practice. Checking
            what&rsquo;s on the agenda. Setting up the metronome. Remembering where you left off. Playing along
            with a song and having to manually rewind a section, over and over again just to try and nail that one lick.
            You push through, because nothing worth having comes easy
            &mdash; but those obstacles chip away at your motivation, bit by bit, until that practice schedule you worked so hard to build
            becomes a relic of a bygone era.
          </p>

          <p className="rm-story-gap reveal">
            Those obstacles are the gap between you and what Mayer&rsquo;s describing. Breaking a song down to its
            smallest particle is exactly the work the setup keeps getting in the way of.
            It's what I encountered trying to learn Red Moon and it&rsquo;s what inspired me to develop this app.
          </p>

          <p className="rm-story-appline reveal">
            Red Moon takes the many tools you need to practice &mdash; the
            metronome, the music, the loops, the exercises &mdash; and gives them a home. A workshop where you
            can slow a song down, isolate the lick and loop it, over and over again taking it
            apart one bar at a time. Custom scale, chord and arpeggio exercises to improve your technique on your terms.
            And an intelligent practice routine that integrates all of these features and adapts to your goals and preferences.
            Everything where you need it, so you can skip the setup and
            get to the part that actually matters. <b>Practice.</b>
          </p>
        </article>

        <section className="rm-story-creed reveal" aria-label="What the app will not do">
          <div className="rm-story-creed-card">
            <p>
              There&rsquo;s no score here. No pass or fail, the app can't listen or give feedback on your playing. The
              app will never tell you you&rsquo;re wrong &mdash; because you&rsquo;re the one listening. And your judgement is the only one that matters.
            </p>
            <p className="find">Find the music in the mistakes.</p>
          </div>
        </section>

        <section className="rm-story-close reveal">
          <p>
            Practice is hard, and no app can hand you the motivation to show up. But what ours can do is take away
            the obstacles between you and showing up &mdash; so whether it&rsquo;s five minutes a day or five
            hours, the one thing that matters most gets easier: you show up.
          </p>
          <p className="rm-story-final">
            The path to the <span className="moon-inline">moon</span>{' '}is yours to navigate. We&rsquo;re just
            here to give you the tools to get you on your way.
          </p>
          <div className="rm-story-cta">
            <Link href="/" className="rm-link">&larr; Back to Red Moon</Link>
            <Link href="/support" className="rm-link">Support</Link>
          </div>
        </section>

      </main>

      <p className="rm-story-footer">
        Epigraph: &ldquo;Red Moon&rdquo; &mdash; Tom Misch, <em>Full Circle</em>
      </p>
      <RedMoonFooter />
    </div>
  )
}
