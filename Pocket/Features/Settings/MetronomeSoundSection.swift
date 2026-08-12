import SwiftUI

/// The **"Metronome sound"** picker (ADR 0114), hosted by *Settings ▸ Sound & feel*. One row per
/// `ClickTimbre`; all are free — no Pro gate. The live metronome picks up the choice at its next
/// playback start (`ClickVoice.loadTimbre`).
///
/// **One tap chooses and plays (ADR 0162 D5).** The row used to carry two affordances at opposite
/// ends — a play triangle on the far left auditioned, a checkmark on the far right reported selection
/// — and nothing on screen said which of the two a tap in the middle would do. The answer was "it
/// selects, silently", which is the less useful one. Now a tap does both, so you always hear what you
/// just chose.
///
/// That is safe here specifically because **the audition stops itself**: `MetronomeSoundPreviewPlayer`
/// schedules two bars and ends. Nothing needs a stop button, and `play` cancels any in-flight audition
/// first, so tapping down the list works the way you'd expect.
///
/// **The row is on the metronome accent (D6).** The play glyph previously rendered system blue — the
/// platform default leaking through `.buttonStyle(.borderless)` — beside a plum checkmark, two accents
/// in one row. Everything here is now `PocketColor.metronome`.
///
/// **Selection is carried by the title and the checkmark, not a row wash** — the device pass rejected
/// the wash 0162 D6 originally specified, for two reasons worth recording. `.listRowBackground`
/// full-bleeds, so a washed row spans edge-to-edge with square corners and visibly cuts the
/// inset-grouped card in half; and a plum checkmark on a plum wash is invisible, which meant the
/// selected row was the one row showing no tick. Accenting the title instead is legible against the
/// standard row background and leaves the card geometry alone.
struct MetronomeSoundSection: View {
    @AppStorage(AppSettings.Key.clickTimbre) private var clickTimbre = ClickTimbre.default
    /// Owns a private engine so an audition never touches the real metronome; stopped on disappear.
    @State private var preview = MetronomeSoundPreviewPlayer()

    var body: some View {
        Section {
            ForEach(ClickTimbre.allCases) { timbre in
                Button {
                    clickTimbre = timbre
                    preview.play(timbre)
                    haptic(.light)
                } label: {
                    row(for: timbre)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(timbre.displayName). \(timbre.blurb)")
                .accessibilityHint("Chooses this click and plays it")
                .accessibilityAddTraits(clickTimbre == timbre ? [.isSelected] : [])
            }
        } header: {
            Text("Metronome sound")
        } footer: {
            Text("The click your metronome plays. Tap one to choose it and hear two bars at "
                 + "\(MetronomeSoundPreviewPlayer.previewBPM) BPM.")
        }
        // Auditions must not outlive the screen.
        .onDisappear { preview.stop() }
    }

    private func row(for timbre: ClickTimbre) -> some View {
        let isSelected = clickTimbre == timbre
        return HStack(spacing: 12) {
            // A state indicator, not a control — the row is the control now. Shows a speaker while
            // this timbre is the one sounding.
            ZStack {
                Circle()
                    .fill(PocketColor.metronomeCircleWash)
                    .frame(width: 32, height: 32)
                Image(systemName: preview.isPlaying(timbre) ? "speaker.wave.2.fill" : "waveform")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PocketColor.metronome)
            }

            VStack(alignment: .leading, spacing: 2) {
                // The chosen row carries the accent in its title as well as its checkmark, so
                // selection survives being read at a glance without a row wash.
                Text(timbre.displayName)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? PocketColor.metronome : PocketColor.textPrimary)
                Text(timbre.blurb)
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(PocketColor.metronome)
                .opacity(isSelected ? 1 : 0)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        Form { MetronomeSoundSection() }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
    }
    .preferredColorScheme(.dark)
}
