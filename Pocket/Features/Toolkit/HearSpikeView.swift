import SwiftUI

/// **SPIKE (ADR 0096 D4 — Hear source, throwaway).** A bench for judging the "Hear" tone on device: a
/// few voicings, a diagram, a Strum/Block toggle, and a Hear button that drives `ChordTonePlayer`. It
/// reports which source is live (built-in tone vs. bundled SoundFont) so the test is honest. Not shipped
/// — reached via a temporary link in `ToolkitView`; delete both once D4 is decided.
struct HearSpikeView: View {
    /// A spread of test cases: open, barre, and a jazzy stack — enough to hear whether triads *and*
    /// denser voicings read clearly.
    private let voicings: [ChordVoicing] = [
        ChordVoicing("C", frets: [0, 1, 0, 2, 3, nil]),
        ChordVoicing("Am", frets: [0, 1, 2, 2, 0, nil]),
        ChordVoicing("G", frets: [3, 0, 0, 0, 2, 3]),
        ChordVoicing("F (barre)", frets: [1, 1, 2, 3, 3, 1]),
        ChordVoicing("Cadd9", frets: [3, 3, 2, 0, 3, nil]),
        ChordVoicing("Dm7", frets: [1, 1, 2, 0, nil, nil])
    ]

    @State private var player = ChordTonePlayer()
    @State private var selection = 0
    @State private var strum = true

    private var current: ChordVoicing { voicings[selection] }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(player.source.rawValue)
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .padding(.top, 8)

                ChordDiagramView(voicing: current, tint: PocketColor.toolkit)
                    .frame(width: 200)

                Picker("Chord", selection: $selection) {
                    ForEach(voicings.indices, id: \.self) { index in
                        Text(voicings[index].name).tag(index)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Strum (vs. block chord)", isOn: $strum)
                    .font(.futura(.subheadline))
                    .tint(PocketColor.toolkit)

                Button {
                    player.play(current, strum: strum)
                } label: {
                    Label("Hear", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PocketColor.toolkit)
                .controlSize(.large)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Hear spike")
        .navigationBarTitleDisplayMode(.inline)
        .tint(PocketColor.toolkit)
    }
}
