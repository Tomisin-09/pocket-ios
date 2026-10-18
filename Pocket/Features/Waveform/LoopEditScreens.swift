import SwiftUI

// Two of the screens behind Edit loop's rows (ADR 0258), pushed inside the sheet's `NavigationStack`;
// Works on & tags is `LoopSkillsScreen`, References the shared `ReferencesScreen`. The sheet edits a
// draft — Cancel discards, Done keeps — so these take bindings into that draft, never the loop, and
// what they change waits for Done like every other field.

/// **Edit loop › Range**: where the loop sits, the way to move it on the waveform, and how it got there
/// (ADR 0201), still directly under the range it explains. Both actions leave the sheet for the
/// waveform, so they arrive as closures that close the sheet first: this screen's own `dismiss` would
/// only pop it.
struct LoopRangeScreen: View {
    let loop: Loop
    let onAdjustRange: () -> Void
    let onWiden: (TimeInterval, TimeInterval) -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent("Loop") {
                    Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))").font(.pocketMono(.body))
                }
                Button(action: onAdjustRange) {
                    Label("Adjust range on waveform", systemImage: "slider.horizontal.below.rectangle")
                }
            }
            LoopSpanSection(loop: loop, onWiden: onWiden)
        }
        .navigationTitle("Range")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// **Edit loop › Colour** (ADR 0031): the swatches, and the warning when a custom colour won't read on
/// the dark background.
struct LoopColourScreen: View {
    let autoColor: Color
    @Binding var choice: LoopColorChoice

    var body: some View {
        Form {
            Section {
                LoopColorPicker(autoColor: autoColor, choice: $choice)
            } footer: {
                if lowContrast {
                    Label("Low contrast on the dark background", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Colour")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A custom colour too close to the background to read (`ColorContrast`).
    private var lowContrast: Bool {
        guard case .custom(let hex) = choice, let color = HexColor.color(from: hex) else { return false }
        return !ColorContrast.isLegible(foreground: HexColor.components(of: color),
                                        background: HexColor.components(of: PocketColor.background))
    }
}

extension LoopColorChoice {
    /// The colour this choice draws, for the **Colour** row's swatch: Auto's is the loop's derived one.
    func color(auto autoColor: Color) -> Color {
        switch self {
        case .auto: autoColor
        case .palette(let index):
            PocketColor.loopPalette.indices.contains(index) ? PocketColor.loopPalette[index] : autoColor
        case .custom(let hex): HexColor.color(from: hex) ?? autoColor
        }
    }

    /// What the swatch is called aloud — the picker's own labels, so the row and the picker agree.
    var accessibilityName: String {
        switch self {
        case .auto: "Automatic colour"
        case .palette(let index): "Colour \(index + 1)"
        case .custom: "Custom colour"
        }
    }
}
