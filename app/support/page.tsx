import type { Metadata } from 'next'
import Link from 'next/link'
import { RedMoonFooter, RedMoonNav } from '../_components/brand'

export const metadata: Metadata = {
  alternates: { canonical: '/support' },
  title: 'Support — Red Moon Practice Studio',
  description:
    'Help and support for Red Moon Practice Studio, a practice studio for guitar and bass players on iPhone. Contact support@decooperations.co.uk.',
}

const SUPPORT_EMAIL = 'support@decooperations.co.uk'

export default function RedMoonSupportPage() {
  return (
    <div className="rm-page">
      <RedMoonNav current="support" />

      <main className="privacy-page">
        <div className="privacy-inner">
          <p className="section-label">Support</p>
          <h1 className="section-heading">Red Moon Practice Studio</h1>
          <p className="privacy-meta">Help &amp; contact</p>

          <section className="privacy-section">
            <h2>Get in touch</h2>
            <p>
              Red Moon is a practice studio for guitar and bass players on iPhone, made by Deco Operations
              Ltd in London.
              If something isn&rsquo;t working, you&rsquo;ve found a bug, or you have an idea for the app,
              we&rsquo;d genuinely like to hear from you.
            </p>
            <div className="rm-contact-card">
              <p><strong>From the app:</strong>
                {' '}
                Settings &#9656; Help &amp; About &#9656; Contact Support writes to us without leaving Red Moon.
              </p>
              <p><strong>Email:</strong> <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a></p>
              <p>We usually reply within a couple of working days.</p>
            </div>
          </section>

          <section className="privacy-section">
            <h2>Frequently asked questions</h2>

            <h3>Adding songs to practise</h3>
            <p>
              Red Moon practises against audio files you already have. Add a track from your device or
              iCloud Drive, or share one in from another app such as Voice Memos or Files, and it appears
              in your song library, ready to loop, slow down, and mark up. It can&rsquo;t play Apple Music
              or Spotify streams.
            </p>

            <h3>Looping and slowing a track down</h3>
            <p>
              Open a song to see its waveform. Set a loop over the bars you want to drill, then use the speed
              control to bring the tempo down while you get the passage under your fingers. Save a loop and it
              stays with the song — with its own target speed — so you can come back to it any time.
            </p>

            <h3>The metronome and the automator</h3>
            <p>
              The metronome works on its own as a click and tempo trainer. Tap in a tempo, or switch on the
              automator to raise the BPM automatically — by a set amount every few bars, or over time — so you
              can build speed hands-free.
            </p>

            <h3>Exercises, routines, and today&rsquo;s session</h3>
            <p>
              Exercises are short, click-based drills with a fretboard diagram and a target tempo. Routines
              are practice sessions you build from blocks. &ldquo;Today&rsquo;s session&rdquo; assembles a
              session for you from your goals and recent practice, so you can start without planning anything.
            </p>

            <h3>What&rsquo;s free, and what is the plan for?</h3>
            <p>
              Your songs are free for good: import them, play them, slow them down, and keep your loops and
              markers. So are the Metronome, your <strong>Journal</strong>{' '}and Practice log, and
              everything in the <strong>Toolkit</strong>: the tuner, your chords, progressions and tabs, and
              the glossary. The plan is for practising: drills, routines, Today&rsquo;s session, the loop
              trainer, Train your ear, Improvise and Watch it on the neck. Blood Moon is free too; the
              other seven moons, and their icons, come with the plan.
            </p>
            <p>
              <strong>£0.99 a month, or £4.99 once.</strong>{' '}That&rsquo;s the founding price, and
              it&rsquo;s yours for as long as you keep the plan. Nothing you can do today will ever move
              behind a higher one. The monthly starts with a free week if you haven&rsquo;t had one, and
              you can cancel it any time in your Apple Account&rsquo;s Subscriptions. Prices are for the
              UK; the App Store shows yours in your own currency.
            </p>

            <h3>Will the price go up?</h3>
            <p>
              Not for you, if you join at the founding price. It&rsquo;s for Red Moon&rsquo;s first 90
              days on sale. After that, new players pay £2.99 a month, or £9.99 once. If you&rsquo;re on
              the monthly, you keep £0.99 for as long as you keep the plan, and Pay once is never charged
              again. If you stop the monthly, Apple holds your price for a while in case you come back;
              after that, you&rsquo;d join at the price of the day.
            </p>

            <h3>What happens if I stop paying?</h3>
            <p>
              Nothing you made is deleted. Your songs, loops and markers, your Journal and the Toolkit stay
              open, and the practice screens wait behind the plan, just as you left them. Red Moon goes
              back to Blood Moon, and so does its icon.
              Settings &#9656; Your data can always export everything, plan or not.
            </p>

            <h3>I paid once, but my monthly plan is still renewing</h3>
            <p>
              Paying once doesn&rsquo;t cancel a subscription, and Red Moon can&rsquo;t cancel one for
              you. Settings &#9656; Cancel your monthly plan opens your Apple Account&rsquo;s
              subscriptions, where you can turn it off. Settings &#9656; Your plan can also ask Apple for a
              refund of the month that overlapped. Apple decides refunds.
            </p>

            <h3>A new phone, or a reinstall</h3>
            <p>
              The plan belongs to your Apple Account, so it comes back when you sign in with the same one.
              If it doesn&rsquo;t show, Restore purchases on the plan&rsquo;s screen asks Apple again.
              What you made in the app stays on the phone you made it on: Settings &#9656; Your data
              &#9656; Export saves a copy, and Restore from a copy, on the same screen, brings it back on
              the new one.
            </p>

            <h3>Does the app collect my data?</h3>
            <p>
              Your playing never reaches us. There are no accounts, no ads and no third-party trackers, and
              the app never sends us your audio, your recordings, your journal notes, your song names or your
              artist name. It doesn&rsquo;t count what you do in it either: there is no analytics in the
              app. If you export a recording, a song, a routine or a tab, the share sheet hands that
              file to wherever you choose, and it goes there and nowhere else. One thing can reach us, and
              only when you send it: a message you write
              yourself in Settings &#9656; Help &amp; About &#9656; Contact Support &mdash; sent only when you tap
              Send, carrying your email address, your message, and the app version, iOS version and device
              model the form shows you before it sends &mdash; plus, only if you switch it on in
              Settings &#9656; Help &amp; About &#9656; Diagnostics, a one-line summary of any crashes.
              Apple separately gives us anonymous totals, such as how many devices opened the app, from
              people who have turned on Share With App Developers on their iPhone; the app plays no part
              in that. If you buy the plan, Apple takes the payment: we never see your card details or
              your Apple Account, and the app tells us nothing about it. See the{' '}
              <Link href="/privacy#red-moon-practice">privacy note</Link> for the full detail.
            </p>

            <h3>Do my songs sync to my other devices?</h3>
            <p>
              Not at the moment. Your songs, loops, exercises, routines and journal entries are stored on the
              iPhone you created them on, and there is no cross-device sync — so nothing you make is visible
              to us, and nothing follows you to a second device. If you delete the app, that content goes with
              it. Sync is something we may add later; if we do, it will use your own private iCloud storage.
            </p>

            <h3>What do I need to run it?</h3>
            <p>
              An iPhone with iOS 17 or later. Add your own audio files to get the most out of the looping
              and slow-down tools; the metronome and exercises work on their own.
            </p>

            <h3>Requests, bugs, and feedback</h3>
            <p>
              Missing a feature, or hit something that doesn&rsquo;t behave? Email{' '}
              <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> with a short description — and, for a bug,
              your iPhone model and iOS version if you can. It all helps.
            </p>
          </section>

          <section className="privacy-section">
            <h2>More</h2>
            <p>
              <Link href="/">About Red Moon</Link> &nbsp;·&nbsp;{' '}
              <Link href="/privacy#red-moon-practice">Privacy</Link> &nbsp;·&nbsp;{' '}
              <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer">
                Terms of Use
              </a>
            </p>
          </section>
        </div>
      </main>

      <RedMoonFooter />
    </div>
  )
}
