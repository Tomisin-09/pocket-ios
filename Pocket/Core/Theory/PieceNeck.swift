import Foundation

/// **What *Watch it on the neck* draws** (ADR 0254): a loop's piece laid on the neck as a map of the lick,
/// with the note being heard lit. Every spot the piece uses is in ink, and the one being heard turns solid
/// (D4). Only the recording sounds; nothing here plays an answer (D3).
///
/// Pure and SwiftUI-free (AGENTS.md), so what lights, what the line says and which loops get a door are
/// unit-tested.
enum PieceNeck {

    /// Every spot the piece's notes are placed on: the map of the lick. Where a lead-in starts and where a
    /// bend lands aren't spots; the glow and the marks show those, on the note being heard.
    static func spots(of labels: [PieceLabel?]) -> Set<NeckSpot> {
        labels.indices.reduce(into: []) { spots, index in spots.formUnion(heardSpots(index, of: labels)) }
    }

    /// The spots tap `index` is placed on: empty while nothing is heard, or for a tap that isn't on the
    /// neck (named by ear, or not named).
    static func heardSpots(_ index: Int?, of labels: [PieceLabel?]) -> Set<NeckSpot> {
        guard let index, labels.indices.contains(index) else { return [] }
        return Set((labels[index]?.frettedNotes ?? []).map { NeckSpot(string: $0.string, fret: $0.fret) })
    }

    /// The frets tap `index` covers: its notes, where a bend lands and where a lead-in starts, so following
    /// it keeps all of its glow in view. `nil` for a tap that isn't on the neck.
    static func frets(of index: Int, in labels: [PieceLabel?], maxFret: Int = PieceLabel.maxFret) -> ClosedRange<Int>? {
        guard labels.indices.contains(index) else { return nil }
        let frets = (labels[index]?.frettedNotes ?? []).flatMap { note -> [Int] in
            var covered = [note.fret, min(note.fret + note.bend, maxFret)]
            if case .fret(let start)? = note.leadIn?.from { covered.append(start) }
            return covered
        }
        guard let low = frets.min(), let high = frets.max() else { return nil }
        return low...high
    }

    /// The frets the whole lick covers, which the board opens centred on (D5). `nil` when nothing is on the
    /// neck.
    static func span(of labels: [PieceLabel?], maxFret: Int = PieceLabel.maxFret) -> ClosedRange<Int>? {
        let covered = labels.indices.compactMap { frets(of: $0, in: labels, maxFret: maxFret) }
        guard let low = covered.map(\.lowerBound).min(), let high = covered.map(\.upperBound).max() else {
            return nil
        }
        return low...high
    }

    /// The fret in the middle of a run, which the board centres on.
    static func centre(of frets: ClosedRange<Int>) -> Int { (frets.lowerBound + frets.upperBound) / 2 }

    /// **The gate** (D2), one rule for all five doors: something is placed on the neck, and the song's
    /// audio can play here. A piece named only by ear has nothing to light, and a loop whose audio can't
    /// play has nothing to follow.
    static func canWatch(hasFrettedLabels: Bool, audioResolves: Bool) -> Bool {
        hasFrettedLabels && audioResolves
    }

    // MARK: - In words

    /// The tap being heard, said the way a player would: the line over the chips, and the neck's VoiceOver
    /// value. *"G string, fret 5, hammered on from 3"*, *"B string, fret 6, bent a whole step"*, *"Gm7,
    /// frets 10 to 12"*, *"F, named by ear"*, *"Not named yet"*.
    static func words(for index: Int, of labels: [PieceLabel?], openMidi: [Int], spelling: NoteSpelling) -> String {
        guard labels.indices.contains(index), let label = labels[index] else { return "Not named yet" }
        let name = label.name(openMidi: openMidi, spelling: spelling)
        let notes = label.frettedNotes
        guard let note = notes.first else { return name.map { "\($0), named by ear" } ?? "Named by ear" }
        guard notes.count == 1 else {
            let frets = notes.map(\.fret)
            let low = frets.min() ?? note.fret, high = frets.max() ?? note.fret
            return "\(name ?? "\(notes.count) notes"), " + (low == high ? "fret \(low)" : "frets \(low) to \(high)")
        }
        let strings = TabLine.stringNames(openMidi: openMidi).map { $0.trimmingCharacters(in: .whitespaces) }
        let string = strings.indices.contains(note.string)
            ? "\(strings[note.string]) string" : "String \(note.string + 1)"
        var words = [string, note.fret == 0 ? "open" : "fret \(note.fret)"]
        switch HaloMotion.motions(into: index, of: labels).first {
        case .legato(let from, let to)?:
            words.append((to.fret > from.fret ? "hammered on from " : "pulled off from ") + fretWord(from.fret))
        case .slide(let from, _)?:
            words.append("slid from " + fretWord(from.fret))
        case .slideIn(_, let fromBelow)?:
            words.append(fromBelow ? "slid in from below" : "slid in from above")
        default:
            break
        }
        if note.bend > 0 { words.append("bent " + bendSizes[min(note.bend, bendSizes.count - 1)]) }
        if note.vibrato { words.append("with vibrato") }
        return words.joined(separator: ", ")
    }

    /// A bend's size, by semitones, as the By ear line says it.
    private static let bendSizes = ["", "a half step", "a whole step", "a step and a half"]

    private static func fretWord(_ fret: Int) -> String { fret == 0 ? "the open string" : "\(fret)" }
}

extension PieceNeck {
    /// The gate read off a live loop: **the one place the five doors ask**, so none of them can come to show
    /// for a loop another hides. Its audio resolves as ear training's does (`LoopModeAccess.Facts`).
    static func canWatch(_ loop: Loop) -> Bool { canWatch(loop.transcription, on: loop) }

    /// The same, for a caller already holding the loop's piece decoded: the Journal's piece rows.
    static func canWatch(_ piece: PieceTranscription?, on loop: Loop) -> Bool {
        canWatch(hasFrettedLabels: piece?.hasFrettedLabels ?? false,
                 audioResolves: LoopModeAccess.Facts(loop).audioResolves)
    }
}

/// **Following** (ADR 0254 D5): the board opens centred on the lick, then moves only when the note being
/// heard leaves the frets in view, so it doesn't swing on every note. Name the notes never scrolls under a
/// finger that's placing a note (0227 D2); nothing is placed here, so the board is free to move.
///
/// Worked in points, as the board is laid out: a cell 30 wide, one every 34 (`NeckGeometry`, which a test
/// holds these to).
enum NeckFollow {
    static let pitch: Double = 34
    static let cell: Double = 30

    /// The frets wholly in view on a board `width` points wide, scrolled to put `centre` in the middle as
    /// far as it can go: a scroll view stops at either end. `nil` when not even one fret fits.
    static func window(centre: Int, width: Double, maxFret: Int = PieceLabel.maxFret) -> ClosedRange<Int>? {
        let board = Double(maxFret + 1) * pitch - (pitch - cell)
        let left = min(max(Double(centre) * pitch + cell / 2 - width / 2, 0), max(board - width, 0))
        let first = Int((left / pitch).rounded(.up))
        let last = min(Int(((left + width - cell) / pitch).rounded(.down)), maxFret)
        return first <= last ? first...last : nil
    }

    /// The fret to centre on now, or `nil` to stay put: when the board isn't centred yet, it goes to the
    /// heard frets; once it is, it moves only when some of them are out of view.
    static func target(current: Int?, heard: ClosedRange<Int>, width: Double,
                       maxFret: Int = PieceLabel.maxFret) -> Int? {
        let wanted = PieceNeck.centre(of: heard)
        guard let current else { return wanted }
        guard let inView = window(centre: current, width: width, maxFret: maxFret) else { return nil }
        if inView.contains(heard.lowerBound) && inView.contains(heard.upperBound) { return nil }
        return wanted == current ? nil : wanted
    }
}
