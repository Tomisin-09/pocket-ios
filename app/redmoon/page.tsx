import type { Metadata } from 'next'
import Link from 'next/link'
import type { StaticImageData } from 'next/image'
import Reveal from './_components/Reveal'
import ShotRail from './_components/ShotRail'
import { Phone, RedMoonFooter, RedMoonNav, StoreButton } from './_components/brand'
import home from './_media/home.png'
import songPlayer from './_media/song-player.png'
import drill from './_media/drill.png'
import routine from './_media/routine.png'
import take from './_media/take.png'
import today from './_media/today.png'
import loopRamp from './_media/loop-ramp.png'
import byEar from './_media/by-ear.png'
import sources from './_media/sources.png'
import log from './_media/log.png'

export const metadata: Metadata = {
  alternates: { canonical: '/' },
  title: 'Red Moon Practice Studio — Give practice a home',
  description:
    'Red Moon is a practice studio for guitar and bass players who learn from everywhere. Loop and slow down songs you own, drill against a click, run routines, and keep everything you do, so your practice adds up instead of starting over. For iPhone.',
}

// Show, don't tell: each idea is one screen and one line. The kickers and headlines are the App Store
// frames' own (appstore-2026-11-16/frames.json), so the site and the listing say the same thing; the
// detail they used to carry lives in the manual now.
type Shot = { kicker: string; title: string; image: StaticImageData; alt: string }

const CHAPTERS: Array<Shot & { line: string }> = [
  {
    kicker: 'Work it out',
    title: 'Loop the bar you can’t play. Slow it down.',
    line: 'Bring in songs you own. Slow them down and the pitch stays true.',
    image: songPlayer,
    alt: 'The song player looping a bar at 0.75× speed, with two saved loops under the waveform.',
  },
  {
    kicker: 'Build it up',
    title: 'Every drill runs against a click.',
    line: 'Tap in a tempo and let the automator raise it, by bars or by time.',
    image: drill,
    alt: 'An alternate-picking drill running at 76 BPM, stepping up a tempo staircase toward 90.',
  },
  {
    kicker: 'Run it',
    title: 'Line up the hard parts. Press play.',
    line: 'Chain loops, songs, drills and rests into a routine.',
    image: routine,
    alt: 'A routine called Open mic, Friday: two drills, a rest and two loops, above a Start button.',
  },
  {
    kicker: 'Keep it',
    title: 'Record a take. Note what you heard.',
    line: 'Pin a note to a moment in a take, so your practice adds up instead of starting over.',
    image: take,
    alt: 'A recorded take of a verse riff with a note, and two comments pinned to moments in it.',
  },
]

const MORE: Shot[] = [
  {
    kicker: 'Run it',
    title: 'Today’s session, shaped by your goals.',
    image: today,
    alt: 'The Practice tab: Today’s session shaped by two goals, then routines, exercises and loops.',
  },
  {
    kicker: 'Build it up',
    title: 'Ramp a loop up to full speed.',
    image: loopRamp,
    alt: 'The loop automator set to climb from 75% to 100% speed in six steps.',
  },
  {
    kicker: 'Work it out',
    title: 'Name the notes by ear. See them on the neck.',
    image: byEar,
    alt: 'A verse riff’s eight notes named and shown on a guitar fretboard.',
  },
  {
    kicker: 'Your sources',
    title: 'Keep the lesson beside the part it’s for.',
    image: sources,
    alt: 'A part’s references: a lesson link, a tab page and a photo of the pattern written out.',
  },
  {
    kicker: 'Keep it',
    title: 'See the days you played. Never a score.',
    image: log,
    alt: 'The practice log: 75 minutes over 5 days this week, by kind, and a month of practised days.',
  },
]

export default function RedMoonPage() {
  return (
    <div className="rm-page rm-dark rm-land">
      <Reveal />
      {/* The scroll-in starts hidden and needs script to show; without script, show it all, prices
          included. */}
      <noscript>
        <style>{'.reveal{opacity:1!important;transform:none!important}'}</style>
      </noscript>
      <RedMoonNav onLanding />

      <main>
        <section className="rm-hero">
          <p className="rm-kicker rm-hero-kicker">Red Moon Practice Studio</p>
          <h1>Give practice a home.</h1>
          <p className="rm-hero-sub">
            A practice studio for guitar and bass players who learn from everywhere.
          </p>
          <div className="rm-hero-actions">
            <StoreButton />
            <p className="rm-hero-meta">iPhone · Guitar and bass · No account</p>
          </div>
          <div className="rm-hero-stage">
            <Phone
              src={home}
              alt="Red Moon’s home screen: Start today’s session, the song you last practised, and this week’s minutes and days."
              sizes="(max-width: 600px) 78vw, 400px"
              eager
            />
          </div>
        </section>

        <div className="rm-chapters">
          {CHAPTERS.map((c) => (
            <section className="rm-chapter" key={c.kicker}>
              <div className="rm-chapter-text reveal">
                <p className="rm-kicker">{c.kicker}</p>
                <h2>{c.title}</h2>
                <p className="rm-chapter-line">{c.line}</p>
              </div>
              <div className="rm-chapter-media reveal">
                <Phone src={c.image} alt={c.alt} sizes="(max-width: 820px) 72vw, 340px" />
              </div>
            </section>
          ))}
        </div>

        <section className="rm-more" aria-labelledby="rm-more-title">
          <ShotRail
            label="More screens from Red Moon"
            heading={<h2 id="rm-more-title">More in the studio.</h2>}
          >
            {MORE.map((s) => (
              <li className="rm-rail-item" key={s.title}>
                <figure>
                  <Phone src={s.image} alt={s.alt} sizes="(max-width: 600px) 64vw, 270px" />
                  <figcaption>
                    <span className="rm-kicker">{s.kicker}</span>
                    {s.title}
                  </figcaption>
                </figure>
              </li>
            ))}
          </ShotRail>
        </section>

        <section className="rm-promises" aria-label="Yours, and only yours">
          <div className="rm-promise reveal">
            <h3>No account.</h3>
            <p>
              Nothing to sign up for, and no <span className="rm-nowrap">third-party</span> trackers.
            </p>
          </div>
          <div className="rm-promise reveal">
            <h3>Your playing never reaches&nbsp;us.</h3>
            <p>
              Your songs, loops, recordings and journal stay on your device unless you send a file of
              them yourself. <Link href="/redmoon/privacy">Read the privacy policy</Link>
            </p>
          </div>
          <div className="rm-promise reveal">
            <h3>Never a score.</h3>
            <p>The practice log shows the days and minutes you played. It never scores them.</p>
          </div>
        </section>

        <section className="rm-quote">
          <figure className="reveal">
            <blockquote>
              You break it down to its smallest particle, then rebuild it — and nobody, not even
              yourself, will notice it came from anywhere.
            </blockquote>
            <figcaption>John Mayer</figcaption>
          </figure>
          <Link href="/redmoon/story" className="rm-textlink reveal">
            Read the story behind the app
          </Link>
        </section>

        <section className="rm-plan" id="get" aria-labelledby="rm-plan-title">
          <div className="rm-plan-card reveal">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img className="rm-plan-logo" src="/redmoon/logo.svg" alt="Red Moon" width={180} height={158} />
            <h2 id="rm-plan-title">One plan</h2>

            <div className="rm-plan-split">
              <div>
                <h3>Free for good</h3>
                <p>Your songs and loops, the Metronome, the Journal and everything in the Toolkit.</p>
              </div>
              <div>
                <h3>The plan</h3>
                <p>For practising: drills, routines, Today’s session and the loop trainer.</p>
              </div>
            </div>

            <p className="rm-price">£0.99 a month, or £4.99 once.</p>
            <p className="rm-price-promise">
              That’s the founding price, and it’s yours for as long as you keep the plan. Nothing you can
              do today will ever move behind a higher one.
            </p>
            <div className="rm-plan-cta">
              <StoreButton />
            </div>
            <p className="rm-price-note">
              The founding price is for Red Moon’s first 90 days on sale. After that, it’s £2.99 a month,
              or £9.99 once. The monthly starts with a free week if you haven’t had one. Prices are for the
              UK; the App Store shows yours in your own currency.
            </p>
          </div>
        </section>
      </main>

      <RedMoonFooter />
    </div>
  )
}
