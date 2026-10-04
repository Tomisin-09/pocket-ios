import SwiftUI

/// **The neck *Watch it on the neck* draws** (ADR 0254 D4): read only. Every spot the piece uses is in ink,
/// as a map of the lick, and the tap being heard turns solid, with its marks over it and its glow under it
/// moving the way it was played. Stopped, the map stays.
///
/// The board, the dots, the marks and the glow are Name the notes' own (`FretNeckBoard`, `NeckSpotDot`,
/// `NeckMarksLayer`, `HeardGlows`), so a lick reads here as it was placed there. Nothing on it is tapped,
/// and nothing sounds from it (D3).
struct PieceNeckView: View {
    let labels: [PieceLabel?]
    /// The open strings the piece was placed against, highest-first.
    let openMidi: [Int]
    let spelling: NoteSpelling
    /// Every spot the piece uses (`PieceNeck.spots`), worked out once by the sheet.
    let lick: Set<NeckSpot>
    /// The tap being heard, or `nil` while stopped.
    let heard: Int?
    /// The fret the board centres on (D5): the lick's middle, then wherever following takes it.
    let centre: Int?

    var body: some View {
        let lit = PieceNeck.heardSpots(heard, of: labels)
        FretNeckBoard(stringNames: stringNames, maxFret: PieceLabel.maxFret, scrollTarget: centre,
                      headroom: Self.headroom) { string, fret in
            NeckSpotDot(name: name(string: string, fret: fret), tier: tier(string: string, fret: fret, lit: lit))
        } marks: {
            // The marks of the tap being heard only, as Name the notes draws the note being named's.
            if let heard, labels.indices.contains(heard) {
                NeckMarksLayer(notes: labels[heard]?.frettedNotes ?? [],
                               previous: heard > 0 ? labels[heard - 1]?.frettedNotes ?? [] : [],
                               join: NeckJoin.symbol(into: heard, of: labels),
                               stringCount: openMidi.count, maxFret: PieceLabel.maxFret, headroom: Self.headroom)
            }
        } beneath: {
            HeardGlows(motions: heard.map { HaloMotion.motions(into: $0, of: labels) } ?? [], token: heard,
                       headroom: Self.headroom)
        }
    }

    /// Room above the top string for a bend's arrow and a vibrato's wave, as on Name the notes' neck.
    private static let headroom: CGFloat = 16

    /// The strings' names down the left edge, thinnest first, as the tab names them.
    private var stringNames: [String] {
        TabLine.stringNames(openMidi: openMidi).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// The note a spot sounds, spelled for the key (ADR 0123), as the editor names it.
    private func name(string: Int, fret: Int) -> String {
        spelling.name(pitchClass: openMidi.indices.contains(string) ? openMidi[string] + fret : fret)
    }

    /// Solid for the tap being heard, ink for the rest of the lick, faint for a spot the piece never uses.
    private func tier(string: Int, fret: Int, lit: Set<NeckSpot>) -> NeckNeighbours.Tier? {
        let spot = NeckSpot(string: string, fret: fret)
        if lit.contains(spot) { return .current }
        return lick.contains(spot) ? .other : nil
    }
}
