import SwiftUI

// **Into it** (ADR 0227 D5, amended by ADR 0230): how the note being named was reached. From the tap
// before, when the two were heard as two notes; or from a start inside this note, a **lead-in**, when they
// were heard as one: a grace note hammered, pulled or slid from another fret, or a slide in from nowhere.
// All four ways in are always shown, so a pull-off is there to be seen before a note goes down to one.
// Split out for file length.
extension NameTheNotesSheet {

    var intoControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                pickerLabel("Into it").frame(width: 44, alignment: .leading)
                MarkSegments(options: IntoChoice.allCases.map { choice in
                    let route = NeckJoin.route(choice, into: active, of: labels)
                    return MarkSegments.Option(title: choice.title, isOn: isLit(choice),
                                               isEnabled: route != .unavailable) { choose(choice, route) }
                })
            }
            intoLine
        }
    }

    /// The choice the note holds, or while the neck waits for a start, the one being started.
    private func isLit(_ choice: IntoChoice) -> Bool {
        if let awaitingStart { return choice == awaitingStart.choice }
        return NeckJoin.holds(choice, into: active, of: labels)
    }

    /// Join from the tap before when it fits, else ask the neck for where the note started. Tapping the
    /// choice already held changes nothing, so it can't swap a lead-in for the tap before by surprise.
    private func choose(_ choice: IntoChoice, _ route: NeckJoin.Route) {
        let waiting = awaitingStart != nil
        awaitingStart = nil
        guard waiting || choice == .picked || !NeckJoin.holds(choice, into: active, of: labels) else { return }
        switch route {
        case .clear: setInto(nil, leadIn: nil)
        case .fromBefore(let join): setInto(join, leadIn: nil)
        case .inside(let request): awaitingStart = request
        case .unavailable: break
        }
    }

    /// Set how the note was reached: a join from the tap before, or a lead-in inside it, never both.
    func setInto(_ join: Join?, leadIn: LeadIn?) {
        guard case .fretted(var notes, _) = labels[active] else { return }
        if notes.count == 1 { notes[0].leadIn = leadIn }
        labels[active] = .fretted(notes, into: leadIn == nil ? join : nil)
    }

    /// A tap on the neck while *Into it* waits for a start: where the lead-in began, when it can be. A tap
    /// on the note itself gives up; any other is left alone, since the dimmed dots say where to tap.
    func takeStart(string: Int, fret: Int, for request: LeadInRequest) {
        guard let note = labels[active]?.singleNote else {
            awaitingStart = nil
            return
        }
        if NeckJoin.accepts(string: string, fret: fret, asStartOf: note, for: request) {
            setInto(nil, leadIn: LeadIn(from: .fret(fret), join: request.join))
            awaitingStart = nil
        } else if string == note.string, fret == note.fret {
            awaitingStart = nil
        }
    }

    // MARK: - The line under it

    @ViewBuilder private var intoLine: some View {
        if let request = awaitingStart, let note = labels[active]?.singleNote {
            hint(startPrompt(request, note))
            HStack(spacing: 18) {
                if request.join == .slide {
                    link("From below") { slideIn(from: .below) }
                    link("From above") { slideIn(from: .above) }
                }
                link("Cancel") { awaitingStart = nil }
            }
        } else {
            if let line = intoText { hint(line) }
            if let offer = intoOffer { link(offer.title, action: offer.action) }
        }
    }

    private func slideIn(from start: LeadIn.Start) {
        setInto(nil, leadIn: LeadIn(from: start, join: .slide))
        awaitingStart = nil
    }

    /// Where to tap for the start, on the note's own string.
    private func startPrompt(_ request: LeadInRequest, _ note: FrettedNote) -> String {
        let names = TabLine.stringNames(openMidi: tuning.openMidi)
        let string = names.indices.contains(note.string)
            ? names[note.string].trimmingCharacters(in: .whitespaces) + " string" : "same string"
        switch (request.join, request.direction) {
        case (.legato, .upward?): return "Tap the fret it was hammered on from, below it on the \(string)."
        case (.legato, _): return "Tap the fret it was pulled off from, above it on the \(string)."
        case (.slide, _): return "Tap the fret it slid from on the \(string), or it slid in from nowhere:"
        }
    }

    /// What the note holds, or why it can't be joined to the tap before, naming that tap. `nil` when a
    /// join could go here and none has.
    private var intoText: String? {
        guard let notes = labels[active]?.frettedNotes, !notes.isEmpty else { return "Place the note first." }
        if notes.count == 1, let leadIn = notes[0].leadIn {
            switch leadIn.from {
            case .fret(let start): return "Started at fret \(start), heard as one note."
            case .below: return "Slid in from below, heard as one note."
            case .above: return "Slid in from above, heard as one note."
            }
        }
        // The tap before, as its chip numbers it.
        let before = "Note \(active)"
        let placedBefore = active > 0 ? fretText(labels[active - 1]?.frettedNotes ?? []) : ""
        if NeckJoin.symbol(into: active, of: labels) != nil {
            return "From \(before.lowercased()) (\(placedBefore)), heard as two notes."
        }
        guard let blocker = NeckJoin.blocker(into: active, of: labels) else { return nil }
        let reason: String
        switch blocker {
        case .notPlaced: return "Place the note first."
        case .first: reason = "The first note has nothing before it."
        case .previousUnnamed: reason = "\(before) isn’t named yet."
        case .previousByEar: reason = "\(before) was named by ear, so it isn’t on the neck."
        case .otherStrings:
            reason = notes.count > 1 ? "\(before) isn’t on the same strings."
                : "\(before) (\(placedBefore)) is on another string."
        case .sameFret: reason = "\(before) (\(placedBefore)) is on the same fret."
        case .mixedDirections: reason = "The notes don’t all move the same way from \(before.lowercased())."
        }
        // On the first note of a pair, the join belongs to the second; say so rather than offer a start here.
        if active + 1 < labels.count, NeckJoin.direction(into: active + 1, of: labels) != nil {
            return reason + " A hammer-on or slide into note \(active + 2) goes on that note."
        }
        return notes.count == 1 ? reason + " Heard as one note that started elsewhere? Pick how." : reason
    }

    /// The one thing to do from here: move a lead-in's start, or say a join from the tap before was really
    /// heard as one note.
    private var intoOffer: (title: String, action: () -> Void)? {
        guard case .fretted(let notes, let into) = labels[active], notes.count == 1 else { return nil }
        if let leadIn = notes[0].leadIn {
            let way = leadIn.join == .legato ? leadIn.direction(into: notes[0].fret) : nil
            return ("Change where it started", { awaitingStart = LeadInRequest(join: leadIn.join, direction: way) })
        }
        guard let into, NeckJoin.symbol(into: active, of: labels) != nil else { return nil }
        let way = into == .legato ? NeckJoin.direction(into: active, of: labels) : nil
        return ("Heard as one note?", { awaitingStart = LeadInRequest(join: into, direction: way) })
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.futura(.caption, weight: .semibold))
            .tint(PocketColor.practice)
            .buttonStyle(.borderless)
            .padding(.vertical, 2)
    }
}
