import SwiftUI

/// The progressive-disclosure **instrument filter** (ADR 0116 S4) — an "All" chip plus one per
/// instrument present, pinned above a practice library. The caller decides *whether* to show it
/// (only once the library holds more than one instrument's content, so the single-instrument player
/// never sees it) and passes the instruments it found; this view owns only the chips.
///
/// Lifted out of `ExerciseLibraryView` when the shared row actions pushed that type past the
/// length budget. Extracting the bar rather than the row half was the better split: the bar needs
/// nothing but its two inputs, where the rows read half the screen's private state.
struct InstrumentFilterBar: View {
    let instruments: [Instrument]
    /// The active filter, `nil` = "All".
    @Binding var selection: Instrument?

    var body: some View {
        HStack(spacing: 8) {
            chip(title: "All", isSelected: selection == nil) { selection = nil }
            ForEach(instruments) { instrument in
                chip(title: instrument.displayName, isSelected: selection == instrument) {
                    selection = instrument
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(PocketColor.background)
    }

    /// One filter chip — a pill that fills with the Practice tint when selected.
    private func chip(title: String, isSelected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Text(title)
                .font(.futura(.subheadline))
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? PocketColor.practice : PocketColor.surfaceStandard)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) exercises")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Instrument filter") {
    @Previewable @State var selection: Instrument?
    return InstrumentFilterBar(instruments: [.guitar, .bass], selection: $selection)
        .preferredColorScheme(.dark)
}
