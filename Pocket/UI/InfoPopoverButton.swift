import SwiftUI

/// The **ⓘ on its own**: a tappable info glyph that reveals an explanation in a compact popover.
/// The half of `FieldInfoLabel` that isn't the title — for rows whose title is already something
/// else (a toggle, a skill name), so there is still one ⓘ grammar in the app rather than two.
///
/// ⚠ **Put it beside a row's control, never inside it.** A `Button` nested in another `Button`'s
/// label fires both on one tap; a skill row that toggles on tap must lay the name and this glyph
/// out as two siblings (ADR 0216 D5).
struct InfoPopoverButton: View {
    /// What the explanation is about — read by VoiceOver as *"About \(subject)"*.
    let subject: String
    let info: String
    @State private var showingInfo = false

    var body: some View {
        Button {
            showingInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                // A glyph this small is a hard target in a list row; the frame is the target.
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(subject)")
        .popover(isPresented: $showingInfo) {
            Text(info)
                .font(.futura(.callout))
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
