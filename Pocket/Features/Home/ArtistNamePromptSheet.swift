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
/// the moment breathe, and a centred *signature*-style field — Red Moon register throughout (quiet,
/// faintly mythic, no exclamation). A soft haptic punctuates the commit.
///
/// **Slice 4 — an offered name, not a blank field.** The signature line arrives *pre-filled* with a
/// generated name (`ArtistNameGenerator`), seeded from the player's intake answers so the first one
/// feels fated; **Spin another** rerolls, and typing over it makes it their own. Accepting saves
/// whatever is in the field (generated, spun, or hand-typed) — the greeting doesn't care which.
struct ArtistNamePromptSheet: View {
    /// The local profile, if any — its intake answers seed the *first* offered name so it feels
    /// theirs. `nil` (skipped intake / no profile) falls back to a random device seed.
    var profile: Profile?  // defaults to nil in the memberwise init (keeps the no-arg preview compiling)

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var fieldFocused: Bool
    @State private var name = ""
    /// The seed behind the currently-shown generated name — advanced on each spin.
    @State private var seed: UInt64 = 0
    /// Drives the staged fade/rise-in on appear — the pause before the name *is* the ceremony.
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
                    Text("You've put in the work. Here's one — keep it, spin another, or make it your own.")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                signature

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

    // MARK: - Signature + spin

    /// The signature: centred, underlined rather than boxed — you sign your name, you don't fill a
    /// field. Pre-filled with the offered name; **Spin another** rerolls, typing overrides.
    private var signature: some View {
        VStack(spacing: 18) {
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

            Button(action: spin) {
                Label("Spin another", systemImage: "sparkles")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .accessibilityHint("Offers a different generated name")
        }
    }

    // MARK: - Choreography & actions

    /// Stage the entrance: offer the first name, then fade/rise the content in and let it settle.
    /// Unlike Slice 1 the keyboard is **not** raised on entry — the offered name should present
    /// itself; tapping the field to edit (or Spin another) is an explicit choice. Reduce Motion
    /// collapses the choreography to an instant reveal.
    private func enter() async {
        offerFirstName()
        if reduceMotion {
            revealed = true
            return
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) { revealed = true }
    }

    /// Seed the first offered name from the intake answers (a *fated* name), or a random device seed
    /// when the intake was skipped. Runs once as the ceremony opens.
    private func offerFirstName() {
        let firstSeed = ArtistNameGenerator.seed(experience: profile?.experience,
                                                  genres: profile?.genres ?? [],
                                                  dream: profile?.dream)
            ?? UInt64.random(in: UInt64.min...UInt64.max)
        seed = firstSeed
        name = ArtistNameGenerator.name(seed: firstSeed)
    }

    /// Reroll to a fresh random name — the "spin freely from here" half of deterministic-then-random.
    private func spin() {
        seed = UInt64.random(in: UInt64.min...UInt64.max)
        name = ArtistNameGenerator.name(seed: seed)
        haptic(.light)
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
