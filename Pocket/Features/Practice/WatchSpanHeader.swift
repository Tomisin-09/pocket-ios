import SwiftUI

/// The top of *Watch it on the neck* for a section or the whole song (ADR 0289), drawn as a loop's header is
/// (`LoopModeIdentityHeader`): the section's name, the song it's from, and the loops whose pieces it plays.
struct WatchSpanHeader: View {
    let song: Song
    let name: String
    let run: SectionWatch.Run

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.futura(.title2)).bold()
                .foregroundStyle(PocketColor.textPrimary)
            Text("from \(song.title)\(song.artist.isEmpty ? "" : " · \(song.artist)")")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Text(Self.sources(run))
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    /// *Pieces from Verse riff, Fill and Outro lick*, and how many were left out for being placed in another
    /// tuning, so a piece that doesn't light isn't a mystery.
    nonisolated static func sources(_ run: SectionWatch.Run) -> String {
        let names = run.sources.map { $0.name.isEmpty ? "Untitled loop" : $0.name }
        var line = switch names.count {
        case 0: "No piece placed on the neck here"
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
