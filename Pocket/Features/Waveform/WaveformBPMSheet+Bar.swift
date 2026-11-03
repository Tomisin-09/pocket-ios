import SwiftUI

// MARK: - Hearing the tempo inside the sheet (ADR 0283)

/// The song's click as the tempo sheet plays it (ADR 0283 D1). `nil` in previews.
struct TempoClickHooks {
    /// What the click plays: the sheet's switch, and the values Done would commit.
    struct Values: Equatable {
        let isOn: Bool
        let bpm: Double?
        let downbeat: TimeInterval?
        let beatsPerBar: Int
    }

    /// Whether the song's click was on when the sheet opened.
    let wasOn: Bool
    /// Play the click for values not yet saved, or stop it.
    let preview: (Values) -> Void
    /// The sheet has closed: the switch as Done left it, or `nil` for any other way out.
    let end: (Bool?) -> Void
}

/// Play and the click, pinned above the sheet's form so the tempo can be heard while it's set,
/// whichever part of the form is in view (ADR 0283 D1). The click shows only once there's something to
/// click; until then the strip says what's missing, rather than greying out a switch (ADR 0284 D3).
struct TempoSheetTransport: View {
    let engine: PracticeAudioEngine
    @Binding var clickOn: Bool
    /// What the click still needs (a tempo, a 1), or `nil` when it can play.
    let clickWaitsFor: String?
    /// The pushed pages keep the click quiet, so they show Play alone (ADR 0284 D6).
    var offersClick = true

    var body: some View {
        HStack {
            Button { engine.togglePlay() } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(engine.isPlaying ? PocketColor.background : PocketColor.waveformAccent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(engine.isPlaying ? PocketColor.waveformAccent
                                                               : PocketColor.surfaceStandard))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.isPlaying ? "Pause" : "Play")
            Spacer()
            if offersClick {
                if let clickWaitsFor {
                    Text(clickWaitsFor)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    ToggleChip(isOn: clickOn, tint: PocketColor.active) { clickOn.toggle() } content: {
                        Label("Click", systemImage: "metronome")
                            .font(.futura(.footnote, weight: .medium))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(PocketColor.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PocketColor.surfaceStandard).frame(height: 1)
        }
    }
}

// MARK: - Counting the bar by choosing (B4, ADR 0283)

/// What the sheet offers for a bar (ADR 0283 D2): 3 or 4 outright, and **More** for the rest of
/// the presets, which a song in 3 or 4 rarely needs.
enum BarChoice: Hashable {
    case three, four, more

    init(_ signature: TimeSignature) {
        switch (signature.beats, signature.noteValue) {
        case (3, 4): self = .three
        case (4, 4): self = .four
        default: self = .more
        }
    }

    /// The signature a choice sets. More sets none; it shows the rest.
    var signature: TimeSignature? {
        switch self {
        case .three: TimeSignature.forStored(beats: 3, noteValue: 4, accentBeats: [])
        case .four: TimeSignature.standard
        case .more: nil
        }
    }
}

/// The section for the 1 (ADR 0284 D4): how many beats in a bar, which of them is the 1, and the two
/// ways to place it. Shown once there's a tempo to count the beats from.
struct TheOneSection: View {
    @Binding var signature: TimeSignature
    @Binding var one: DownbeatChoice
    let onMark: () -> Void
    let onSetOnWaveform: () -> Void

    var body: some View {
        Section {
            BeatsInABarRow(signature: $signature)
            WhichBeatIsTheOneRow(beat: Binding(get: { one.beat(inBarOf: signature.beats) },
                                               set: { one.beat = $0 }),
                                 beatsPerBar: signature.beats, canChoose: one.placed != nil)
            Button(action: onMark) {
                Label("Mark the 1 at the playhead", systemImage: "1.circle")
            }
            Button(action: onSetOnWaveform) {
                Label("Set the 1 on the waveform", systemImage: "waveform.path")
            }
        } header: {
            TempoSheetHeader("The 1")
        } footer: {
            TempoSheetFooter("The 1 starts a bar, and the click plays it higher. Where a song drifts, set "
                             + "the 1 again on the waveform, and the grid re-locks from there.")
        }
        .tempoSheetCard()
    }
}

/// **Beats in a bar**: 3, 4 or More, which opens the full list of time signatures.
struct BeatsInABarRow: View {
    @Binding var signature: TimeSignature
    @State private var showsMore: Bool

    init(signature: Binding<TimeSignature>) {
        _signature = signature
        _showsMore = State(initialValue: BarChoice(signature.wrappedValue) == .more)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Beats in a bar")
            TempoPills(options: [PickerItem(value: BarChoice.three, title: "3"),
                                 PickerItem(value: BarChoice.four, title: "4"),
                                 PickerItem(value: BarChoice.more, title: "More…")],
                       selection: choice)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Beats in a bar")
            if showsMore {
                Picker("Time signature", selection: $signature) {
                    ForEach(TimeSignature.presets) { Text($0.name).tag($0) }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var choice: Binding<BarChoice> {
        Binding(get: { showsMore ? .more : BarChoice(signature) },
                set: { picked in
                    if let chosen = picked.signature { signature = chosen }
                    showsMore = picked == .more
                })
    }
}

/// **Which beat is the 1?** One button a beat. The click accents the 1, so choosing a beat moves the
/// accent there, and the player keeps the one that lands where the bar starts (ADR 0283 D3). The
/// chosen beat fills green, the player's colour for what's chosen (ADR 0284 D4).
struct WhichBeatIsTheOneRow: View {
    @Binding var beat: Int
    let beatsPerBar: Int
    /// A 1 to count from.
    let canChoose: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Which beat is the 1?")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
                      spacing: 8) {
                ForEach(1...max(1, beatsPerBar), id: \.self) { number in
                    Button {
                        beat = number
                        haptic(.light)
                    } label: {
                        Text("\(number)")
                            .font(.futura(.body))
                            .foregroundStyle(number == beat ? PocketColor.background : PocketColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(number == beat ? PocketColor.active
                                                                     : PocketColor.surfaceStandard))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Beat \(number)")
                    .accessibilityAddTraits(number == beat ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
        .disabled(!canChoose)
        .opacity(canChoose ? 1 : 0.4)
    }

    /// A bar of up to 7 fits one row; 12/8 takes two of 6.
    private var columns: Int { beatsPerBar <= 7 ? max(1, beatsPerBar) : 6 }
}

/// The limit of one tempo, said where a tempo is set (ADR 0283 D4). The same for every song: Red
/// Moon doesn't yet tell a song that moves from one that doesn't.
struct SteadyTempoSection: View {
    var body: some View {
        Section {
            Label("Works best with songs played to a click. A song that speeds up or slows down will drift.",
                  systemImage: "exclamationmark.triangle")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .listRowBackground(Color.clear)
        }
    }
}
