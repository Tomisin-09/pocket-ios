import SwiftUI

// The screens behind song details' category rows (ADR 0258), each pushed inside the sheet's
// `NavigationStack`. **Every presentation hangs off the pushed screen's own `Form`**, never a row or a
// section inside it: a sheet raised from inside a form in a sheet fights the presentation that owns
// the screen, and loses (see `ReferencesSection.editing`). The Audio file screen is `SongAudioScreen`.

/// **Song details › Progress**: what the song's mastery is made of, the speed you can play it at, and
/// the counts. Mastery and the slowest loop stay side by side, as ADR 0250 D8 keeps them everywhere.
struct SongProgressScreen: View {
    let song: Song

    var body: some View {
        Form {
            Section {
                DetailLabeledContent(label: "Mastery") { masteryValue }
                // The speed beside the mastery (ADR 0250 D8), naming the loop that sets it.
                if let speed = song.speedReading {
                    DetailLabeledContent(label: "Slowest loop") {
                        Text("\(speed.loopName) · \(speed.percent)%")
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                            .lineLimit(1)
                    }
                }
            } footer: {
                // Was the Mastery row's ⓘ. This screen has the room to say it outright.
                Text(PracticeFieldInfo.songMastery)
            }
            Section("Practice stats") {
                statRow("Loops", song.loops.count)
                statRow("Markers", song.markers.count)
                statRow("Annotations", song.annotationCount)
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// What the average is made of (ADR 0250 D9): a raised loop drops out until it is rated again, so
    /// the dots alone can't say how many they stand for.
    @ViewBuilder private var masteryValue: some View {
        if let mastery = song.mastery {
            HStack(spacing: 8) {
                Text(MasteryRollup.ratedLabel(rated: song.ratedLoopCount, of: song.loops.count))
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                MasteryDots(filled: mastery, size: 8)
            }
        } else {
            Text("Unrated").foregroundStyle(PocketColor.textSecondary)
        }
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        DetailLabeledContent(label: label) {
            Text("\(value)").font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
        }
    }
}

/// **Song details › Collections**: the song's collections, read-only here as they always were on this
/// sheet. They are set in **Edit** (ADR 0033).
struct SongCollectionsScreen: View {
    let song: Song

    var body: some View {
        Form {
            Section {
                ForEach(song.collections, id: \.self) { tag in
                    Text(tag).foregroundStyle(PocketColor.textPrimary)
                }
            } footer: {
                Text("Change a song's collections in Edit.")
            }
        }
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A details row: a secondary label on the left, the supplied value view trailing. Mirrors the edit
/// sheet's row rhythm so details and edit feel like one place.
struct DetailLabeledContent<Value: View>: View {
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        LabeledContent {
            value()
        } label: {
            Text(label).foregroundStyle(PocketColor.textSecondary)
        }
    }
}
