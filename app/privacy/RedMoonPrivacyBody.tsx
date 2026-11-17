/* Red Moon Practice Studio's own privacy policy: the app and redmoonpracticestudio.co.uk.
 *
 * It is a separate document from Deco Operations' policy (app/privacy), which no longer covers Red
 * Moon. Wording is the app repo's docs/privacy-policy.md (canonical) merged with what the live policy
 * said before the split (lawful bases, retention, sub-processors). When what the app sends changes,
 * change this page, the canonical, and the support FAQ together; nothing checks them against each other.
 *
 * The id on §2 is load-bearing: the shipped 1.4 app and App Store Connect link to
 * decooperations.co.uk/privacy#red-moon-practice, and that page keeps a stub with the same id.
 */
export const RED_MOON_POLICY_UPDATED = '16 November 2026'

export default function RedMoonPrivacyBody() {
  return (
    <main className="privacy-page">
      <div className="privacy-inner">
        <p className="section-label">Legal</p>
        <h1 className="section-heading">Privacy Policy</h1>
        <p className="privacy-meta">Red Moon Practice Studio · Last updated: {RED_MOON_POLICY_UPDATED}</p>

        <section className="privacy-section">
          <h2>1. Who we are</h2>
          <p>
            Red Moon Practice Studio (“the app”) is a guitar and bass practice app for iPhone, made by{' '}
            <strong>Deco Operations Ltd</strong>, a company registered in England and Wales (company number{' '}
            <strong>17032490</strong>) with its registered office in London, United Kingdom. We are registered
            with the Information Commissioner’s Office (ICO registration number <strong>ZC112793</strong>).
          </p>
          <p>
            For the purposes of the UK GDPR and the Data Protection Act 2018, Deco Operations Ltd is the data
            controller for the app and for this website, redmoonpracticestudio.co.uk. This policy covers only
            those two. Deco Operations’ other services have their own policy at{' '}
            <a href="https://decooperations.co.uk/privacy">decooperations.co.uk/privacy</a>.
          </p>
        </section>

        <section className="privacy-section" id="red-moon-practice">
          <h2>2. The short version</h2>
          <p>
            <strong>Your playing never reaches us.</strong> The app has no user accounts, no advertising and no
            third-party trackers, and it never sends us your audio, your recordings, your journal notes, your
            song names or your artist name. Everything you make stays on your device unless you send a file of
            it yourself.
          </p>
          <p>
            <strong>The app does not count or report how you use it.</strong> There is no analytics in it.
          </p>
          <p>
            There is one exception to “nothing leaves your device”, and it carries nothing you have played,
            recorded or written: <strong>a message you write to us</strong>, from Settings ▸ Help &amp; About ▸
            Contact Support. Nothing is sent unless you type it and tap Send, and the app shows you everything
            it attaches before you do. See §6.
          </p>
        </section>

        <section className="privacy-section">
          <h2>3. What stays on your device</h2>
          <ul>
            <li>
              <strong>Your practice content</strong>: songs you add, loops, exercises, routines and journal
              entries are stored on your device. The app has no cross-device sync, so none of it is copied to
              any server of ours or to iCloud, and we never see it. If sync is added in a future version it
              will use your own private iCloud storage, and this policy will be updated before it ships.
            </li>
            <li>
              <strong>Your audio files</strong>: the app practises against audio files you choose from your
              device or iCloud Drive, and only ones you explicitly pick. When you add a song, Red Moon keeps
              its <strong>own copy</strong> inside the app’s storage on your phone, so the song still plays if
              you later move, rename or delete the original, and so it comes back with your phone if you
              restore from a backup. Your original file is never moved or altered. The copy stays on your
              device and is included in your own device backup. It is never uploaded to us, and it leaves your
              phone only if you export or send the song yourself.
            </li>
            <li>
              <strong>Your recordings</strong>: practice takes you choose to record with the microphone are
              saved on your device. They are not uploaded, and leave your phone only if you export one
              yourself.
            </li>
            <li>
              <strong>App settings</strong>: preferences such as tempo defaults are kept on your device in the
              system’s standard settings storage. The app also reads the system clock to keep the metronome and
              practice timers accurate; that never leaves your device.
            </li>
          </ul>
        </section>

        <section className="privacy-section">
          <h2>4. Files you send yourself</h2>
          <p>
            You can take things out of the app as files: a backup of everything (Settings ▸ Your data ▸
            Export), a single recording, a song’s audio, a song with its loops and markers for someone else’s
            copy of Red Moon, an exercise, a routine with the songs it plays, or a tab as text or a PDF. Each
            file is made on your device and handed to the iOS share sheet, and you choose where it goes:
            AirDrop, Messages, Mail, Files or another app. The app does not upload it, we keep no copy of it,
            and the app never learns where it went.
          </p>
          <p>
            <strong>A song you send, or a routine that plays songs, carries your artist name</strong> if you
            have set one, so the person who opens it knows who it is from. The send screen shows the name before
            anything is sent. Nothing else from your profile goes with it, and with no artist name set, no name
            is sent.
          </p>
        </section>

        <section className="privacy-section">
          <h2>5. How we know the app is used</h2>
          <p>
            The app itself collects no usage data. It does not count which features you use, it contains no
            analytics software, and it sends nothing about how you use it.
          </p>
          <p>
            Apple separately gives developers anonymous, aggregated figures about their apps: how many devices
            opened the app on a given day, how many sessions there were, how many people kept using it after
            installing, and how often it crashed. Apple collects these only from people who have turned on{' '}
            <strong>Share With App Developers</strong>{' '}in the iPhone’s Settings ▸ Privacy &amp; Security ▸
            Analytics &amp; Improvements, under{' '}
            <a href="https://www.apple.com/legal/privacy/" target="_blank" rel="noopener noreferrer">
              Apple’s privacy policy
            </a>
            . The App Store also gives us totals for how many people viewed the app’s page and downloaded it.
            We see totals, never individuals, and the app plays no part in collecting them. They are not
            personal data, so there is nothing about you in them for us to access, correct or delete.
          </p>
        </section>

        <section className="privacy-section">
          <h2>6. When you write to us</h2>
          <p>
            <strong>From inside the app.</strong>{' '}Settings ▸ Help &amp; About ▸ Contact Support is a form. When
            you tap Send, and only then (nothing is sent in the background), we receive:
          </p>
          <ul>
            <li>
              <strong>The reply address you type</strong>, used to answer you and for nothing else. It is never
              added to a mailing list, and the app has no accounts to attach it to.
            </li>
            <li>
              <strong>The message you write.</strong>
            </li>
            <li>
              <strong>Three technical details</strong> the form shows you in full before you send: the app
              version, your iOS version, and your device model identifier (for example “iPhone17,1”, the
              hardware generation, never a serial number or an advertising ID).
            </li>
            <li>
              <strong>One optional line about crashes</strong>, if you have turned that on (below). The form
              shows it to you too.
            </li>
          </ul>
          <p>
            Nothing is attached from your library: not your songs, your recordings, your journal notes or your
            artist name. The form is delivered by Formspree, Inc. (see §12), which passes it to our support
            inbox.
          </p>
          <p>
            <strong>By email.</strong> If you email us instead, we receive your address and whatever you write,
            and use them to reply.
          </p>
          <p>
            <strong>Lawful basis:</strong> legitimate interests (responding to your message and diagnosing a
            fault you are reporting to us). Because your message arrives attached to an address you chose to
            give us, we treat all of it as linked to you, and you can ask us to delete it (§13).
          </p>

          <h3>Crash and freeze reports</h3>
          <p>
            iOS keeps its own record of any time the app crashed or froze, and hands it to the app roughly once
            a day. <strong>That record stays on your device</strong>, and it is never sent anywhere on its own.
            You can read it, and clear it, at Settings ▸ Help &amp; About ▸ Diagnostics.
          </p>
          <p>
            One switch on that screen, <strong>off unless you turn it on</strong>, adds a single line to your
            next support message: how many crashes or freezes there were, since when, and what iOS called the
            most recent one, with its iOS version. No call stacks, no logs, no file paths, and nothing about
            what you were playing. The line is shown to you on that screen, and again in the form, before you
            send.
          </p>
        </section>

        <section className="privacy-section">
          <h2>7. What we do not do</h2>
          <ul>
            <li>
              We do <strong>not</strong> collect names, contacts or location. We collect an email address only
              when you give us one so we can reply.
            </li>
            <li>
              We do <strong>not</strong> send your audio, recordings, journal notes, song names or artist name
              anywhere, ever, not in a support message or a crash summary either.
            </li>
            <li>
              We do <strong>not</strong> show ads, use advertising identifiers, or put advertising software in
              the app.
            </li>
            <li>
              We do <strong>not</strong> use the IDFA or the App Tracking Transparency prompt, and never will.
            </li>
            <li>
              We do <strong>not</strong> track you across apps or websites, build a profile of you, or sell or
              share your data for advertising.
            </li>
            <li>
              We do <strong>not</strong> put analytics software in the app, or count how you use it.
            </li>
          </ul>
        </section>

        <section className="privacy-section">
          <h2>8. Device permissions</h2>
          <p>
            The app asks for two system permissions, each only when you use the feature that needs it, and both
            used only on your device:
          </p>
          <ul>
            <li>
              <strong>Microphone</strong>: for the tuner, which listens to a played string to work out its
              pitch, analysing the sound as it arrives and keeping none of it, and for the practice takes you
              choose to record, which are saved on your device. iOS shows its recording indicator whenever the
              microphone is active. Nothing the microphone hears is uploaded; the app has no audio upload path.
            </li>
            <li>
              <strong>Notifications</strong>: if you set a practice reminder on a routine, the app asks iOS for
              permission to notify you, at that moment and not before. The reminder is scheduled on your
              device, and iOS delivers it on the days you chose. There is no push service, so nothing about
              your reminders, or about whether you practised, reaches us.
            </li>
          </ul>
          <p>
            The app does <strong>not</strong> ask for access to your music library. It practises against audio
            files you import from Files or iCloud Drive, and it cannot play Apple Music or Spotify streaming
            audio at all.
          </p>
        </section>

        <section className="privacy-section">
          <h2>9. Purchases</h2>
          <p>
            The app is free to download, and its plan is sold through the App Store, as a monthly subscription
            or a single payment. Apple takes the payment and keeps the record of it, under{' '}
            <a href="https://www.apple.com/legal/privacy/" target="_blank" rel="noopener noreferrer">
              Apple’s privacy policy
            </a>
            . We never receive your payment details, your name or your Apple Account. The app checks whether
            you have the plan by asking Apple, on your device, and sends nothing about it to us. Apple gives us
            totals of what was sold, by country, and never who bought it. If you stop paying, nothing you made
            is deleted.
          </p>
        </section>

        <section className="privacy-section">
          <h2>10. This website</h2>
          <p>
            redmoonpracticestudio.co.uk is a set of ordinary pages: no accounts, no forms, no cookies, and no
            analytics. Like any web host, our host (Vercel, §12) handles standard request data, such as your IP
            address and the page you asked for, to deliver the page to you.
          </p>
        </section>

        <section className="privacy-section">
          <h2>11. How long we keep your data</h2>
          <ul>
            <li>
              <strong>Support messages</strong> (from the app or by email): kept in our inbox for up to 2
              years, then deleted, or sooner if you ask us to delete them.
            </li>
            <li>
              <strong>Usage data</strong>: the app sends us none, so there is none to keep.
            </li>
            <li>
              <strong>Your own practice content</strong>: never sent to us, and stays on your device until you
              delete it or remove the app.
            </li>
          </ul>
        </section>

        <section className="privacy-section">
          <h2>12. Who handles data for us</h2>
          <p>
            Apple, which handles purchases and the anonymous figures described above, acts for itself, under
            its own policy. These are the processors that act for us:
          </p>
          <table className="privacy-table">
            <thead>
              <tr>
                <th>Provider</th>
                <th>Purpose</th>
                <th>Data location</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Formspree, Inc.</td>
                <td>Delivery of a support message you send from the app</td>
                <td>US (standard contractual clauses)</td>
              </tr>
              <tr>
                <td>Vercel, Inc.</td>
                <td>Hosting of redmoonpracticestudio.co.uk</td>
                <td>EU / US (standard contractual clauses)</td>
              </tr>
              <tr>
                <td>Google Fonts</td>
                <td>Web fonts (self-hosted at build time)</td>
                <td>No runtime requests to Google</td>
              </tr>
            </tbody>
          </table>
          <p>The app uses no other processor. Nothing is sold, and nothing is shared for advertising.</p>
        </section>

        <section className="privacy-section">
          <h2>13. Your rights</h2>
          <p>Under the UK GDPR you have the right to:</p>
          <ul>
            <li>Access the personal data we hold about you</li>
            <li>Correct inaccurate data</li>
            <li>Request erasure of your data (where no overriding legal basis applies)</li>
            <li>Restrict, or object to, processing based on legitimate interests</li>
            <li>Data portability (where processing is automated and consent- or contract-based)</li>
            <li>
              Lodge a complaint with the Information Commissioner’s Office (ICO) at{' '}
              <a href="https://ico.org.uk" target="_blank" rel="noopener noreferrer">
                ico.org.uk
              </a>
            </li>
          </ul>
          <p>
            Red Moon holds no personal data about you on our systems, apart from any support message you send
            us. Everything you create lives on your own device, under your control. To exercise any of these
            rights, email{' '}
            <a href="mailto:hello@decooperations.co.uk">hello@decooperations.co.uk</a>. We will respond within
            one month.
          </p>
        </section>

        <section className="privacy-section">
          <h2>14. Children</h2>
          <p>
            The app is rated 4+. It has no accounts, asks for no personal details from anyone, including
            children under 13, and collects no usage data.
          </p>
        </section>

        <section className="privacy-section">
          <h2>15. Security</h2>
          <p>
            We apply appropriate technical and organisational measures to protect the personal data we do hold,
            against unauthorised access, loss or disclosure.
          </p>
        </section>

        <section className="privacy-section">
          <h2>16. Changes to this policy</h2>
          <p>
            If a future version of the app adds a feature that processes data differently (for example, an
            optional AI feature that sends practice history to a server), this policy will be updated{' '}
            <strong>before</strong> that feature ships, any such processing will be clearly disclosed and{' '}
            <strong>opt-in</strong>, and the processors and lawful basis will be named here. Other changes will
            be noted at the top of this page with a revised “Last updated” date.
          </p>
        </section>

        <section className="privacy-section">
          <h2>17. Contact</h2>
          <p>
            Questions about this policy, or to exercise any data-protection right:{' '}
            <a href="mailto:hello@decooperations.co.uk">hello@decooperations.co.uk</a>. For help with the app:{' '}
            <a href="mailto:support@decooperations.co.uk">support@decooperations.co.uk</a>.
          </p>
        </section>
      </div>
    </main>
  )
}
