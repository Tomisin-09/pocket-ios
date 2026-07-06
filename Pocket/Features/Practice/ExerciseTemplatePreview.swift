import SwiftUI

/// The stopped-state **template previews** on the exercise run screen (ADR 0065): a titled card that
/// shows what the exercise plays before you press Start — the strum lane (static, so you read the
/// down/up directions) or the fretboard drill (self-driving animation, so the shape walks the neck).
/// Split out of `ExerciseRunView` to keep that file lean.

/// A static strum-pattern card.
struct StrumPatternPreview: View {
    let pattern: StrumPattern

    var body: some View {
        templatePreviewCard("Strum pattern") {
            StrumLane(pattern: pattern, tint: PocketColor.practice)
        }
    }
}

/// An animated fretboard-drill card, captioned per the global note-label preference so it matches the
/// creation preview and the live board.
struct FretboardExercisePreview: View {
    let drill: FretboardDrill
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    var body: some View {
        templatePreviewCard("Fretboard") {
            FretboardDrillPreview(drill: drill, tint: PocketColor.practice, labelMode: labelMode)
        }
    }
}

/// A static chord-progression card: the sequence of chord diagrams the drill changes through, so you
/// read the whole progression before you press Start. The first chord shows active; the rest preview.
struct ChordProgressionPreview: View {
    let progression: ChordProgression

    var body: some View {
        templatePreviewCard("Chord progression") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(progression.changes.enumerated()), id: \.offset) { index, change in
                        ChordDiagramView(voicing: change.voicing, isActive: index == 0,
                                         tint: PocketColor.practice,
                                         degreeLabel: progression.numeral(for: change.voicing))
                            .frame(width: 78)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 120)
        }
    }
}

/// A titled, rounded card the two previews share.
@ViewBuilder
private func templatePreviewCard<Content: View>(_ title: String,
                                                @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 8) {
        Text(title)
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(PocketColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        content()
    }
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.surfaceSubtle))
}
