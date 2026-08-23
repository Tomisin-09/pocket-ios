# 0150 — A take is yours to send (export, not hosting)

- **Status:** Proposed — **parked pending legal advice**, and **superseded in
  part by ADR 0181, for self-export only** (see the amendment below). This ADR
  is written to hold the shape of the question, not to authorise a build. It
  must not move to Accepted on the evidence currently in it.
- **Date:** 2026-08-09

## Amendment — 2026-08-23, ADR 0181

Left as written; this note records what has since been decided around it rather
than editing the reasoning that led here.

**One half of this ADR has been acted on.** ADR 0181 ships a whole-archive
export — every song, loop, exercise, routine, journal entry and take, written to
a zip and handed to the OS share sheet. That is the **export, not hosting** case
this ADR reasons through at §29-43, and 0181 adds one argument to it: a backup
the player keeps for restore is a materially weaker case on the Content Rights
axis than a single take one tap from Messages, because the artefact's purpose,
shape and natural destination are all restore rather than distribution.

**The other half stays exactly where it was.** Per-take sharing is still parked.
There is no `ShareLink` on a take row and no share action in `TakesSheet`. Every
open question in §92-110 — the EULA, the Content Rights declaration, commercial
audio picked up through the mic — is still open. Nothing in 0181 resolved them;
it **scoped around** them.

**The decision to proceed for self-export was the owner's, taken 2026-08-22.**
No legal review has happened. Do not read the amendment as evidence that one
did.

**The speaker-bleed warning this ADR asked for was built**, in the form the
archive allows: one line on the export screen and in the manual saying that a
take recorded next to a playing song may have picked that song up through the
mic. The §118-121 claim that the privacy page rests on — *"the app has no audio
upload path"* — was re-checked and still holds: a share sheet transmits nothing.

## Context

A practice take (ADR 0069) is a mic-only AAC file the app writes into its own
container. Today it cannot leave the device by any route: there is no
`ShareLink` or `UIActivityViewController` anywhere in the sources, and
`UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace` are absent from
`Info.plist`, so the container is not even browsable in Files. The privacy
policy states the position flatly — "the app has no audio upload path."

ADR 0064 closed audio sharing: the shareable unit is the exercise, never the
loop, and loop sharing plus any creator-compensation model needs "its own rights
framework to reopen." That ADR was reasoning about a **social backend** —
accounts, a shared-content store, a moderation queue, a stats-ingest path. It
did not consider a local share sheet, because none was proposed. This ADR is
about the gap 0064 left rather than a reversal of what it decided.

The prompt is Voice Memos. Tapping Share there hands the file to the OS and the
user picks a destination; Apple never stores or forwards it. That is a
materially different rail from anything 0064 contemplated, and it is the one
being asked about.

## The distinction this ADR turns on

**Export is not hosting.**

- **Hosting** — we hold the file and serve it to others. That pulls in
  notice-and-takedown machinery (a designated agent and repeat-infringer policy
  for US safe harbour, the equivalent hosting defence in UK/EU), a moderation
  flow, a custom EULA carrying a user warranty, and a changed App Store Connect
  *Content Rights* declaration. This is ADR 0064's territory and **stays
  closed**.
- **Export** — the file goes take → OS share sheet → wherever the user sends it.
  We never receive it, never store it, never serve it. None of the above
  attaches.

Everything below concerns export only.

## Why a take is not a voice memo

Voice Memos is content-agnostic: it has no idea whether it captured a meeting, a
busker, or an album played into the mic, and that ignorance is most of its
safety. Pocket is not ignorant. A take is bound to what it was recorded against,
and the Journal caption says so out loud — "Don't Know Why Guitar Cover ·
Chords" is rendered from the take's own owner link
(`JournalTimeline.label(loop:exercise:song:)`).

That provenance awareness cuts two ways, and both need advice:

1. **Headphone take** — the microphone captured the player alone. That is their
   own performance and their own sound recording. If they were playing someone
   else's song, the *composition* remains third-party, so distributing a cover
   implicates mechanical/sync rights — but that is the user's affair, exactly as
   it is when they post a cover recorded any other way.
2. **Speaker take** — mic bleed baked a commercial master into the file. Sending
   it is distributing an unlicensed copy of someone else's recording, whatever
   the user intended. `docs/research/feasibility-practice-recording.md` already
   called the mixdown version of this "a landmine the moment it syncs or
   shares"; speaker bleed is a weaker form of the same thing, arriving through
   the room instead of through the mixer.

The app already distinguishes these. ADR 0069 Slice 0 built a pure route
classifier that drives the headphone-clean vs speaker-bleed cue at arm time. It
was framed as a recording-quality nudge. Under an export affordance it becomes
the rights signal too, which is a re-purposing worth stating rather than
absorbing silently.

## Proposed decision — NOT ACCEPTED, for discussion only

1. **Export only; hosting stays closed.** ADR 0064 §2 is untouched. Nothing here
   creates an account, a backend, or a Pocket-served copy of any take.
2. **A share sheet on the take rows** — the Journal ▸ Takes rows and the
   per-owner `TakesSheet`, reusing `RecordingStore.url(for:)`, which already
   resolves a real file URL.
3. **Speaker takes carry a warning at export**, driven by the existing route
   classification rather than a new mechanism. Whether a warning is *sufficient*
   is the central open question below.
4. **No batch export in a first slice.** One take, one deliberate action. Bulk
   export changes the character of the feature and should be decided separately.
5. **The mic-only rule is unchanged.** ADR 0069's guarantee — the app never
   renders its own loop or song playback into a take file — is what keeps a
   headphone take clean, and it is not up for revision here.

## Why this is not Accepted

These need a qualified opinion, not a product judgement:

- Does an export affordance on a **provenance-aware** app carry exposure that a
  neutral recorder's does not? The app knows and displays what each take was
  recorded against; that is the fact a general-purpose recorder never has.
- Is a warning on speaker takes sufficient, or should they be **blocked** from
  export? Blocking is enforceable — the classification already exists — but
  punishes the many users whose bleed is inaudible or whose backing was their
  own material.
- Does Apple's **standard EULA** remain adequate when we add an export
  affordance but host nothing? (Expected yes, since there is no UGC hosting, but
  it needs confirming — and if the answer is no, the licence link moves off
  Apple's standard terms across all three surfaces: App Store description,
  `PaywallView`, and Settings ▸ About.)
- Does the ASC **Content Rights** declaration change? (Expected no — we
  distribute nothing — but ADR 0148 §7 is a reminder of how easily that answer
  flips.)
- **UK-first framing**, given the operating jurisdiction, with the US position
  understood rather than assumed.

## Consequences

**If accepted**, the build is small: a `ShareLink` on two surfaces, a warning
path keyed off existing route classification, and a test that a take's file URL
resolves. No backend, no schema change, no new permission.

**While parked**, nothing changes and nothing is owed. Takes stay on-device, the
privacy policy's "no audio upload path" claim stays true, and no user has been
promised an export. That is a comfortable place to wait, which is precisely why
this should wait.

## Related

- ADR 0064 — V2 social layer boundaries (the hosting rail; stays closed)
- ADR 0069 — practice-take recording (mic-only; the route classifier)
- ADR 0001 — audio source local-first (the DRM wall this all sits behind)
- ADR 0148 — songs we own (Content Rights declaration precedent)
- ADR 0142 — journal reach (the owner-caption link the share sheet sits beside)

## Sibling question, decided elsewhere

Whether a take should **survive the deletion of the loop it was recorded
against** is a separate decision about data lifetime, not rights, and needs its
own ADR. It is noted here only because both questions were prompted by the same
Voice Memos comparison: takes now appear in one flat list (Journal ▸ Takes)
while remaining cascade-owned children of their loop or exercise, so the list
implies a permanence the delete rule does not honour. ADR 0143 already solved
this shape for session notes — `routineUID` as a loose id copy plus a
`routineNameAtEntry` snapshot, so "deleting a routine must not delete the
reflection written about it."
