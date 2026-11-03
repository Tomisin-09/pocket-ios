import SwiftUI

// MARK: - The top of the tempo sheet: find it, then hear it (ADR 0284 D1, D2)

/// What heads the sheet under Play and the click: **Find the tempo** until there's a tempo, then the
/// tempo with where it came from, or a beat-mapped song's beats.
struct TempoSheetTopSection: View {
    let top: TempoSheetTop
    /// The bar and its 1, under the tempo.
    let summary: String
    /// The song follows a beat map, which a tempo chosen here replaces on Done (ADR 0281 D4).
    let replacesBeats: Bool
    /// There's a 1, so the click can play the tempo.
    let hasOne: Bool
    let estimateFailed: Bool
    let beatMap: BeatMapHooks?
    let onFind: () -> Void
    let onScale: (Double) -> Void
    let onUseOneTempo: () -> Void

    var body: some View {
        switch top {
        case .find, .listening:
            Section {
                FindTheTempoButton(isListening: top == .listening, action: onFind)
                    .tempoSheetBare()
            }
        case .beats:
            if let beatMap {
                BeatMapSummarySection(hooks: beatMap, onUseOneTempo: onUseOneTempo)
            }
        case .tempo(let shown):
            Section {
                TempoReadingCard(draft: shown, summary: summary, replacesBeats: replacesBeats, hasOne: hasOne,
                                 onScale: onScale)
                    .tempoSheetCard()
            }
        }
        if estimateFailed {
            Section {
                EstimateFailedNote()
                    .listRowBackground(Color.clear)
            }
        }
    }
}

/// **Find the tempo**: the sheet's first move, one wide teal button saying what it does. While it
/// listens it says so and can't be pressed again.
struct FindTheTempoButton: View {
    let isListening: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        Button(action: action) {
            HStack(spacing: 16) {
                Group {
                    if isListening {
                        ProgressView().tint(PocketColor.waveformAccent)
                    } else {
                        Image(systemName: "wand.and.stars").font(.system(size: 26))
                    }
                }
                .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isListening ? "Listening to the song…" : "Find the tempo")
                        .font(.futura(.title3, weight: .bold))
                    Text(isListening ? "A few seconds" : "Listens to the song for its beat and the 1")
                        .font(.futura(.footnote))
                        .foregroundStyle(isListening ? PocketColor.textSecondary : PocketColor.background)
                        .opacity(isListening ? 1 : 0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(isListening ? PocketColor.waveformAccent : PocketColor.background)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(PocketColor.waveformAccent.opacity(isListening ? 0.14 : 1)))
            .overlay(shape.stroke(PocketColor.waveformAccent.opacity(isListening ? 0.5 : 0), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isListening)
        .accessibilityElement(children: .combine)
    }
}

/// The tempo the sheet holds, large, with where it came from above it and the bar and its 1 under
/// it. Then **Half** and **Double**, each with the tempo it gives, for the commonest wrong reading:
/// twice or half the song's (ADR 0282 D5).
struct TempoReadingCard: View {
    let draft: TempoDraft
    let summary: String
    let replacesBeats: Bool
    let hasOne: Bool
    let onScale: (Double) -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var readingSize = 56.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.sourceLine)
                .font(.futura(.caption2, weight: .bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(PocketColor.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TempoMath.wholeBPM(draft.bpm))
                    .font(.system(size: readingSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(TempoMath.wholeBPM(draft.bpm)) beats per minute")
            Text(summary)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textPrimary)
            if replacesBeats {
                Text("Done replaces the beats you tapped with this one tempo.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            // Without a 1 the click can't play, and the strip says so: the line says how to get one.
            Text(hasOne ? "Press play with the click on. If it's twice as fast or half as fast as the song:"
                        : "Mark the 1 below to hear it with the click. If it's twice as fast or half as fast as "
                          + "the song:")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .padding(.top, 6)
            HStack(spacing: 8) {
                scaleButton("Half", factor: 0.5)
                scaleButton("Double", factor: 2)
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The tempo it gives is worked out from the number alone. `TempoDraft.scaled(by:)` would find an
    /// estimate's 1 again, which is work for the press, not for every redraw.
    private func scaleButton(_ title: String, factor: Double) -> some View {
        let allowed = draft.allows(factor)
        let result = TempoMath.wholeBPM(draft.bpm * factor)
        return Button { onScale(factor) } label: {
            Text(allowed ? "\(title) · \(result)" : title)
        }
        .buttonStyle(TempoActionPillStyle())
        .disabled(!allowed)
        .accessibilityLabel(allowed ? "\(title) the tempo, \(result) BPM" : "\(title) the tempo")
    }
}

/// Said when Find the tempo heard no steady beat, so the button doesn't seem to have done nothing.
struct EstimateFailedNote: View {
    var body: some View {
        Label("Couldn't find a steady beat in this song. Tap along or type a tempo instead.",
              systemImage: "exclamationmark.triangle")
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
    }
}
