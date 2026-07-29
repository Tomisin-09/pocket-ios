import Foundation

/// The exercise's **note rate**, the labels and comparisons derived from it, and the binding between
/// a measured command tempo and the rhythm it was earned at (ADR 0121).
///
/// There is now **one** rhythm concept. What used to be a second axis — `subdivision`, nominally the
/// metronome's click — turned out never to have been wired to the engine at all, so it stated a
/// rhythm without sounding one; 0121 retires it, backfills its value into `Exercise.notesPerBeat`
/// and stops writing it.
///
/// Resolution order is content-first: content that carries its own `notesPerBeat` (every fretboard
/// run, every strum pattern) is authoritative, because that is the axis the Rhythm dropdown moves and
/// the drill actually plays. `Exercise.notesPerBeat` covers templates whose content declares none.
/// When neither states one — a chord-changing drill — the rate is genuinely **unstated**, not
/// "quarters", so it is `nil` and no surface invents a label for it.
extension Exercise {

    /// The rate the **content** declares, or `nil` for a template that has none (chords are held for
    /// beats, not subdivided; the metronome renderer has no notes of its own). Each accessor already
    /// gates on `kind`, but the switch is exhaustive so a new template can't silently inherit a wrong
    /// rate.
    var contentNoteRate: NoteRate? {
        switch kind {
        case .fretboard: fretboardContent.map { NoteRate(perBeat: $0.notesPerBeat) }
        case .strumming: strumPattern.map { NoteRate(perBeat: $0.slotsPerBeat) }
        case .strumChords: strumChordSheet.map { NoteRate(perBeat: $0.strumPattern.slotsPerBeat) }
        case .chords, .metronome: nil
        }
    }

    /// The exercise's **effective** note rate: the content's own where it declares one, else the
    /// drill's own `notesPerBeat`, else `nil` (nothing states a rhythm — see the type note above; a
    /// label is shown only when this is non-`nil`).
    var noteRate: NoteRate? {
        if let contentNoteRate { return contentNoteRate }
        return notesPerBeat.map { NoteRate(perBeat: $0) }
    }

    /// The rhythm the **command tempo** was measured at, when one is bound (ADR 0121). Every surface
    /// that renders the command reads its rhythm from here, not from `noteRate`: the label describes
    /// the measurement, so it must not silently re-badge itself with today's rhythm.
    var commandNoteRate: NoteRate? {
        commandNotesPerBeat.map { NoteRate(perBeat: $0) }
    }

    /// Notes per minute at a given tempo — the **comparison** number, derived and never stored. An
    /// exercise with no declared rhythm counts one note per beat, so it compares as its bare BPM
    /// rather than dropping out of the ordering.
    func notesPerMinute(atBPM bpm: Int) -> Int {
        (noteRate ?? .quarters).notesPerMinute(atBPM: bpm)
    }

    /// Notes per minute at the effective command tempo — what the library's Command sort ranks on, so
    /// *Spider Walk* (80 @ sixteenths = 320) no longer reads as a near-neighbour of *Chord Changes*
    /// (70 @ quarters = 70).
    var commandNotesPerMinute: Int { notesPerMinute(atBPM: command) }

    /// The command → reach line every list row shows, with the rhythm the tempos are measured in
    /// ("Command 80 → 96 BPM · 16ths"). One property rather than four hand-built strings, so the
    /// library, the routine block row, the add-unit picker and the up-next card can't drift apart.
    /// The suffix is omitted when no rhythm is stated — an absent label means "not stated", never
    /// "quarters".
    ///
    /// Prefers the **bound** rhythm (`commandNoteRate`) over today's: these tempos *are* the command,
    /// so they're reported in the rhythm they were measured in. After 0121 the two can only differ
    /// inside an unresolved edit, since every rhythm change resolves the binding.
    var commandProgressLabel: String {
        let tempos = "Command \(command) → \(reachTempo) BPM"
        guard let rate = commandNoteRate ?? noteRate else { return tempos }
        return "\(tempos) · \(rate.compactLabel)"
    }

    // MARK: - Rhythm changes (ADR 0121)

    /// The tempos a rhythm change has to carry across — the pure rescaler's input.
    var rhythmTempos: RhythmChange.Tempos {
        RhythmChange.Tempos(working: workingTempo, command: command,
                            reachOverride: targetTempoOverride,
                            backoffOverride: backoffTempoOverride)
    }

    /// Whether moving to `newPerBeat` **revalues a measured achievement** — the test for whether the
    /// player has to be asked rather than told.
    ///
    /// Requires a measured command *and* a bound rhythm to compare against. A command with no
    /// binding (measured on a drill that stated no rhythm, then given one) isn't being revalued:
    /// nothing was claimed before, so there is no rescale to offer and nothing to re-measure — the
    /// new rhythm is simply stamped.
    func rhythmChangeRevaluesCommand(to newPerBeat: Int) -> Bool {
        guard hasMeasuredCommand, let bound = commandNotesPerBeat else { return false }
        return bound != max(1, newPerBeat)
    }

    /// Move the drill's **own** rhythm to `newPerBeat`, but only when the content isn't the one
    /// stating it — content is authoritative and its editor writes it. Keeps the model coherent
    /// whichever way a rhythm change arrives: after either answer below, `noteRate` reports the
    /// rhythm the drill is now in, with no second call needed to make that true.
    private func adoptOwnNoteRate(_ newPerBeat: Int) {
        guard contentNoteRate == nil else { return }
        notesPerBeat = max(1, newPerBeat)
    }

    /// **Keep the same note speed**: rescale every tempo so the notes-per-minute the player owns is
    /// unchanged (80 @ eighths → 40 @ sixteenths), and re-bind the command to the new rhythm. The
    /// achievement survives the change, restated in the new units.
    func keepNoteSpeed(movingTo newPerBeat: Int, range: ClosedRange<Int>) {
        let rescaled = RhythmChange.keepingNoteSpeed(rhythmTempos,
                                                     from: commandNotesPerBeat ?? newPerBeat,
                                                     to: newPerBeat, clampedTo: range)
        workingTempo = rescaled.working
        commandTempo = rescaled.command
        targetTempoOverride = rescaled.reachOverride
        backoffTempoOverride = rescaled.backoffOverride
        adoptOwnNoteRate(newPerBeat)
        commandNotesPerBeat = max(1, newPerBeat)
    }

    /// **Re-measure**: clear the command and its binding, so the drill reads "not yet measured" until
    /// the player earns one at the new rhythm (the `commandTempo` discipline — an un-promoted
    /// exercise falls back to its working tempo rather than showing a number nobody achieved). The
    /// working floor is still rescaled: a warm-up floor left at the old rhythm is the wrong speed to
    /// warm up at, whichever answer was given.
    func reMeasureCommand(movingTo newPerBeat: Int, range: ClosedRange<Int>) {
        let rescaled = RhythmChange.keepingNoteSpeed(rhythmTempos,
                                                     from: commandNotesPerBeat ?? newPerBeat,
                                                     to: newPerBeat, clampedTo: range)
        workingTempo = rescaled.working
        adoptOwnNoteRate(newPerBeat)
        commandTempo = nil
        commandNotesPerBeat = nil
        // The pins are the player's own goal and floor, not part of the achievement — they're
        // restated in the new rhythm rather than thrown away. Both stay valid: the rescale keeps a
        // reach above command and a backoff at or below it, and the un-promoted command falls back to
        // `working`, which the rescale keeps at or below command too.
        targetTempoOverride = rescaled.reachOverride
        backoffTempoOverride = rescaled.backoffOverride
    }

    /// Bind the command to the drill's current rhythm without touching a tempo — what a rhythm change
    /// that revalues nothing does (no measured command, or none was ever bound).
    func bindCommandRhythmToContent() {
        commandNotesPerBeat = hasMeasuredCommand ? noteRate?.perBeat : nil
    }
}
