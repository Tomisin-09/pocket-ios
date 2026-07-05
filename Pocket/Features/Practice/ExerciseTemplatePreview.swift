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
