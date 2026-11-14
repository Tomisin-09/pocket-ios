import SwiftUI

// **Into it** (ADR 0227 D5, amended by ADR 0230): how the note being named was reached. From the tap
// before, when the two were heard as two notes; or from a start inside this note, a **lead-in**, when they
// were heard as one: a grace note hammered, pulled or slid from another fret, or a slide in from nowhere,
// for one note or a shape moving as one (a double-stop slid into place). In a chord a hammer-on or
// pull-off moves one note and the rest are held (ADR 0252 D1); *The whole chord moved?* moves them all.
// All four ways in are always shown, so a pull-off is there to be seen before a note goes down to one; after
// a bent note a fifth, Release, lets the bend down on this tap (ADR 0296). Split out for file length.
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
            let options = IntoChoice.offered(into: marked, of: labels).map(intoOption)
            // Five don't fit one row on the smallest phone or at the larger text sizes: Release goes under
            // the four, which stay one row as they always were.
            ViewThatFits(in: .horizontal) {
                MarkSegments(options: options)
                VStack(alignment: .leading, spacing: 6) {
                    MarkSegments(options: Array(options.prefix(4)))
                    if options.count > 4 { MarkSegments(options: Array(options.dropFirst(4))) }
                }
            }
            intoLine
        }
    }

    private func intoOption(_ choice: IntoChoice) -> MarkSegments.Option {
        let route = NeckJoin.route(choice, into: marked, of: labels)
        return MarkSegments.Option(title: choice.title, isOn: isLit(choice), isEnabled: route != .unavailable) {
            apply(NeckEditing.choose(choice, labels: labels, cursor: cursor))
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
            let offers = intoOffers
            if !offers.isEmpty {
                // Side by side where they fit; one under the other at the larger text sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { offerLinks(offers) }
                    VStack(alignment: .leading, spacing: 4) { offerLinks(offers) }
                }
            }
        }
    }

    private func offerLinks(_ offers: [Offer]) -> some View {
        ForEach(offers.indices, id: \.self) { index in
            link(offers[index].title, action: offers[index].action)
        }
    }

    /// Where to tap for the start: on the note's own string; in a chord, on the string of the note that
    /// moved, the rest held (0252 D1); or for a shape moving as one, on any of its strings, the others
    /// following.
    private func startPrompt(_ request: LeadInRequest, _ notes: [FrettedNote]) -> String {
        guard notes.count == 1, let note = notes.first else {
            switch (request.join, request.direction, request.together) {
            case (.legato, .upward?, false):
                return "Tap the fret it was hammered on from, below it, on the string of the note that moved. "
                    + "The rest of the chord is held."
            case (.legato, _, false):
                return "Tap the fret it was pulled off from, above it, on the string of the note that moved. "
                    + "The rest of the chord is held."
            case (.legato, .upward?, true):
                return "Tap the fret one of its notes was hammered on from, below it. The others move with it."
            case (.legato, _, true):
                return "Tap the fret one of its notes was pulled off from, above it. The others move with it."
            case (.slide, _, _), (.release, _, _):
                // A release never waits for a start (ADR 0296 D8); it's listed only so the switch is whole.
                return "Tap the fret one of its notes slid from; the others move with it. Or it slid in from nowhere:"
            }
        }
        let string = stringWords(note.string)
        switch (request.join, request.direction) {
        case (.legato, .upward?): return "Tap the fret it was hammered on from, below it on the \(string)."
        case (.legato, _): return "Tap the fret it was pulled off from, above it on the \(string)."
        case (.slide, _), (.release, _):
            return "Tap the fret it slid from on the \(string), or it slid in from nowhere:"
        }
    }

    /// What the note holds, or why it can't be joined to the tap before, naming that tap. `nil` when a
    /// join could go here and none has.
    private var intoText: String? {
        if labels[marked]?.isMuted == true { return "A muted note has no way in." }
        guard let notes = labels[marked]?.frettedNotes, !notes.isEmpty else {
            // Release places the note itself (ADR 0296 D3), so it's the other way to start one here.
            return NeckJoin.canRelease(into: marked, of: labels)
                ? "Place the note first, or choose Release if note \(marked)’s bend comes down here."
                : "Place the note first."
        }
        if let moving = notes.first(where: { $0.leadIn != nil }), let leadIn = moving.leadIn {
            if notes.count > 1, !NeckJoin.movesAsOne(notes) { return heldText(moving, leadIn) }
            let heard = notes.count == 1 ? voice.asOneNote : "moving as one"
            switch leadIn.from {
            case .fret(let start) where notes.count == 1: return "Started at fret \(start), \(heard)."
            case .fret(let start):
                let frets = abs(start - moving.fret)
                let side = start < moving.fret ? "lower" : "higher"
                return "Started \(frets) fret\(frets == 1 ? "" : "s") \(side), \(heard)."
            case .below: return "Slid in from below, \(heard)."
            case .above: return "Slid in from above, \(heard)."
            }
        }
        // The tap before, as its chip numbers it.
        let before = "Note \(marked)"
        let placedBefore = marked > 0 ? fretText(labels[marked - 1]?.frettedNotes ?? []) : ""
        if case .fretted(_, _, .release?) = labels[marked], NeckJoin.releases(into: marked, of: labels) {
            return "Let down from \(before.lowercased()) (\(placedBefore)), \(voice.asTwoNotes)."
        }
        if NeckJoin.symbol(into: marked, of: labels) != nil {
            return "From \(before.lowercased()) (\(placedBefore)), \(voice.asTwoNotes)."
        }
        guard let blocker = NeckJoin.blocker(into: marked, of: labels) else { return nil }
        let reason: String
        switch blocker {
        case .notPlaced: return "Place the note first."
        case .muted: return "A muted note has no way in."
        case .first: reason = "The first note has nothing before it."
        case .previousUnnamed: reason = "\(before) isn’t named yet."
        case .previousMuted: reason = "\(before) is muted, so there’s no fret to come from."
        case .previousByEar: reason = "\(before) was named by ear, so it isn’t on the neck."
        case .otherStrings:
            reason = notes.count > 1 ? "\(before) isn’t on the same strings."
                : "\(before) (\(placedBefore)) is on another string."
        case .sameFret:
            // Bent, it may be this note's bend coming down (ADR 0296 D2).
            if NeckJoin.canRelease(into: marked, of: labels) {
                return "\(before) (\(placedBefore)) is on the same fret. If its bend comes down here, choose Release."
            }
            reason = "\(before) (\(placedBefore)) is on the same fret."
        case .mixedDirections: reason = "The notes don’t all move the same way from \(before.lowercased())."
        }
        // On the first note of a pair, the join belongs to the second; say so rather than offer a start here.
        if marked + 1 < labels.count, NeckJoin.direction(into: marked + 1, of: labels) != nil {
            return reason + " A hammer-on or slide into note \(marked + 2) goes on that note."
        }
        return reason + (notes.count == 1 ? voice.startedElsewhere : voice.shapeStartedElsewhere)
    }

    /// One note of a chord moving, the rest held (0252 D1): *B string hammered on from fret 5; the others
    /// held.*
    private func heldText(_ note: FrettedNote, _ leadIn: LeadIn) -> String {
        let string = stringWords(note.string)
        switch (leadIn.join, leadIn.from) {
        case (.legato, .fret(let start)):
            let how = leadIn.direction(into: note.fret) == .downward ? "pulled off" : "hammered on"
            return "\(string) \(how) from fret \(start); the others held."
        case (.slide, .fret(let start)), (.release, .fret(let start)):
            return "\(string) slid from fret \(start); the others held."
        case (_, .below): return "\(string) slid in from below; the others held."
        case (_, .above): return "\(string) slid in from above; the others held."
        }
    }

    /// A string as the line says it: "B string".
    private func stringWords(_ string: Int) -> String {
        let names = TabLine.stringNames(openMidi: tuning.openMidi)
        return names.indices.contains(string)
            ? names[string].trimmingCharacters(in: .whitespaces) + " string" : "same string"
    }

    typealias Offer = (title: String, action: () -> Void)

    /// What to do from here: move a lead-in's start, and for one note of a chord hammered or pulled, say
    /// the whole chord moved (0252 D2); or say a join from the tap before was really heard as one note.
    private var intoOffers: [Offer] {
        guard case .fretted(let notes, _, let into) = labels[marked], !notes.isEmpty else { return [] }
        if let moving = notes.first(where: { $0.leadIn != nil }), let leadIn = moving.leadIn {
            let way = leadIn.join == .legato ? leadIn.direction(into: moving.fret) : nil
            // A shape moving as one moves again as one; one note moving picks its note again.
            let request = LeadInRequest(join: leadIn.join, direction: way, together: NeckJoin.movesAsOne(notes))
            var offers: [Offer] = [("Change where it started", { awaitingStart = request })]
            if NeckJoin.movedAsOne(notes) != nil {
                offers.append(("The whole chord moved?", {
                    apply(NeckEditing.moveTogether(labels: labels, cursor: cursor))
                }))
            }
            return offers
        }
        // A release heard as one note is the bend's own Release and one tap fewer: taking a note out (ADR
        // 0231), not a way into this one (ADR 0296 D1).
        guard let into, into != .release, NeckJoin.symbol(into: marked, of: labels) != nil else { return [] }
        let way = into == .legato ? NeckJoin.direction(into: marked, of: labels) : nil
        let title = notes.count == 1 ? voice.oneNoteOffer : "Moved into place as one?"
        return [(title, { awaitingStart = LeadInRequest(join: into, direction: way, together: true) })]
    }
}
