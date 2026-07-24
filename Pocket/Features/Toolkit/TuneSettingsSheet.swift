import SwiftUI

/// The **Tune Settings** sheet (ADR 0115 Slice 4) — a Pocket-native, indigo sheet (not a system form)
/// carrying every tuner preference: instrument (Guitar / Bass), mode (Guided / Chromatic), the tuning
/// picker, reference-pitch calibration, and the success-chime toggle. Every control persists via
/// `@AppStorage` on `AppSettings.Key`, so `TunerView` reads the same keys live — a change here takes
/// effect on the tuner without any wiring between the two.
///
/// Switching instrument resets the tuning to that instrument's Standard, so a bass tuning never leaks
/// onto guitar. All controls are free — a tuner is a reference utility, not the author-vs-run Pro lever
/// (ADR 0112) — and nothing here grades the player (ADR 0070).
struct TuneSettingsSheet: View {
    @AppStorage(AppSettings.Key.tunerInstrument) private var instrumentRaw = Instrument.default.rawValue
    @AppStorage(AppSettings.Key.tunerMode) private var modeRaw = TunerMode.default.rawValue
    @AppStorage(AppSettings.Key.tunerTuning) private var tuningName = Instrument.default.standardTuning.name
    @AppStorage(AppSettings.Key.tunerReferenceA) private var referenceA = AppSettings.tunerReferenceDefault
    @AppStorage(AppSettings.Key.tunerChimeEnabled) private var chimeEnabled = true
    @Environment(\.dismiss) private var dismiss

    private var instrument: Instrument { Instrument(rawValue: instrumentRaw) ?? .default }
    private var mode: TunerMode { TunerMode(rawValue: modeRaw) ?? .default }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    instrumentCard
                    modeCard
                    if mode == .guided { tuningCard }
                    referenceCard
                    chimeCard
                }
                .padding(20)
                .readableWidth()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Tune Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.toolkit)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.toolkit)
                }
            }
            // Instrument switch resets to that instrument's Standard (ADR 0115) so a guitar-only
            // tuning can't linger on bass.
            .onChange(of: instrumentRaw) { _, _ in
                tuningName = instrument.standardTuning.name
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Instrument

    private var instrumentCard: some View {
        card(title: "Instrument") {
            RawSegmented(
                options: Instrument.allCases.map { ($0.rawValue, $0.displayName) },
                selection: $instrumentRaw)
        }
    }

    // MARK: - Mode

    private var modeCard: some View {
        card(title: "Mode") {
            VStack(alignment: .leading, spacing: 10) {
                RawSegmented(
                    options: TunerMode.allCases.map { ($0.rawValue, $0.displayName) },
                    selection: $modeRaw)
                Text(mode.blurb)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    // MARK: - Tuning (guided only)

    private var tuningCard: some View {
        card(title: "Tuning") {
            VStack(spacing: 0) {
                ForEach(Array(instrument.tunings.enumerated()), id: \.element.id) { index, tuning in
                    Button {
                        haptic(.light)
                        tuningName = tuning.name
                    } label: {
                        tuningRow(tuning)
                    }
                    .buttonStyle(.plain)
                    if index < instrument.tunings.count - 1 {
                        Divider().overlay(PocketColor.surfaceBorder)
                    }
                }
            }
        }
    }

    private func tuningRow(_ tuning: Tuning) -> some View {
        let isSelected = tuning.name == tuningName
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tuning.name)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(tuning.compactLabel)
                    .font(.pocketMono(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .kerning(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark")
                .font(.futura(.subheadline, weight: .bold))
                .foregroundStyle(PocketColor.toolkit)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(!isSelected)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Reference pitch

    private var referenceCard: some View {
        card(title: "Reference pitch") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A\(referenceA)")
                        .font(.pocketMono(.title2))
                        .foregroundStyle(PocketColor.textPrimary)
                        .monospacedDigit()
                    Text(referenceA == AppSettings.tunerReferenceDefault
                         ? "Standard concert pitch"
                         : "Hz — concert A")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                HStack(spacing: 10) {
                    stepButton(symbol: "minus", label: "Lower reference pitch",
                               enabled: referenceA > AppSettings.tunerReferenceRange.lowerBound) {
                        referenceA -= 1
                    }
                    stepButton(symbol: "plus", label: "Raise reference pitch",
                               enabled: referenceA < AppSettings.tunerReferenceRange.upperBound) {
                        referenceA += 1
                    }
                }
            }
        }
    }

    private func stepButton(symbol: String, label: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button {
            haptic(.light)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.futura(.title3, weight: .bold))
                .foregroundStyle(enabled ? PocketColor.toolkit : PocketColor.surfaceBorder)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PocketColor.toolkitCircleWash))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Chime

    private var chimeCard: some View {
        card(title: "Success chime") {
            Toggle(isOn: $chimeEnabled) {
                Text("Chime when a string lands in tune")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .tint(PocketColor.toolkit)
        }
    }

    // MARK: - Card chrome

    /// One titled settings card — a section header above a rounded surface, in the toolkit's indigo
    /// study accent (the sheet's shared visual grammar, one level down from the tuner screen itself).
    private func card<Content: View>(title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .textCase(.uppercase)
                .kerning(1.2)
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PocketColor.toolkitCardWash))
        }
    }
}

/// A Pocket-native segmented pill control over raw-string options, bound to an `@AppStorage` `String`.
/// The selected pill fills with the toolkit indigo; the rest read as quiet secondary labels. Used for
/// the instrument and mode pickers so the sheet stays off the system segmented control (ADR 0115).
private struct RawSegmented: View {
    let options: [(value: String, label: String)]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    haptic(.light)
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? PocketColor.toolkit : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(PocketColor.surfaceStandard))
    }
}

#Preview("Tune Settings") {
    TuneSettingsSheet()
        .preferredColorScheme(.dark)
}
