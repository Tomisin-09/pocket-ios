import SwiftUI

// **Into it** (ADR 0227 D5, amended by ADR 0230): how the note being named was reached. From the tap
// before, when the two were heard as two notes; or from a start inside this note, a **lead-in**, when they
// were heard as one: a grace note hammered, pulled or slid from another fret, or a slide in from nowhere,
// for one note or a shape moving as one (a double-stop slid into place).
// All four ways in are always shown, so a pull-off is there to be seen before a note goes down to one.
// Split out for file length.
extension NeckNoteEditor {

    /// *Into it* and its ⓘ on a line of their own, the four ways in under them at full width: with the ⓘ
    /// beside them they no longer fit one row on the smallest phone.
    var intoControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                rowTitle("Into it")
                InfoPopoverButton(subject: "Into it", info: voice.intoInfo)
                    .padding(.vertical, -8)
            }
            MarkSegments(options: IntoChoice.allCases.map { choice in
                let route = NeckJoin.route(choice, into: marked, of: labels)
                return MarkSegments.Option(title: choice.title, isOn: isLit(choice),
                                           isEnabled: route != .unavailable) {
                    apply(NeckEditing.choose(choice, labels: labels, cursor: cursor))
                }
            })
            intoLine
        }
    }

    /// The choice the note holds, or while the neck waits for a start, the one being started.
    private func isLit(_ choice: IntoChoice) -> Bool {
        if let awaitingStart { return choice == awaitingStart.choice }
        return NeckJoin.holds(choice, into: marked, of: labels)
    }

    // MARK: - The line under it

    @ViewBuilder private var intoLine: some View {
        if let request = awaitingStart, let notes = labels[marked]?.frettedNotes, !notes.isEmpty {
            hint(startPrompt(request, notes))
            HStack(spacing: 18) {
                if request.join == .slide {
                    link("From below") { apply(NeckEditing.slideIn(from: .below, labels: labels, cursor: cursor)) }
                    link("From above") { apply(NeckEditing.slideIn(from: .above, labels: labels, cursor: cursor)) }
                }
                link("Cancel") { awaitingStart = nil }
            }
        } else {
            if let line = intoText { hint(line) }
            if let offer = intoOffer { link(offer.title, action: offer.action) }
        }
    }

    /// Where to tap for the start: on the note's own string, or for a shape on any of its strings, the
    /// others following.
    private func startPrompt(_ request: LeadInRequest, _ notes: [FrettedNote]) -> String {
        guard notes.count == 1, let note = notes.first else {
            switch (request.join, request.direction) {
            case (.legato, .upward?):
                return "Tap the fret one of its notes was hammered on from, below it. The others move with it."
            case (.legato, _):
                return "Tap the fret one of its notes was pulled off from, above it. The others move with it."
            case (.slide, _):
                return "Tap the fret one of its notes slid from; the others move with it. Or it slid in from nowhere:"
            }
        }
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
        guard let notes = labels[marked]?.frettedNotes, !notes.isEmpty else { return "Place the note first." }
        if let leadIn = notes[0].leadIn {
            let heard = notes.count == 1 ? voice.asOneNote : "moving as one"
            switch leadIn.from {
            case .fret(let start) where notes.count == 1: return "Started at fret \(start), \(heard)."
            case .fret(let start):
                let frets = abs(start - notes[0].fret)
                let side = start < notes[0].fret ? "lower" : "higher"
                return "Started \(frets) fret\(frets == 1 ? "" : "s") \(side), \(heard)."
            case .below: return "Slid in from below, \(heard)."
            case .above: return "Slid in from above, \(heard)."
            }
        }
        // The tap before, as its chip numbers it.
        let before = "Note \(marked)"
        let placedBefore = marked > 0 ? fretText(labels[marked - 1]?.frettedNotes ?? []) : ""
        if NeckJoin.symbol(into: marked, of: labels) != nil {
            return "From \(before.lowercased()) (\(placedBefore)), \(voice.asTwoNotes)."
        }
        guard let blocker = NeckJoin.blocker(into: marked, of: labels) else { return nil }
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
        if marked + 1 < labels.count, NeckJoin.direction(into: marked + 1, of: labels) != nil {
            return reason + " A hammer-on or slide into note \(marked + 2) goes on that note."
        }
        return reason + (notes.count == 1 ? voice.startedElsewhere
            : " Moved into place as one? Pick how.")
    }

    /// The one thing to do from here: move a lead-in's start, or say a join from the tap before was really
    /// heard as one note.
    private var intoOffer: (title: String, action: () -> Void)? {
        guard case .fretted(let notes, let into) = labels[marked], !notes.isEmpty else { return nil }
        if let leadIn = notes[0].leadIn {
            let way = leadIn.join == .legato ? leadIn.direction(into: notes[0].fret) : nil
            return ("Change where it started", { awaitingStart = LeadInRequest(join: leadIn.join, direction: way) })
        }
        guard let into, NeckJoin.symbol(into: marked, of: labels) != nil else { return nil }
        let way = into == .legato ? NeckJoin.direction(into: marked, of: labels) : nil
        let title = notes.count == 1 ? voice.oneNoteOffer : "Moved into place as one?"
        return (title, { awaitingStart = LeadInRequest(join: into, direction: way) })
    }
}
