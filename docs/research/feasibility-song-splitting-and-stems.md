# Feasibility — "song splitting" (sections & stems) (research, 2026-07-05)

V2 vision asks for "song splitting capabilities (e.g. Song Surgeon)". That
phrase covers two very different features; they are split here because one is
nearly free and the other is a major bet.

## Reading 1 — splitting a song into sections (cheap, near-term)

Song-Surgeon-style chopping: export a region of a song as its own audio file.
Pocket already has the hard parts — loops *are* sections, and the engine reads
raw PCM from DRM-free files.

- **Build:** an "Export loop as audio" action — read the loop's frame range via
  `AVAudioFile`, write a new file (m4a via `AVAssetExportSession` or wav via
  `AVAudioFile` write), hand it to the share sheet / save to Files.
- **Rights posture:** the user exports a slice of their own file to their own
  device — same posture as any DAW/editor. No sharing rail (ADR 0064 keeps
  audio out of the social layer).
- **Verdict: feasible now.** Small slice, no new permissions, no backend.
  Candidate follow-up: "duplicate song from loop" so a section becomes its own
  practiceable Song with its own loops.

## Reading 2 — stem separation (vocal/instrument isolation) (big bet, spike first)

Demucs-class source separation ("practice against the band minus guitar") is
the ambitious reading.

- **Server-side: rejected as the default path.** It means uploading users'
  copyrighted audio to our backend — a privacy, cost, *and* rights exposure
  that contradicts the local-first posture (ADR 0001, ADR 0064). Would also
  make stem quality a recurring compute bill.
- **On-device: the only path consistent with the product.** HTDemucs-family
  models convert to Core ML; A16+/Neural Engine can separate a 4-minute track
  in roughly real-time-ish (minutes, not seconds — needs a progress UX and
  thermal care). Model weights are ~80–300 MB — an optional download, never in
  the base app bundle. Older devices degrade to "not offered".
- **Licensing check is part of the spike:** Demucs code is MIT but *trained
  weights* carry their own terms and some model zoo variants differ; verify the
  exact weights' licence before shipping, and budget for converting/validating
  ourselves rather than vendoring a random conversion.
- **Verdict: plausible, not V2-early.** Run as a self-contained spike
  (convert model → measure quality/latency/thermals on the user's iPhone →
  decide). Nothing in the current architecture blocks it; stems would enter the
  engine as additional local files, which the pipeline already understands.

## Also in this family: pitch shift / key change (cheap, unlock when wanted)

`AVAudioUnitTimePitch` (already in the engine for speed) does pitch shift
essentially for free — a "practice in a different key / detune half-step"
control is a small UI slice, no research needed. Parked until asked for.
