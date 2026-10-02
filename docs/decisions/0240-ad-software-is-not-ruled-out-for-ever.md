# ADR 0240 — No ad software today, and not ruled out for ever

- **Status:** Accepted (2026-10-02). Nothing is built and nothing is planned. This changes what Red
  Moon promises, not what it does.
- **Date:** 2026-10-02
- **Amends:** ADR 0120 — §1. Tier 3 is split in two. **The IDFA, the App Tracking Transparency
  prompt and MMPs stay ruled out permanently** (D1). **Ad SDKs leave the permanent ban**: there is
  none in the app, and adding one takes its own ADR first (D2). Tier 1 and Tier 2 are unchanged, and
  §2 to §7 were already superseded by 0239.
- **Relates to:** 0239 (Red Moon counts nothing, and an ad SDK would reopen it) · 0237 (free; D3
  rules out paying to remove ads) · 0092 (your playing never leaves the device) · 0070 (no grading,
  the boundary 0120 §1 was modelled on)
- **Schema:** none. No code changes.

## Context

ADR 0120 §1 closed Tier 3 on 2026-07-29: *"IDFA, the ATT prompt, MMPs, ad SDKs. Ruled out,
permanently."* Red Moon was going to be paid for then. The privacy policy carried it as *"We do not
use the IDFA, the App Tracking Transparency prompt, or any advertising SDK. We never will; this is a
permanent product boundary."*

ADR 0237 made Red Moon free on 2026-10-01, so there is nothing left to sell. On 2026-10-02 the owner
opened the door on ads in future. Ads aren't planned and will probably never come, but with the app
free, the owner doesn't want that door completely shut. Red Moon has not been publicly released, so
the public wording can change now without withdrawing a promise anyone has relied on. After release
it could not.

The ban bundled two different things:

- **Tracking.** The IDFA and the ATT prompt exist to recognise a player across other companies' apps
  and websites, to target ads or measure them. MMPs are the attribution side of the same machinery.
  This is what players' trust rests on, and it is the line the manual, the policy and the company
  site all state in public.
- **Ad software.** An SDK that shows ads. It doesn't have to track: a non-personalised or contextual
  ad needs neither the IDFA nor the prompt.

Only the second stands in the way of the door the owner wants left open.

## Decision

### D1 — Tracking stays ruled out, permanently

No IDFA, no ATT prompt, no MMP, and nothing Apple defines as tracking: linking data from this app
with other companies' data for targeted advertising or advertising measurement, or sharing it with a
data broker. `NSPrivacyTracking` stays `false`. Tier 2, AdAttributionKit with Apple Search Ads, is
still the ceiling for attribution.

The public line *"Red Moon does not use the advertising identifier or the App Tracking Transparency
prompt, and it never will"* stays word for word, in the manual, the policy and the company site.

### D2 — Ad software is not in the app, and is no longer ruled out for ever

There is no ad SDK in Red Moon and none is planned. One can be added only by a new ADR, written
before any code, which has to answer:

- **How it stays inside D1:** non-personalised ads, no tracking under Apple's definition,
  `NSPrivacyTracking` still `false`.
- **What it does to 0239.** Red Moon counts nothing and makes no network call of its own. An ad SDK
  fetches ads and counts impressions, so that ADR has to say what becomes of *"Red Moon doesn't count
  what you do in it."*
- **The policy's own promise.** *Changes to this policy* says any new processing is disclosed and
  **opt-in** before it ships, with its processors and lawful basis named.
- **0237 D3.** Nothing free moves behind a price, so paying to remove ads is out.
- **Where ads may appear.** The Marketing Foundation recommends keeping them off the practice
  screens. That is a recommendation, not decided here.
- **What moves with it:** the privacy policy, the App Privacy label, `PrivacyInfo.xcprivacy` and the
  manual.

Whether Red Moon shows ads of any kind, including a sponsorship or a house ad built into the app with
no SDK, is not decided here either.

### D3 — What the public texts say

`docs/privacy-policy.md`, under *What we do not do*:

- *"We do not show ads or use advertising identifiers"* gains **"and there is no advertising
  software in the app"**. That states today's fact without promising it for ever.
- *"We do not use the IDFA, the App Tracking Transparency prompt, or any advertising SDK. We never
  will"* loses **"or any advertising SDK"**. The permanent promise is now about tracking only.

The manual and the company site already state only the tracking line, so they don't change. "No
ads" stays where it is a present-tense disclosure, and is not used as a selling line (owner,
2026-10-02, recorded in the Marketing Foundation).

### D4 — Nothing in the app changes

No code and no schema. `PrivacyInfo.xcprivacy` is left alone: its comment (*"no IDFA, no ATT
prompt, no ad SDK"*) describes what the app contains today, and that stays true.

## Alternatives rejected

**Remove both "never" lines, tracking included.** This was the owner's first instinct. It was
dropped because the tracking line isn't what blocks the ads the owner might one day run, and it is
the promise worth most to players. Removing it would only make tracked ads possible, at the cost of
the ATT prompt and *"Data Used to Track You"* on the App Store page.

**Leave §1 as written.** It shuts a door the owner wants open. After public release, retracting a
published "never" would cost more than amending it now.

**Soften the public wording and leave 0120 saying "permanently".** A public text that disagrees with
its ADR is how ADR 0144 went on stating a price that had been replaced.

## Consequences

- ADR 0120's header gains *Amended by: ADR 0240*, and §1 carries a note pointing here.
- `docs/privacy-policy.md` changes as D3 says. *Last updated* stays 2 October 2026, the same day.
- `docs/app-store-listing-copy.md`: the App Privacy note now says no IDFA and no ATT prompt
  permanently, and no ad SDK today. The tracking answer in App Store Connect stays **No**.
- **Owed outside the repo:** the Marketing Foundation's ads constraints. An ad SDK is no longer
  banned outright; it needs an ADR that answers D2. The company site needs nothing, since it never
  carried the ad-SDK line.
- **Unaffected:** 0070, 0092's audio boundary, 0237 D3, Tier 2, and 0239. Any ad SDK would reopen
  0239, as D2 says.
