# App Store listing copy — Red Moon Practice v1.0

Draft copy for the App Store Connect submission. Tweak freely; character limits
are Apple's hard caps. Honesty guardrail: Red Moon practises against **your own
local / iCloud audio files** — never imply Apple Music / Spotify streaming (see
[ADR 0001](decisions/0001-audio-source-local-first.md)).

---

## Name (reserved)
**Red Moon Practice** — already reserved in App Store Connect (the qualifier that
clears the "Red Moon Fitness" name collision).

## Subtitle — 30 char max
> **Loop, slow down, learn songs**  *(28)*

Alternates:
- `Slow down and loop any song` *(27)*
- `The guitar woodshed in your pocket` — too long (34); trim if you love it.

## Promotional text — 170 char max (editable anytime, no review)
> Bring your own tracks and loop the hard bar until it's yours — slow it down,
> keep the pitch, and drill scales, chords and routines between takes. *(140)*

## Keywords — 100 char max, comma-separated, NO spaces after commas
Don't spend keyword space on words already in the name ("practice") or subtitle.
> `guitar,looper,slow downer,metronome,tempo,scales,chords,arpeggio,riff,solo,transcribe,woodshed,bass`

*(99 chars — verify in the field; ASC counts live.)*

## Description
> **Red Moon is a practice room, not a jukebox.**
>
> Drop in your own recordings — local files or anything in iCloud Drive — and
> turn the part you can't play yet into the part you own. Set a loop over the
> tricky bar, slow it down without dropping the pitch, and run it until your
> hands catch up.
>
> **Loop and slow down**
> • Draw a loop on the waveform and repeat it hands-free
> • Slow the tempo while the pitch stays true
> • Stack loops across a song and jump between them
>
> **A real metronome**
> • Precise, steady tempo you can trust
> • Use it on its own or under any exercise
>
> **Exercises that show you the neck**
> • Scales and arpeggios drawn as fretboard boxes, labelled by where your hand
>   goes
> • Chords as diagrams — open shapes, movable barre grips, or a custom placer
>   for any voicing you can imagine
> • Picking, legato and strumming drills with a tempo ramp
>
> **Build a session**
> • Chain loops, songs and exercises into a routine and press play
> • Keep a private journal of how a passage is coming along
>
> Everything stays on your device and your iCloud. No account, no ads, no
> tracking, nothing sent anywhere.
>
> Named after the Tom Misch track that started it all.

## Support URL — REQUIRED
Needs to resolve to a real page. Cheapest route: a single static page (GitHub
Pages, Notion public page, or a Carrd) with a contact email. Placeholder:
`https://<host>/red-moon-practice/support`

## Marketing URL — optional
Leave blank for v1, or point at the same host's landing page.

## Privacy Policy URL — REQUIRED
Host `docs/privacy-policy.md` (rendered) somewhere public and paste the URL.
GitHub Pages renders Markdown directly, which is the zero-effort option.

## Category
- **Primary:** Music
- **Secondary:** Education

## Age rating
Questionnaire answers are all "None" → **4+**.

## Price / availability
- **Price:** Free (the base ADPLA covers free apps; you haven't accepted
  Schedule 2 and there's no IAP in v1 — keep it free).
- **Availability:** All territories, unless you want a phased rollout.

## Export compliance
Auto-skipped — `ITSAppUsesNonExemptEncryption = false` is already set.

---

## Hosting (support + privacy pages)

**Privacy Policy — reuse the existing company policy.** Add a "Red Moon Practice
(iOS app)" section to the existing per-service policy at
`decooperations.co.uk/privacy` (Vercel), matching the Docket/website section style
— see the paste-ready section text in chat / commit. It must state the app collects
nothing (no accounts, no analytics, no networking, local + own-iCloud only). Give
Apple the anchored URL so the reviewer lands on the relevant section:
- **Privacy Policy URL** → `https://decooperations.co.uk/privacy#red-moon-practice`
  (verify the heading slugifies to that anchor).
- `docs/site/privacy.html` is now **redundant** — delete once the section is live.

**Support URL.** Deploy `docs/site/support.html` to AWS under `decooperations.click`
(matches the `click.decooperations.pocket` bundle namespace):
- `docs/site/support.html` → **Support URL** `https://decooperations.click/redmoon/support`
- Zero-deploy alternative: point Support URL at the existing
  `decooperations.co.uk/contact` form (loses the iOS-17 / your-files expectations
  the dedicated page sets).

Contact email on the support page: `support@decooperations.click` — confirm it
exists / forwards before submission. Marketing URL: leave blank for v1 (full
marketing site is a post-launch project; point the Marketing URL at it later — no
new build needed).

## Screenshots — final upload order (6.5", 1242×2688)
NOTE: this app's listing exposes the **6.5"** iPhone slot, which accepts only
1242×2688 / 1284×2778 — NOT the 6.9" 1320×2868 size. Rescale to 1242×2688.
Curated 8, ordered for the install sheet (first 3 carry the pitch):

1. Loop trainer, Solo 1 playing (1.00×, 86 BPM) — hero, the moat
2. A–B loop + "Save as loop" (0.75×) — the core gesture
3. A Minor Pentatonic (fretboard + ramp + journal) — "it teaches"
4. Red Moon Practice Routine — session spine
5. Metronome + Automator — trust/utility
6. Custom chord placer (C minor) — novelty
7. Chord run (Irreplaceable plagal) — chords in action
8. Library (clean) — where you live

Upscale every shot from 16 Pro native (1206×2622) to the 6.5" size before upload:
```bash
for f in *.png *.PNG; do sips -z 2688 1242 "$f" --out "appstore-$f"; done
```
Done: `Documents/Red Moon Screenshots 2/appstore-1242x2688/` (named 01–08 in slot order).

## Pre-submission checklist
- [ ] Subtitle, promotional text, keywords, description entered (above)
- [ ] 8 screenshots upscaled to 1320×2868 and uploaded in order
- [ ] `support@decooperations.click` mailbox live
- [ ] "Red Moon Practice" section added to decooperations.co.uk/privacy; `#red-moon-practice` anchor resolves
- [ ] support.html deployed to decooperations.click/redmoon/support
- [ ] Support URL + Privacy Policy URL pasted into the form
- [ ] Category: Music (primary) / Education (secondary)
- [ ] Age rating questionnaire → 4+
- [ ] Price: Free · Availability set
- [ ] `xcodegen generate` → Archive (Release, team 2L35PZ86GP — Deco Operations Ltd, paid; owns `click.decooperations.pocket`) → Upload
- [ ] Build finished processing and attached to version 1.0
- [ ] Add for Review → Submit
- [ ] (optional) fix "Dont" → "Don't" in the seeded library before re-shooting #8
