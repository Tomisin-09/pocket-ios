import SwiftUI

/// The small text and link styles Name the notes and the neck editor share (ADR 0235 D9), so the two
/// can't drift apart.
@MainActor
enum NamingControls {
    static func hint(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.futura(.caption, weight: .semibold))
            .tint(PocketColor.practice)
            .buttonStyle(.borderless)
            .padding(.vertical, 2)
    }

    static func pickerLabel(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
    }
}

/// A row of small segments where each can be off on its own, which `Picker(.segmented)` can't do: *Into it*
/// offers only the ways in that fit.
struct MarkSegments: View {
    struct Option {
        let title: String
        let isOn: Bool
        let isEnabled: Bool
        let action: () -> Void
    }

    let options: [Option]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button(action: option.action) {
                    Text(option.title)
                        .font(.futura(.footnote, weight: option.isOn ? .bold : nil))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .frame(minWidth: 38, minHeight: 28)
                        .foregroundStyle(PocketColor.textPrimary)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(option.isOn ? PocketColor.surfaceBorder : .clear))
                }
                .buttonStyle(.plain)
                .disabled(!option.isEnabled)
                .opacity(option.isEnabled ? 1 : 0.35)
                .accessibilityAddTraits(option.isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PocketColor.surfaceSubtle))
        .fixedSize()
    }
}
