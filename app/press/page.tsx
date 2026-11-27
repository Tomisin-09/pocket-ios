import type { Metadata } from 'next'
import Image from 'next/image'
import Link from 'next/link'
import { APP_STORE_URL, RedMoonFooter, RedMoonNav } from '../_components/brand'

// The press kit: one page a writer can take everything from without asking. The facts, two
// ready-to-use descriptions, five of the App Store frames and the brand files, each downloadable.
//
// The words come from the App Store description (`docs/app-store-listing-copy.md` on main) and the
// landing page, so the three say the same thing. The price is said as a schedule, as the landing
// page says it: on day 31 the founding block comes off the landing page (ADR 0320 D3), and this
// page's price row goes in the same change.
//
// The frames are the 1.6 App Store set at full size (6.9", `appstore-2026-11-24/6.9/`), copied into
// `public/press/` so they download under a name that says what they are. The logos are the site's
// own `/redmoon/*.svg`, which are derived from the app (`scripts/derive-brand-svgs.py` on main);
// `red-moon-logo.png` is `logo.svg` rendered at 2048 px wide on a transparent ground.
//
// `tomisin-alabi.jpg` is cropped from a performance photo to Tomisin alone (other people in the frame
// are left out, since they didn't agree to be in a press kit) and re-encoded without its metadata.
// The photographer is Binh Dang (@binhsdump), credited under it.

export const metadata: Metadata = {
  alternates: { canonical: '/press' },
  title: 'Press kit — Red Moon Practice Studio',
  description:
    'Facts, descriptions, screenshots, the app icon and the logo for Red Moon Practice Studio, a practice studio for guitar and bass players on iPhone.',
}

const PRESS_EMAIL = 'redmoon@decooperations.co.uk'

const FRAMES = [
  { file: 'red-moon-01-work-it-out.png', title: 'Loop the bar you can’t play. Slow it down.' },
  { file: 'red-moon-02-build-it-up.png', title: 'Every drill runs against a click.' },
  { file: 'red-moon-03-run-it.png', title: 'Line up the hard parts. Press play.' },
  { file: 'red-moon-04-keep-it-journal.png', title: 'Pick up where you left off.' },
  { file: 'red-moon-06-work-it-out-by-ear.png', title: 'Name the notes by ear. See them on the neck.' },
]

export default function RedMoonPressPage() {
  return (
    <div className="rm-page">
      <RedMoonNav />

      <main className="privacy-page">
        <div className="privacy-inner">
          <p className="section-label">Press kit</p>
          <h1 className="section-heading">Red Moon Practice Studio</h1>
          <p className="privacy-meta">A practice studio for guitar and bass players, on iPhone</p>

          <section className="privacy-section">
            <h2>At a glance</h2>
            <dl className="rm-press-facts">
              <dt>Name</dt>
              <dd>Red Moon Practice Studio. Red Moon, after the first mention.</dd>
              <dt>What it is</dt>
              <dd>A practice app for guitar and bass players who learn from everywhere</dd>
              <dt>Platform</dt>
              <dd>iPhone, iOS 17 or later</dd>
              <dt>Price</dt>
              <dd>
                Free to download, with one plan inside: £0.99 a month or £4.99 once for Red Moon’s first 30
                days on sale, then £2.99 a month or £9.99 once. The monthly starts with a free week. The song
                player and its loops, the Metronome, the Journal and the Toolkit are free for good.
              </dd>
              <dt>Account</dt>
              <dd>None</dd>
              <dt>Made by</dt>
              <dd>Tomisin Alabi, in London</dd>
              <dt>Developer</dt>
              <dd>Deco Operations Ltd</dd>
              <dt>Links</dt>
              <dd>
                <a href={APP_STORE_URL}>App Store</a> · <Link href="/">Website</Link> ·{' '}
                <Link href="/story">Liner notes</Link>, the story behind it
              </dd>
              <dt>Contact</dt>
              <dd>
                <a href={`mailto:${PRESS_EMAIL}`}>{PRESS_EMAIL}</a>
              </dd>
            </dl>
          </section>

          <section className="privacy-section">
            <h2>About Red Moon</h2>
            <p>Use either version as it stands, or cut it down.</p>

            <h3>In one paragraph</h3>
            <div className="rm-press-copy">
              <p>
                Red Moon Practice Studio is an iPhone app for guitar and bass players who learn from
                everywhere. Players loop and slow down songs they own, drill against a click, line the hard
                parts up into a routine, and keep a record of everything they do, so their practice adds up
                instead of starting over. It has no account, and it never scores anyone’s playing.
              </p>
            </div>

            <h3>At more length</h3>
            <div className="rm-press-copy">
              <p>
                Red Moon Practice Studio is a practice studio for guitar and bass players who learn from
                everywhere: a video lesson, a teacher, a tab, a record they love. It doesn’t hand them another
                method. It gives them the tools to build their own from what they already learn from, and it
                keeps everything they do, so their practice adds up instead of starting over.
              </p>
              <p>
                Players bring in songs they own, loop the bar they can’t play yet and slow it down while the
                pitch stays true. Drills for scales, arpeggios, picking and chord changes run against a click,
                with a tempo ramp that raises the speed a step at a time. Loops, songs, drills and rests chain
                into a routine, and Today’s session builds one from the player’s own goals. Takes, notes and a
                practice log keep the record. The log shows the days and minutes played, and never scores
                them.
              </p>
              <p>
                There’s no account, and what a player records or writes stays on their phone unless they send
                it themselves. Red Moon is made in London by Tomisin Alabi, a self-taught guitarist.
              </p>
            </div>
          </section>

          <section className="privacy-section">
            <h2>Who makes it, and why</h2>
            <div className="rm-press-maker">
              <figure>
                <Image
                  src="/press/tomisin-alabi.jpg"
                  alt="Tomisin Alabi playing an acoustic guitar in front of a brick wall."
                  width={1150}
                  height={1437}
                  sizes="(max-width: 560px) 100vw, 220px"
                />
                <figcaption>
                  <span className="rm-press-credit">
                    Photo by Binh Dang,{' '}
                    <a href="https://www.instagram.com/binhsdump/" target="_blank" rel="noopener noreferrer">
                      @binhsdump
                    </a>
                    . Please credit it.
                  </span>
                  <a href="/press/tomisin-alabi.jpg" download>
                    JPEG, 1150 × 1437
                  </a>
                </figcaption>
              </figure>
              <div>
                <p>
                  Red Moon is made by Tomisin Alabi, a self-taught guitarist in London. It’s named after the
                  Tom Misch song Tomisin was learning when the setup kept getting in the way: dialling in the
                  metronome, finding where the last session ended, rewinding the same lick by hand.
                </p>
                <p>
                  The app gives those tools one home, so practice picks up where it stopped. The whole story is
                  in the <Link href="/story">liner notes</Link>, in Tomisin’s own words.
                </p>
              </div>
            </div>
          </section>

          <section className="privacy-section">
            <h2>What Red Moon won’t do</h2>
            <ul>
              <li>
                <strong>Grade your playing.</strong> There’s no score, and no pass or fail. The player is the
                one listening.
              </li>
              <li>
                <strong>Ask for an account.</strong> There’s nothing to sign up for.
              </li>
              <li>
                <strong>Take your playing.</strong> Audio, recordings, notes and song names stay on the device
                unless the player sends them.
              </li>
              <li>
                <strong>Count what you do.</strong> Red Moon has no analytics, and it never uses the
                advertising identifier.
              </li>
            </ul>
            <p>
              Each of these is a written decision in the app’s design record, which runs to more than 300
              of them.
            </p>
          </section>

          <section className="privacy-section">
            <h2>Screens</h2>
            <p>Five of the App Store frames, full size: PNG, 1320 × 2868.</p>
            <ul className="rm-press-shots">
              {FRAMES.map((f) => (
                <li key={f.file}>
                  <a href={`/press/${f.file}`} download className="rm-press-shot">
                    <Image
                      src={`/press/${f.file}`}
                      alt={`Red Moon’s App Store frame: ${f.title}`}
                      width={1320}
                      height={2868}
                      sizes="(max-width: 600px) 44vw, 130px"
                    />
                    <span>Download</span>
                  </a>
                </li>
              ))}
            </ul>
          </section>

          <section className="privacy-section">
            <h2>Icon and logo</h2>
            <div className="rm-press-assets">
              <figure>
                <div className="rm-press-tile">
                  <Image src="/press/red-moon-app-icon.png" alt="Red Moon’s app icon" width={1024} height={1024} sizes="120px" />
                </div>
                <figcaption>
                  App icon
                  <a href="/press/red-moon-app-icon.png" download>
                    PNG, 1024 × 1024
                  </a>
                </figcaption>
              </figure>
              <figure>
                <div className="rm-press-tile rm-press-tile-dark">
                  <Image src="/redmoon/logo.svg" alt="The Red Moon logo: a red crescent and stars over the words Red Moon" width={512} height={450} sizes="120px" unoptimized />
                </div>
                <figcaption>
                  Logo
                  <a href="/redmoon/logo.svg" download="red-moon-logo.svg">
                    SVG
                  </a>
                  <a href="/press/red-moon-logo.png" download>
                    PNG, 2048 wide, transparent
                  </a>
                </figcaption>
              </figure>
              <figure>
                <div className="rm-press-tile rm-press-tile-dark">
                  <Image src="/redmoon/mark.svg" alt="The Red Moon mark: the crescent and stars" width={345} height={512} sizes="80px" unoptimized />
                </div>
                <figcaption>
                  The moon on its own
                  <a href="/redmoon/mark.svg" download="red-moon-mark.svg">
                    SVG
                  </a>
                </figcaption>
              </figure>
            </div>
            <p>
              The logo’s red is <strong>#C24A2C</strong>, and the icon’s ground is <strong>#0F0F0F</strong>.
              Please don’t recolour, stretch or redraw them.
            </p>
          </section>

          <section className="privacy-section">
            <h2>Contact</h2>
            <div className="rm-contact-card">
              <p>
                <strong>Email:</strong> <a href={`mailto:${PRESS_EMAIL}`}>{PRESS_EMAIL}</a>
              </p>
              <p>We usually reply within a couple of working days.</p>
            </div>
          </section>
        </div>
      </main>

      <RedMoonFooter />
    </div>
  )
}
