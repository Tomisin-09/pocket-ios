import SwiftUI

/// The top of *Watch it on the neck* for what was picked on the song map (ADR 0289, ADR 0308 D2, D3), drawn
/// as a loop's header is (`LoopModeIdentityHeader`): what was picked, its bars and when they start, the song
/// it's from, the loops whose pieces light, and what in the stretch isn't picked and stays dark.
struct WatchSpanHeader: View {
    let song: Song
    let watch: SongMapPicking.Watch
    let run: SectionWatch.Run

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(watch.title)
                .font(.futura(.title2)).bold()
                .foregroundStyle(PocketColor.textPrimary)
            Text(watch.sheetLine)
                .font(.futura(.subheadline, weight: .medium))
                .foregroundStyle(PocketColor.textPrimary)
            Text("from \(song.title)\(song.artist.isEmpty ? "" : " · \(song.artist)")")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Text(Self.sources(run))
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .padding(.top, 2)
            if let dark = watch.darkLine {
                Text(dark)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// The loops whose pieces light, and how many in another tuning don't.
    nonisolated static func sources(_ run: SectionWatch.Run) -> String {
        let names = run.sources.map { $0.name.isEmpty ? "Untitled loop" : $0.name }
        var line = switch names.count {
        case 0: "Nothing picked is placed on the neck"
        case 1: "The piece from \(names[0])"
        default: "Pieces from " + names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
        if run.otherTuning > 0 {
            line += run.otherTuning == 1 ? ". One in another tuning isn't shown"
                : ". \(run.otherTuning) in other tunings aren't shown"
        }
        return line
    }
}
