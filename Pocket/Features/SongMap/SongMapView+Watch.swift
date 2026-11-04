import SwiftUI

/// *Watch it on the neck* from the song map for a stretch of the song (ADR 0289): a section, from its
/// heading's hold menu, or the whole song, from the toolbar. Each door is behind the same gate as a loop's
/// (ADR 0254 D2): something in the stretch is placed on the neck, and the song's audio plays here.
extension SongMapView {

    /// A stretch of the song to watch on the neck (ADR 0289).
    struct WatchSpan: Identifiable {
        let name: String
        let start: TimeInterval
        let end: TimeInterval
        let isWholeSong: Bool
        var id: String { "\(start)-\(end)-\(isWholeSong)" }
    }

    /// *Watch it on the neck* for a section, or the whole song (ADR 0289), behind the same gate and with the
    /// song player paused first.
    func watch(_ span: WatchSpan) {
        made = nil
        onOpenNestedAudio()
        watchingSpan = span
    }

    /// A section's door, or `nil` when it has nothing to light or its audio can't play here (0254 D2).
    func watchDoor(_ section: SongMap.Section, sources: [SectionWatch.Source]) -> (() -> Void)? {
        let name: String
        switch section.heading {
        case .none: return nil
        case .start: name = "Start"
        case .marker(_, let label): name = label.isEmpty ? "Section" : label
        }
        guard PieceNeck.canWatch(sources, from: section.start, to: section.end, on: song) else { return nil }
        return { watch(WatchSpan(name: name, start: section.start, end: section.end, isWholeSong: false)) }
    }

    /// The whole song's door (ADR 0289), or `nil` behind the gate.
    func watchSongDoor(_ map: SongMap, sources: [SectionWatch.Source]) -> (() -> Void)? {
        let end = map.sections.last?.end ?? song.duration
        guard PieceNeck.canWatch(sources, from: 0, to: end, on: song) else { return nil }
        return { watch(WatchSpan(name: "The whole song", start: 0, end: end, isWholeSong: true)) }
    }
}
