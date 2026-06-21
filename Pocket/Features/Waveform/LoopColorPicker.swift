import SwiftUI

/// What a loop's colour is set to (ADR 0031). Drives the edit-sheet picker and maps to
/// the loop's `colorIndex` / `customColorHex` on save.
enum LoopColorChoice: Equatable {
    case auto                 // derive from start-order
    case palette(Int)         // a fixed PocketColor.loopPalette slot
    case custom(String)       // a free colour, "#RRGGBB"
}

/// Loop colour chooser for the edit sheet (ADR 0031): an **Auto** swatch (the derived
/// start-order hue, marked "A"), the fixed `PocketColor.loopPalette`, and a trailing
/// **custom** gateway (rainbow-ringed system colour wheel) for any other colour. The
/// selected swatch is ringed.
struct LoopColorPicker: View {
    /// The loop's derived (start-order) colour — shown on the Auto swatch.
    let autoColor: Color
    @Binding var choice: LoopColorChoice

    var body: some View {
        HStack(spacing: 0) {
            Swatch(color: autoColor, isSelected: choice == .auto,
                   label: "Automatic colour", badge: "A") { choice = .auto }
            ForEach(PocketColor.loopPalette.indices, id: \.self) { index in
                Spacer(minLength: 6)
                Swatch(color: PocketColor.loopPalette[index], isSelected: choice == .palette(index),
                       label: "Colour \(index + 1)") { choice = .palette(index) }
            }
            Spacer(minLength: 6)
            customGateway
        }
        .padding(.vertical, 4)
    }

    /// The system colour wheel, fronted by a rainbow ring so it reads as "more colours".
    /// Its swatch shows the current custom colour (or the auto colour as a starting
    /// point); a white ring marks it as the active choice.
    private var customGateway: some View {
        let binding = Binding<Color>(
            get: {
                if case .custom(let hex) = choice, let color = HexColor.color(from: hex) { return color }
                return autoColor
            },
            set: { choice = .custom(HexColor.hex(from: $0)) }
        )
        let isSelected = { if case .custom = choice { return true } else { return false } }()
        return ColorPicker("", selection: binding, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 30, height: 30)
            .background {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                        center: .center),
                        lineWidth: 3)
                    .frame(width: 38, height: 38)
            }
            .overlay {
                if isSelected {
                    Circle().strokeBorder(PocketColor.textPrimary, lineWidth: 3).frame(width: 38, height: 38)
                }
            }
            .accessibilityLabel("Custom colour")
    }
}

/// One colour circle in the picker. Ringed when selected; an optional `badge` letter
/// (used for "Auto") sits on the fill.
private struct Swatch: View {
    let color: Color
    let isSelected: Bool
    let label: String
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay {
                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PocketColor.background)
                    }
                }
                .overlay {
                    Circle().strokeBorder(PocketColor.textPrimary, lineWidth: isSelected ? 3 : 0)
                }
                .padding(4)            // enlarge the tap target past the 30pt circle
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
