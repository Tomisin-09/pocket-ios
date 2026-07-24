import SwiftUI

/// The **"Metronome sound"** picker in Settings (ADR 0114): one row per `ClickTimbre`, each with a
/// play button that auditions the sound at a fixed 90 BPM before you commit. Split out of `SettingsView`
/// so that screen stays under the file/type-length cap (mirrors `ProfileCurationSection`).
///
/// Tapping a row **selects** the timbre (persisted via `@AppStorage`); tapping the inline play button
/// **auditions** it without changing the selection. All timbres are free (ADR 0114) — no Pro gate. The
/// live metronome picks up the choice at its next playback start (`ClickVoice.loadTimbre`).
struct MetronomeSoundSection: View {
    @AppStorage(AppSettings.Key.clickTimbre) private var clickTimbre = ClickTimbre.default
    /// Owns a private engine so an audition never touches the real metronome; stopped on disappear.
    @State private var preview = MetronomeSoundPreviewPlayer()

    var body: some View {
        Section {
            ForEach(ClickTimbre.allCases) { timbre in
                Button {
                    clickTimbre = timbre
                } label: {
                    row(for: timbre)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Metronome sound")
        } footer: {
            Text("The click your metronome plays. Tap ▶ to hear each one at "
                 + "\(MetronomeSoundPreviewPlayer.previewBPM) BPM.")
        }
        // Auditions must not outlive the screen.
        .onDisappear { preview.stop() }
    }

    private func row(for timbre: ClickTimbre) -> some View {
        HStack(spacing: 12) {
            Button {
                preview.isPlaying(timbre) ? preview.stop() : preview.play(timbre)
            } label: {
                Image(systemName: preview.isPlaying(timbre) ? "stop.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            // Borderless so the play button is independently tappable inside the selectable row.
            .buttonStyle(.borderless)
            .accessibilityLabel(preview.isPlaying(timbre) ? "Stop preview" : "Preview \(timbre.displayName)")

            VStack(alignment: .leading, spacing: 2) {
                Text(timbre.displayName)
                    .foregroundStyle(PocketColor.textPrimary)
                Text(timbre.blurb)
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(PocketColor.metronome)
                .opacity(clickTimbre == timbre ? 1 : 0)
                .accessibilityLabel("Selected")
                .accessibilityHidden(clickTimbre != timbre)
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
