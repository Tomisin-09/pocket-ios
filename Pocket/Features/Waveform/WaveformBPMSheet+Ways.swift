import SwiftUI

// MARK: - The other ways to set a tempo (ADR 0284 D5, D6)

/// Under the 1, the ways to set a tempo besides finding it, each saying when it's the one to use.
/// *Find the tempo* joins them once something heads the sheet that didn't come from it.
struct OtherWaysSection: View {
    /// A tempo heads the sheet, so these are *other* ways rather than the only ones left.
    let hasTempo: Bool
    let offersFindAgain: Bool
    /// The song can be tapped through (`nil` hooks in previews).
    let offersTapThrough: Bool
    @Binding var typing: Bool
    @Binding var typedText: String
    /// The tempo shown, which typing its whole number keeps exact.
    let showing: Double?
    let onFind: () -> Void
    let onUseTyped: (Double) -> Void

    var body: some View {
        Section {
            if offersFindAgain {
                Button(action: onFind) {
                    TempoWayLabel(title: "Find the tempo", when: "Listens to the song for its beat and the 1",
                                  systemImage: "wand.and.stars")
                }
            }
            NavigationLink(value: TempoSheetPage.tapAlong) {
                TempoWayLabel(title: "Tap along", when: "Tap with the song as it plays", systemImage: "hand.tap")
            }
            Button { typing.toggle() } label: {
                TempoWayLabel(title: "Type a tempo", when: "When you already know it", systemImage: "keyboard")
            }
            if typing {
                TypeATempoRow(text: $typedText, showing: showing, onUse: onUseTyped)
            }
            if offersTapThrough {
                NavigationLink(value: TempoSheetPage.tapThrough) {
                    TempoWayLabel(title: "Tap through the song", when: "For a song that speeds up or slows down",
                                  systemImage: "waveform")
                }
            }
        } header: {
            TempoSheetHeader(hasTempo ? "Other ways to set it" : "Or set it yourself")
        }
        .tempoSheetCard()
    }
}

/// *Type a tempo*, open in place under its row: the number, and **Use**.
struct TypeATempoRow: View {
    @Binding var text: String
    let showing: Double?
    let onUse: (Double) -> Void

    @FocusState private var focused: Bool

    private var value: Double? { TempoDraft.typed(text, showing: showing) }

    var body: some View {
        HStack(spacing: 10) {
            TextField("120", text: $text)
                .keyboardType(.decimalPad)
                .font(.pocketMono(.body))
                .focused($focused)
                .padding(.horizontal, 12)
                .frame(width: 96, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.background))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(PocketColor.surfaceBorder, lineWidth: 1))
                .accessibilityLabel("Tempo in BPM")
            Text("BPM")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            Button("Use") {
                guard let value else { return }
                focused = false
                onUse(value)
            }
            .buttonStyle(TempoPrimaryPillStyle())
            .disabled(value == nil)
        }
        .padding(.leading, 40)
        .padding(.vertical, 2)
        .onAppear { focused = true }
    }
}

/// **Tap along** (ADR 0284 D6): a page of its own, so the pad can be big and the taps change nothing
/// until **Use**. Taps read the playhead (`PracticeAudioEngine.currentTime`), so a loop or a slowed
/// speed still reads the song's true tempo. The click is quiet here: it would play the tempo being
/// replaced, and pull the taps towards it.
struct TapAlongView: View {
    let engine: PracticeAudioEngine
    let onUse: (Double) -> Void

    @State private var taps: [TimeInterval] = []
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize = 64.0

    private var reading: Double? { TempoMath.bpm(fromTapTimes: taps) }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(reading.map(TempoMath.wholeBPM) ?? "—")
                    .font(.system(size: readingSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(reading.map { "\(TempoMath.wholeBPM($0)) beats per minute" } ?? "Tempo not set")
            // ADR 0166: the reading moves while you tap, which is surprising if it isn't said.
            Text("Play the song and tap along. The reading follows your last few taps.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button { tap() } label: {
                Text(engine.isPlaying ? "TAP" : "Play to start tapping")
            }
            .buttonStyle(TapPadStyle(isLive: engine.isPlaying))
            .disabled(!engine.isPlaying)
            .accessibilityLabel("Tap to the beat")
            HStack {
                Button("Reset") { taps.removeAll() }
                    .buttonStyle(TempoActionPillStyle())
                    .disabled(taps.isEmpty)
                Spacer()
                Button(reading.map { "Use \(TempoMath.wholeBPM($0)) BPM" } ?? "Use this tempo") {
                    if let reading { onUse(reading) }
                }
                .buttonStyle(TempoPrimaryPillStyle())
                .disabled(reading == nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .safeAreaInset(edge: .top, spacing: 0) {
            TempoSheetTransport(engine: engine, clickOn: .constant(false), clickWaitsFor: nil, offersClick: false)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .tint(PocketColor.waveformAccent)
        .navigationTitle("Tap along")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tap() {
        guard engine.isPlaying else { return }
        taps.append(engine.currentTime)
        haptic(.light)
    }
}

/// The tap pad, terracotta as the metronome's TAP buttons are plum, and lit while it's pressed so each tap
/// is seen as well as felt. It fills the height it's given. Quiet while the song is paused, when a
/// tap has no playhead to read.
struct TapPadStyle: ButtonStyle {
    var isLive = true

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let wash = isLive ? (configuration.isPressed ? 0.32 : 0.14) : 0.06
        return configuration.label
            .font(isLive ? .futura(.title2, weight: .bold) : .futura(.headline))
            .tracking(isLive ? 2 : 0)
            .foregroundStyle(isLive ? PocketColor.waveformAccent : PocketColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: .infinity)
            .background(shape.fill(PocketColor.waveformAccent.opacity(wash)))
            .overlay(shape.stroke(PocketColor.waveformAccent.opacity(isLive ? 0.5 : 0.25), lineWidth: 1))
            .contentShape(shape)
    }
}
