import Foundation

/// **Watch the section** (ADR 0289): several loops' pieces merged into one run of taps in song time, so
/// *Watch it on the neck* can play straight through a section, or the whole song, lighting each note as
/// it's heard.
///
/// - **Only pieces placed on the neck take part.** A part named by ear lights nothing, so it mustn't hide
///   a riff under it.
/// - **Where two overlap, the one that starts later shows**, for as long as it lasts, its repeats included
///   (ADR 0232 D14). The earlier one's taps under it are left out, and it comes back when the later one
///   ends.
/// - **A tap is heard until the next tap or the end of its loop**, so a stretch no piece covers is a gap,
///   with nothing lit.
/// - **One tuning**, the first piece's. A piece placed in another is left out and counted, because its
///   frets would be drawn on the wrong strings.
/// - **A join is kept only after the tap it was named against.** Across two loops, or into a repeat's first
///   note, it's dropped, as a join that no longer fits always is (ADR 0227 D5).
///
/// Pure and SwiftUI-free (AGENTS.md), with plain values in, so the merge is unit-tested.
enum SectionWatch {

    /// One loop, as the merge reads it.
    struct Source: Equatable, Sendable {
        let id: UUID
        let name: String
        /// Song seconds.
        let start: TimeInterval
        let end: TimeInterval
        /// Where its repeats end (ADR 0232 D14), or `end` when it doesn't repeat.
        let reach: TimeInterval
        let piece: PieceTranscription
        var isChords = false
    }

    /// One tap of the run.
    struct Tap: Equatable, Sendable {
        /// Song seconds.
        let seconds: TimeInterval
        /// When it stops being heard: the next tap, the end of its loop, or a later loop taking over.
        let until: TimeInterval
        let label: PieceLabel?
        /// The loop it came from, an index into `Run.sources`.
        let source: Int
    }

    /// The taps to play, in order, and what they were placed against.
    struct Run: Equatable, Sendable {
        let taps: [Tap]
        /// The loops that take part, in the order they start.
        let sources: [Source]
        let openMidi: [Int]?
        let tuningLabel: String?
        /// Pieces left out because they were placed in another tuning.
        var otherTuning = 0

        var labels: [PieceLabel?] { taps.map(\.label) }

        /// The tap being heard at `time`, in song seconds, or `nil` before the first and in a gap.
        func heard(at time: TimeInterval) -> Int? {
            guard let index = taps.lastIndex(where: { $0.seconds <= time }), time < taps[index].until else {
                return nil
            }
            return index
        }

        /// The loop whose taps start at `index`, where the run moves on to another loop; `nil` inside one.
        func source(startingAt index: Int) -> Source? {
            guard taps.indices.contains(index) else { return nil }
            if index > 0, taps[index - 1].source == taps[index].source { return nil }
            return sources[taps[index].source]
        }
    }

    /// One loop's piece, every tap, each heard until the next: what *Watch it on the neck* plays for a loop
    /// (ADR 0254), the way it always has.
    static func run(of piece: PieceTranscription?, id: UUID, name: String) -> Run {
        let taps = piece?.taps ?? []
        let source = Source(id: id, name: name, start: taps.first?.seconds ?? 0, end: .infinity, reach: .infinity,
                            piece: piece ?? PieceTranscription(taps: []))
        return Run(taps: taps.indices.map { index in
            Tap(seconds: taps[index].seconds,
                until: index + 1 < taps.count ? taps[index + 1].seconds : .infinity,
                label: taps[index].label, source: 0)
        }, sources: [source], openMidi: piece?.openMidi, tuningLabel: piece?.tuningLabel)
    }

    /// The pieces of `sources` that sound between `from` and `to`, merged into one run (see the type).
    static func merge(_ sources: [Source], from: TimeInterval, to: TimeInterval) -> Run {
        let onTheNeck = sources.filter { $0.piece.hasFrettedLabels && $0.start < to && $0.reach > from }
            .sorted(by: startsFirst)
        let tuning = onTheNeck.first?.piece.openMidi
        let kept = onTheNeck.filter { $0.piece.openMidi == tuning }
        let entries = kept.indices.flatMap { Self.entries(of: kept, at: $0, from: from, to: to) }
            .sorted { ($0.seconds, $0.source, $0.pass, $0.index) < ($1.seconds, $1.source, $1.pass, $1.index) }
        let taps = entries.indices.map { position -> Tap in
            let entry = entries[position]
            var until = min(kept[entry.source].reach, to)
            if position + 1 < entries.count { until = min(until, entries[position + 1].seconds) }
            // A loop starting later takes over at its start, whether or not it has a tap there.
            if let later = kept.first(where: { $0.start > entry.seconds && $0.start < until }) { until = later.start }
            let previous = position > 0 ? entries[position - 1] : nil
            let named = previous.map {
                $0.source == entry.source && $0.pass == entry.pass && $0.index == entry.index - 1
            } ?? false
            return Tap(seconds: entry.seconds, until: until, label: named ? entry.label : withoutJoin(entry.label),
                       source: entry.source)
        }
        return Run(taps: taps, sources: kept, openMidi: tuning, tuningLabel: kept.first?.piece.tuningLabel,
                   otherTuning: onTheNeck.count - kept.count)
    }

    /// The order loops start in. On the same moment, chords before notes, so a riff counts as the later
    /// one and shows over the chords it's played across.
    private static func startsFirst(_ lhs: Source, _ rhs: Source) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.isChords != rhs.isChords { return lhs.isChords }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private struct Entry {
        let seconds: TimeInterval
        let label: PieceLabel?
        let source: Int
        /// Which time round: 0 for the pass that was counted, then one per repeat.
        let pass: Int
        /// The tap's place in its own piece.
        let index: Int
    }

    /// A loop's taps on every pass, kept only where this loop is the one showing.
    private static func entries(of kept: [Source], at index: Int, from: TimeInterval, to: TimeInterval) -> [Entry] {
        let source = kept[index]
        let length = source.end - source.start
        guard length > 0 else { return [] }
        let passes = max(1, Int(((source.reach - source.start) / length).rounded(.up)))
        // The latest-starting loop that covers a moment is the one showing then.
        let showing = { (time: TimeInterval) in
            kept.indices.last { kept[$0].start <= time && time < kept[$0].reach } == index
        }
        return (0..<passes).flatMap { pass in
            source.piece.taps.enumerated().compactMap { tapIndex, tap -> Entry? in
                guard tap.seconds >= source.start - tolerance, tap.seconds < source.end else { return nil }
                let time = max(tap.seconds, source.start) + Double(pass) * length
                guard time < source.reach, time >= from, time < to, showing(time) else { return nil }
                return Entry(seconds: time, label: tap.label, source: index, pass: pass, index: tapIndex)
            }
        }
    }

    /// A tap counted a hair before its loop's start is still the loop's first note.
    private static let tolerance: TimeInterval = 0.001

    private static func withoutJoin(_ label: PieceLabel?) -> PieceLabel? {
        guard case .fretted(let notes, let muted, _)? = label else { return label }
        return .fretted(notes, muted: muted, into: nil)
    }
}

extension SectionWatch {
    /// The loops on a song's map with a piece saved, as the merge reads them.
    static func sources(of map: SongMap) -> [Source] {
        map.pieces.values.compactMap { piece in
            guard case .piece(let counted) = piece.content else { return nil }
            return Source(id: piece.uid, name: piece.name, start: piece.start, end: piece.end, reach: piece.reach,
                          piece: counted, isChords: piece.layer == .chords)
        }
    }

    /// Whether a stretch has anything to light: at least one tap on the neck between `from` and `to`. The
    /// door's half of the gate (ADR 0254 D2); the song's audio is the other.
    static func hasSomethingToWatch(_ sources: [Source], from: TimeInterval, to: TimeInterval) -> Bool {
        merge(sources, from: from, to: to).labels.contains { $0?.isOnTheNeck ?? false }
    }
}
