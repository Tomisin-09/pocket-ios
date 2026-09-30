import SwiftUI

/// The song map's actions (ADR 0232): sections and repeats (D7, D8, D14, D15), and what the map makes and
/// takes back (D9, D16, D17). Apart from `SongMapView` only to keep each file within its length budget.
extension SongMapView {

    // MARK: - Sections and repeats

    /// *as Verse 1*: to the section it names, on whichever view is showing.
    func showSection(_ start: TimeInterval) {
        scrollTarget = .section(start)
    }

    /// How far a piece repeats (D14, D15), from its hold menu.
    func setRepeats(_ uid: UUID, _ reach: SongMap.RepeatsTo?) {
        made = nil
        SongMapWriter.setRepeats(uid, reach, in: song)
    }

    /// Offered once per song (D7): it has markers, none of them starts a section, and the offer hasn't
    /// been answered.
    func offersSections(_ input: SongMapInput) -> Bool {
        !sectionOfferAnswered && SectionWords.shouldOffer(input.markers, duration: input.duration)
            && !AppSettings.sectionOfferMade(for: song.sourceID)
    }

    /// *Not now*, or the markers used: either way it's been answered, and isn't offered again.
    func answerSectionOffer() {
        AppSettings.recordSectionOffer(for: song.sourceID)
        withAnimation { sectionOfferAnswered = true }
    }

    // MARK: - Making and copying

    /// A gap tapped: offer *Make a piece here* (D9), and a copy of any piece counted on its lane (D16).
    func offerPiece(_ gap: SongMap.Gap) {
        made = nil
        makingPiece = gap
    }

    /// *Make a piece here* (D9). It's drawn heavier for a moment, so you can see where it went, and can
    /// be taken back (D17).
    func make(_ gap: SongMap.Gap) {
        guard let loop = SongMapWriter.make(gap, in: song, context: modelContext) else { return }
        highlighted = [loop.uid]
        showMade([loop], message: "Made \(loop.name)")
    }

    /// *Copy to…* from a piece's hold menu (D16).
    func startCopy(_ uid: UUID) {
        made = nil
        copying = CopySource(uid: uid)
    }

    /// The copies made, drawn heavier for a moment, and taken back together by one Undo (D17).
    func copy(_ uid: UUID, into targets: [SongMapCopy.Target], grid: SongMapInput.Grid?) {
        guard let source = song.loops.first(where: { $0.uid == uid }) else { return }
        let loops = SongMapWriter.copy(source, into: targets, grid: grid, in: song, context: modelContext)
        guard let first = loops.first else { return }
        highlighted = Set(loops.map(\.uid))
        showMade(loops, message: loops.count == 1 ? "Made \(first.name)"
                    : "Made \(loops.count) copies of \(source.name)")
    }

    func showMade(_ loops: [Loop], message: String) {
        withAnimation(.easeOut(duration: 0.2)) { made = Made(message: message, uids: Set(loops.map(\.uid))) }
    }

    /// Undo for what the map just made (D17): those loops, and nothing else. The map never deletes a
    /// loop made on the waveform.
    @ViewBuilder var undoBar: some View {
        if let made {
            UndoToastView(message: made.message, hint: "Removes what was just made") {
                SongMapWriter.takeBack(made.uids, from: song, context: modelContext)
                highlighted = []
                withAnimation(.easeOut(duration: 0.2)) { self.made = nil }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// *from bar 9 to bar 12*, or *from 0:32 to 0:48* in seconds scale.
    func span(of gap: SongMap.Gap, in map: SongMap) -> String {
        if let grid = map.grid, let bars = SongMapLayout.barRange(from: gap.start, to: gap.end, in: grid) {
            return bars.count == 1 ? "in bar \(bars.lowerBound)"
                : "from bar \(bars.lowerBound) to bar \(bars.upperBound)"
        }
        return "from \(timecode(gap.start)) to \(timecode(gap.end))"
    }

    // MARK: - Words

    /// What the board or the tab is for, under the song's facts.
    func guidance(_ map: SongMap, tab: SongTab?) -> String {
        guard let tab else {
            return map.pieces.isEmpty
                ? "No loops yet. Tap + in a lane to make one there. Every loop on this song appears here, "
                    + "where it plays."
                : "Each loop sits where it plays. Tap one for its tab, hold it to work on it, or tap + to "
                    + "make one in a gap."
        }
        return tab.isEmpty
            ? "Nothing counted yet. Count a loop in Train your ear and it's drawn here, where it plays."
            : "Drawn from your pieces, where they play. Tap a row to see the pieces that drew it."
    }

    /// The artist, and what the rows are measured in.
    func facts(_ map: SongMap) -> String {
        var parts = [song.artist].filter { !$0.isEmpty }
        switch map.scale {
        case .bars:
            if let bpm = song.bpm { parts.append("\(bpm) BPM") }
            parts.append("\(song.beatsPerBar)/\(song.noteValue)")
        case .seconds:
            parts.append(SongMapInput.hasGrid(song) ? "In seconds, bars hidden" : "In seconds, no tempo set")
        }
        return parts.joined(separator: " · ")
    }

    /// *Notes · Bars 9–11*, or *Notes · 0:23–0:45* in seconds scale.
    func place(of piece: SongMap.Piece, in map: SongMap) -> String {
        let span: String
        if let bars = map.bars(of: piece) {
            span = bars.count == 1 ? "Bar \(bars.lowerBound)" : "Bars \(bars.lowerBound)–\(bars.upperBound)"
        } else {
            span = "\(timecode(piece.start))–\(timecode(piece.end))"
        }
        return "\(SongMapStyle.name(piece.layer)) · \(span)"
    }
}
