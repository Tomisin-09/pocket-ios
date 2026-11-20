import SwiftUI

/// *Watch it on the neck* from the song map for what's picked (ADR 0289, ADR 0308): a section, straight from
/// its name's hold menu, or the pieces and sections picked, from the picking bar's **Watch**. Each door is
/// behind the same gate as a loop's (ADR 0254 D2): something picked is placed on the neck, and the song's
/// audio plays here. The toolbar's eye is gone (0308 D1): the whole song is every section picked.
extension SongMapView {

    /// The picks being watched, for `.sheet(item:)`: a fresh id each time, so watching the same picks again
    /// opens the sheet again.
    struct WatchSpan: Identifiable {
        let id = UUID()
        let watch: SongMapPicking.Watch
    }

    /// Open the sheet for `watch`, with the song player paused first.
    func watch(_ watch: SongMapPicking.Watch) {
        made = nil
        onOpenNestedAudio()
        watchingSpan = WatchSpan(watch: watch)
    }

    /// Watch for these picks, or `nil` with nothing picked, nothing picked placed on the neck, or the song's
    /// audio not playing here (0254 D2).
    func watchDoor(_ watch: SongMapPicking.Watch?, sources: [SectionWatch.Source]) -> (() -> Void)? {
        guard let watch,
              PieceNeck.canWatch(sources.filter { watch.lit.contains($0.id) }, from: watch.start, to: watch.end,
                                 on: song) else { return nil }
        return { self.watch(watch) }
    }

    /// A section name's *Watch it on the neck* (D1): every piece in it, straight to the sheet.
    func watchDoor(_ section: SongMap.Section, in map: SongMap, sources: [SectionWatch.Source]) -> (() -> Void)? {
        watchDoor(SongMapPicking.watch(SongMapPicking.pieces(in: section, of: map), in: map), sources: sources)
    }
}
