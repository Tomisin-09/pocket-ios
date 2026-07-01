import SwiftUI

/// A field label paired with a tappable **ⓘ** that reveals a one-line explanation in a popover.
/// Used on the coined practice-model fields — Mastery, Command tempo, Focus, loop Type, and the
/// derived Song mastery — where the label alone doesn't convey the meaning (Cluster 4 polish).
/// Standard music vocabulary (Key, Genre, BPM) deliberately gets none — an ⓘ there is noise.
///
/// Drop it into any `LabeledContent` / `Stepper` label slot. The info button carries its own tap
/// target (`.plain` button style) so it stays independently tappable inside a Form row — including
/// alongside a menu `Picker`, whose row would otherwise swallow the tap — and the popover pins to
/// a compact callout on iPhone via `presentationCompactAdaptation(.popover)` instead of adapting
/// to a full sheet.
struct FieldInfoLabel: View {
    let title: String
    let info: String
    @State private var showingInfo = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About \(title)")
            .popover(isPresented: $showingInfo) {
                Text(info)
                    .font(.callout)
                    .foregroundStyle(PocketColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    // Force the text to report its full height for the fixed width, so the popover
                    // grows to fit instead of clipping to a compact two-line callout.
                    .frame(width: 260, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}

/// Single source of truth for the explanatory copy. Centralised so the shared terms read
/// identically everywhere they surface (Command tempo appears on both the loop and exercise
/// create paths). The copy encodes the ADR 0036 field definitions.
enum PracticeFieldInfo {
    static let mastery =
        "How cleanly you own this loop — feel, tone, accuracy. Separate from speed: you can "
        + "play something fast but scrappy, or slow but perfect."
    static let commandTempo =
        "The fastest speed you own this loop at, as a % of the original. Command is speed; "
        + "Mastery is cleanliness — deliberately two axes."
    static let focus =
        "Your intent right now, not how well you play it. Backburner (parked) · Active (in "
        + "rotation) · Sharpening (pushing it / gig prep)."
    static let loopType =
        "What kind of loop: Lick (melodic) · Riff (melody + rhythm) · Chords (rhythmic) · "
        + "Passage (a longer span covering several)."
    static let songMastery =
        "Averaged from this song's loops — rate individual loops to set it. \u{201C}Unrated\u{201D} "
        + "until at least one loop has a mastery."
    static let exerciseCommandTempo =
        "The fastest you can play it cleanly and repeatably right now. The warm-up floor and the "
        + "reach derive from it — tune them when you run the drill. Command is speed, separate "
        + "from how cleanly you own it."
}

#Preview {
    Form {
        Section("Practice") {
            LabeledContent {
                Text("★★★☆☆").foregroundStyle(PocketColor.marker)
            } label: {
                FieldInfoLabel(title: "Mastery", info: PracticeFieldInfo.mastery)
            }
            LabeledContent {
                Text("85%").font(.pocketMono(.body))
            } label: {
                FieldInfoLabel(title: "Command tempo", info: PracticeFieldInfo.commandTempo)
            }
        }
    }
    .preferredColorScheme(.dark)
}
