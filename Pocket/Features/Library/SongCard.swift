import SwiftData
import SwiftUI

/// A rich, text-forward library card (ADR 0035): a leading colour accent (in place of
/// artwork), the title, a metadata line (key · BPM · loops · markers), collection chips,
/// and mastery dots. The colour accent is derived from the (derived) mastery tier, so the
/// list reads as practice state at a glance without any cover art (ADR 0036).
struct SongCard: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Self.accentColor(for: song.mastery))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)

                if !song.artist.isEmpty {
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textSecondary)
                        .lineLimit(1)
                }

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                        .lineLimit(1)
                }

                if !song.collections.isEmpty {
                    collectionChips
                }
            }

            Spacer(minLength: 8)

            if let mastery = song.mastery, mastery > 0 {
                MasteryDots(filled: mastery)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    /// "C · 120 BPM · 4 loops · 2 markers" — known facts only, in that order.
    private var metadata: String {
        var parts: [String] = []
        if !song.key.isEmpty { parts.append(song.key) }
        if let bpm = song.bpm { parts.append("\(bpm) BPM") }
        let loops = song.loops.count
        if loops > 0 { parts.append("\(loops) loop\(loops == 1 ? "" : "s")") }
        let markers = song.markers.count
        if markers > 0 { parts.append("\(markers) marker\(markers == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    private var collectionChips: some View {
        HStack(spacing: 6) {
            ForEach(song.collections, id: \.self) { collection in
                Text(collection)
                    .font(.pocketMono(.caption2))
                    .lineLimit(1)
                    .foregroundStyle(PocketColor.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
        .lineLimit(1)
    }

    /// Mastery tier → accent colour (mirrors `LibrarySectioning.masteryTier`): unrated
    /// (no loops) neutral, needs work warm, solid blue, polished green. Colour is a UI
    /// concern, so the mapping lives here rather than in the pure module (ADR 0036).
    static func accentColor(for mastery: Int?) -> Color {
        guard let mastery else { return PocketColor.barDefault }
        switch mastery {
        case ...1: return PocketColor.marker
        case 2...3: return PocketColor.waveformBar
        default: return PocketColor.active
        }
    }
}

/// Mastery as up to five small dots (0–5), amber when filled.
struct MasteryDots: View {
    let filled: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < filled ? PocketColor.marker : PocketColor.barDefault)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel("Mastery \(filled) of 5")
    }
}

#Preview("Song card") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let song = Song.sample()
    song.key = "Am"
    song.bpm = 92
    song.collections = ["blues", "needs-work"]
    song.loops.forEach { $0.mastery = 3 }   // derived song mastery → 3 (ADR 0036)
    container.mainContext.insert(song)
    return List { SongCard(song: song) }
        .listStyle(.plain)
        .preferredColorScheme(.dark)
}
