import SwiftData
import SwiftUI

/// The **"you've earned a name"** moment (ADR 0113). Shown once, full-screen, after the player has
/// actually done the work — completed an exercise or captured a loop — never demanded at the door.
/// It's an offer, not a gate: "Not now" leaves as cleanly as signing, the name stays editable in
/// Settings either way, and the parent sets `artistNamePromptSeen` on either exit so this never
/// returns.
///
/// Deliberately ceremonial rather than a form (device feedback: the plain sheet read flat). A
/// full-screen cover on the app's own ground, a dimmed Red Moon crest, a staged fade-in that lets
/// the moment breathe, and a centred *signature*-style field you sign your name into — Red Moon
/// register throughout (quiet, faintly mythic, no exclamation). A soft haptic punctuates the
/// commit. The generated-name flow (accept / reroll) is ADR 0113 Slice 4; Slice 1 signs by hand.
struct ArtistNamePromptSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var fieldFocused: Bool
    @State private var name = ""
    /// Drives the staged fade/rise-in on appear — the pause before the field *is* the ceremony.
    @State private var revealed = false

    private var isBlank: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // The Red Moon crescent as the seal over the moment — the symbol alone (no
                // wordmark, `RedMoonMark`), so it reads as an emblem, not a logo lockup.
                // Theme-aware artwork (ADR 0061/0062), so it sits right in either appearance.
                Image("RedMoonMark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 132)
                    .opacity(0.9)
                    .padding(.bottom, 36)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Every artist earns their name.")
                        .font(.futura(.title2, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("You've put in the work. What should we call you?")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 36)

                // The signature: centred, underlined rather than boxed — you sign your name, you
                // don't fill a field.
                VStack(spacing: 10) {
                    TextField("", text: $name, prompt: Text("Your name"))
                        .font(.futura(.title, weight: .medium))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($fieldFocused)
                        .onSubmit(save)
                        .foregroundStyle(PocketColor.textPrimary)
                    Rectangle()
                        .fill(PocketColor.surfaceBorder)
                        .frame(height: 1)
                        .frame(maxWidth: 200)
                }
                .padding(.horizontal, 40)

                Spacer()

                VStack(spacing: 16) {
                    Button(action: save) {
                        Text("This is me")
                            .font(.futura(.headline))
                            .foregroundStyle(PocketColor.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(PocketColor.textPrimary, in: Capsule())
                    }
                    .disabled(isBlank)
                    .opacity(isBlank ? 0.4 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isBlank)

                    Button("Not now") { dismiss() }
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
        }
        // The ceremony is always dark, whatever the app's appearance — the near-black ground and
        // the moon read stronger, and it sets the moment apart from the rest of the UI. This also
        // resolves the theme-aware assets/colours (`RedMoonMark`, `PocketColor.*`) to their dark
        // variants regardless of the device setting.
        .preferredColorScheme(.dark)
        .task { await enter() }
    }

    /// Stage the entrance: fade/rise the content in, hold a beat, then raise the keyboard so the
    /// cursor lands in the signature line. Reduce Motion collapses the choreography to an instant
    /// reveal + immediate focus.
    private func enter() async {
        if reduceMotion {
            revealed = true
            fieldFocused = true
            return
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) { revealed = true }
        try? await Task.sleep(for: .seconds(1))
        fieldFocused = true
    }

    private func save() {
        guard !isBlank else { return }
        Profile.setArtistName(name, in: context)
        haptic(.medium) // a single soft beat marks the name being taken
        dismiss()
    }
}

#Preview {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) { ArtistNamePromptSheet() }
        .modelContainer(for: Profile.self, inMemory: true)
}
