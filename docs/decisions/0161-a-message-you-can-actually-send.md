# ADR 0161 — a message you can actually send

- **Status:** **Accepted — built 2026-08-12** (branch `pocket-254-a-message-you-can-send`)
- **Date:** 2026-08-12
- **Supersedes:** the `mailto:` Contact Support row introduced with ADR 0145. The plain-text address
  that ADR 0145 required in the "How do I get help?" answer **stands, and matters more** — see D5.
- **Relates to:** ADR 0120 / ADR 0147 (analytics, and the only other thing this app sends anywhere) ·
  ADR 0002 (the AI proxy backend, which this deliberately does **not** wait for) · ADR 0092 (the AI
  charter's "audio never leaves the device" promise, which this does not touch)

## Context

Settings ▸ About has had a **Contact Support** row since ADR 0145. It is a `mailto:` link, and a
`mailto:` **silently does nothing** on a device with no Mail account configured — no error, no sheet,
no feedback of any kind. The tap just fails.

This was known when it shipped. The comment above the row said so, and it is the stated reason ADR
0145 requires the support address to *also* appear as selectable plain text inside the "How do I get
help?" answer. The row was the convenience; the answer was the guarantee.

That trade was acceptable while the app had no players. It stops being acceptable at the point a
closed beta puts the app in front of eight people whose entire job is to tell us what went wrong.
A beta tester who taps Contact Support, gets nothing, and concludes the app is broken is a tester
we have lost — and the report we lose is the one about the feature that failed first.

### The app has never made a network call

This is the app's **first `URLSession`**, and the launch-readiness gate says so in as many words:
*"nothing calls it (zero `URLSession` in V1)"*. That gate exists to keep the privacy story simple,
and it is a real constraint rather than a slogan — it is why the privacy policy could state that the
app's only third-party processor is Aptabase.

So this is not a small feature. It is the feature that ends a property the app has had since it was
written, and the paperwork is a co-requisite rather than a follow-up (D6, D7).

## Decision

### D1 — the row opens an in-app form, not Mail

`ContactSupportSheet` collects a message and a reply address and POSTs them over HTTPS. It works on
every device, whether or not Mail is configured, and it can report its own failure.

### D2 — the reply address is required

Send stays disabled until the message is non-empty and the address is plausible. A support message
with no return address is one we can read and never answer; the player learns nothing, waits, and
concludes we ignored them. A momentarily dim button is a far smaller cost.

`SupportRequest.looksLikeEmailAddress` is a **typo catcher, not a validator**, and must not grow into
one. Formspree does the authoritative check. Every serious attempt to match RFC 5322 with a pattern
ends up rejecting addresses that genuinely work, and a player locked out of the support form by our
own regex has no way left to tell us about it.

### D3 — the diagnostics are shown, not merely disclosed

Three facts travel with the message: app version and build, iOS version, and hardware model
identifier (`iPhone17,1`). They are **printed in the sheet, above the Send button**, under the header
"Sent with your message".

Not in a disclosure triangle, not in a privacy policy the player would have to go and find — on the
screen, in the moment, in the same words that get sent. This is the same posture ADR 0147 took for
analytics: the way you earn the right to send something is to say plainly that you are sending it.

The mechanism is that the sheet and the payload both read `SupportDiagnostics.summary`, so they
cannot drift apart, and `testPayloadCarriesNothingTheSheetDoesNotShow` fails if a fourth field is
ever added to the payload without also appearing on screen.

Nothing else goes: no identifier, no locale, no carrier, no storage figures, nothing derived from the
library. Not song titles, not the artist name, not notes, not recordings.

### D4 — Formspree, not a backend of our own

We post to `https://formspree.io/f/mbdweqar` — the same form the marketing site's contact page and
the beta guide already use, so support messages from every surface land in one inbox in one format.

**The alternative was considered properly and rejected on the facts** (see *Alternatives*). It is not
a lock-in: `SupportSending` is a one-method protocol, and replacing Formspree is a second conformance
and a different URL. No view, no test and no ADR has to move.

### D5 — the plain-text address survives, and is load-bearing again

ADR 0145's requirement stands. The reason has *changed shape*: a `mailto:` failed silently, so the
address was the fallback for a failure nobody could see. An HTTPS form fails **visibly**, and when
Formspree refuses — a tripped spam rule, the monthly cap — retrying will not help, so the error
message has to send the player somewhere. `SupportSendError.rejected` names
`FAQEntry.supportAddress` directly. Deleting it from the FAQ answer now breaks an error message too,
and a test pins that.

### D6 — the privacy manifest is updated in the same commit

`PrivacyInfo.xcprivacy` gains three `NSPrivacyCollectedDataTypes` entries: `EmailAddress`,
`OtherUserContent` and `OtherDiagnosticData`, all with purpose `AppFunctionality` (Apple's vocabulary
has no "customer support" purpose; the six valid values are ThirdPartyAdvertising,
DeveloperAdvertising, Analytics, ProductPersonalization, AppFunctionality and Other).

All three are declared **`Linked` = true**, deliberately. The message and device details arrive
attached to a reply address the player chose to give us, so they are associated with an identity even
though the app has no accounts. Declaring them unlinked would be the convenient answer and the wrong
one. `NSPrivacyTracking` stays `false` — nothing here is tracking, and Tier 3 remains ruled out.

### D7 — the published privacy policy must be corrected *before* this ships

This is the part that is easy to miss and impossible to fix afterwards. The live policy at
`decooperations.co.uk/privacy`, in the Red Moon Practice section, currently says:

> The other processors listed in this policy (Vercel, AWS, Twilio, Formspree) **are not used by this
> app**.

Shipping this feature makes a published privacy statement false. The correction lives in a different
repo (`laundry-pickup-project`, branch `uk-site`, `app/privacy/page.tsx`) which **auto-deploys to
production on every push**, so the ordering is forced and is the right way round: **correct the
policy first, then ship the build.** The processor table already lists Formspree for "Contact form
delivery" and §4 already covers retention, so the edit is narrow — but it is not optional.

### D8 — the wire contract was verified, not assumed

The two callers already using this form (the marketing site's contact page, the beta guide's confusion
reports) both post `FormData`. JSON was therefore **unproven against this endpoint**, and a unit suite
driving a stubbed `URLProtocol` would have passed regardless — the failure would have surfaced on the
first real send, from a beta tester whose only way to report it was the thing that just broke.

Both paths were checked against the live endpoint on 2026-08-12:

| | Status | Body |
|---|---|---|
| Accepted | `200` | `{"next":"/thanks","ok":true}` |
| Refused | `422` | `{"error":"Validation errors","errors":[{"code":"TYPE_EMAIL",…,"message":"should be an email"}]}` |

That check paid for itself twice. It confirmed JSON is accepted, and the refusal body showed that a
rejection can be **correctable** — so `playerFacingMessage` now repeats Formspree's reason instead of
flatly telling the player that retrying won't help, which for a mistyped address would have been
wrong.

## Alternatives considered

### Build our own endpoint instead of using a third party — rejected for now

The instinct is right and the reasoning survives scrutiny in one respect: we will need our own
backend eventually, for the Phase 4 Claude proxy. Doing it now would be a rehearsal.

It was rejected on four specifics:

1. **There is nothing to extend.** `infrastructure/prod/` contains a single `.gitkeep`. The Release
   `POCKET_API_HOST` is still the placeholder `api.pocket.example.com`. "In-house" means standing up
   new infrastructure, not reusing any.
2. **It would not remove a third party, only change which one.** A serverless route still needs an
   email API (Resend, SES) to deliver to the support inbox. We would swap "Formspree" in the privacy
   policy for "Resend" — the same disclosure, the same sub-processor entry, plus an API key to hold.
3. **A public POST endpoint shipped inside a client needs a rate limiter and a spam story**, both of
   which we would be writing from scratch, in the site repo that auto-deploys to production on every
   push, while a beta waits on it.
4. **It is the last item before the closed beta**, which is already on hold. The cost of choosing
   Formspree now is close to zero *because* of `SupportSending`; the cost of choosing wrong later is
   one conformance.

**Revisit when either of these becomes true:** the free tier's 50 submissions/month starts binding,
or the endpoint — which ships extractable in the binary, the same exposure the marketing site has
always had — gets scraped and abused. Neither is a reason to pre-build today.

### Keep the `mailto:` alongside the form — rejected

Two rows doing the same job, one of which silently fails on some devices. The failure mode is the
whole reason for this ADR; keeping a door that sometimes leads nowhere, next to one that works, only
makes it likelier someone picks the broken one.

### Attach logs, or the library contents — rejected

Richer triage, and it would make some bug reports much easier to action. It also breaks D3: the
moment what is attached stops being something a player can read in full on one line, "we send this
and nothing else" stops being a sentence we can honestly write on the screen. The version, the OS and
the model answer most triage questions; the rest can be asked for in the reply.

### Send anonymously (no address) — rejected

See D2.

## Consequences

- The app makes network calls now. The launch-readiness gate's "zero `URLSession`" line is retired
  and replaced by a narrower one: **the only outbound calls are opt-in analytics and a support
  message the player typed and sent by hand.**
- `AboutSection` grows a `sender` dependency, defaulted to `FormspreeSender()` so `SettingsView` is
  unchanged. The sheet is hosted there rather than in `SettingsView`, which sits just under
  SwiftLint's 400-line ceiling.
- A failed send **keeps the sheet open with every character intact**. Losing a written message to a
  dropped connection would be a second failure on top of the first, and the player would have no idea
  the first had happened.
- The FAQ answer for "How do I get help or report a bug?" no longer says the row opens Mail, because
  it doesn't. A help answer describing a door that isn't there is the exact bug the beta guide
  already taught us to avoid.
- `FormspreeSenderTests` drives a stubbed `URLProtocol` and never touches the network — a suite that
  posted to the live form would burn the monthly allowance and spam the support inbox on every CI
  run.
