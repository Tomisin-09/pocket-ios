import SwiftUI

// MARK: - The tempo sheet in the player's own look (ADR 0284 D7)

// The sheet is dressed as the player it opens from rather than as a stock form: the app's
// background under `surfaceStandard` cards, Futura on the words, teal (`waveformAccent`) on what you
// press and green (`active`) on what's chosen. That's the speed bar's split, whose presets fill green
// and whose metronome button is teal. The background is the metronome settings sheet's.
extension View {
    func tempoSheetStyle() -> some View {
        font(.futura(.body))
            .tint(PocketColor.waveformAccent)
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
    }

    /// A section of the tempo sheet, as a card.
    func tempoSheetCard() -> some View {
        listRowBackground(PocketColor.surfaceStandard)
    }

    /// A row drawn on its own, with nothing of the form's behind it.
    func tempoSheetBare() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }
}

/// A section header in the tempo sheet, in sentence case on every iOS.
struct TempoSheetHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.futura(.subheadline, weight: .bold))
            .foregroundStyle(PocketColor.textSecondary)
            .textCase(nil)
    }
}

/// A section footer in the tempo sheet.
struct TempoSheetFooter: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
    }
}

/// A choice drawn as the speed bar's preset pills: the chosen one filled in `active`, the others in
/// `surfaceStandard`. Both states are the same size, so nothing moves under the finger.
struct TempoPills<Value: Hashable>: View {
    let options: [PickerItem<Value>]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                    haptic(.light)
                } label: {
                    Text(option.title)
                        .font(.futura(.subheadline, weight: .medium))
                        .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(isSelected ? PocketColor.active : PocketColor.surfaceStandard))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// A one-shot action as a small capsule (Half, Double, Reset): teal on `surfaceStandard`, greyed
/// when it can't be used.
struct TempoActionPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration)
    }

    private struct Pill: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.futura(.subheadline, weight: .medium))
                .foregroundStyle(isEnabled ? PocketColor.waveformAccent : PocketColor.textSecondary.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(PocketColor.surfaceStandard))
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }
}

/// The sheet's one strong action at a time (Use, Use 89 BPM): filled teal, greyed when it can't
/// be used.
struct TempoPrimaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration)
    }

    private struct Pill: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.futura(.body, weight: .bold))
                .foregroundStyle(isEnabled ? PocketColor.background : PocketColor.textSecondary.opacity(0.6))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(isEnabled ? PocketColor.waveformAccent : PocketColor.surfaceStandard))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

/// A row of the other ways to set a tempo (ADR 0284 D5): a teal glyph, what it is, and when it's the
/// one to use.
struct TempoWayLabel: View {
    let title: String
    let when: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 19))
                .foregroundStyle(PocketColor.waveformAccent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(when)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
