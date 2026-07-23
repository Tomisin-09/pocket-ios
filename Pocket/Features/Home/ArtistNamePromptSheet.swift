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
/// **Slice 4 — a name is offered, never imposed.** The signature line starts **blank**; providing a
/// name is an explicit act — type your own, or tap **Spin a name** to have one offered
/// (`ArtistNameGenerator`). The *first* spin is seeded from the player's intake answers so it feels
/// fated; each **Spin another** rerolls randomly. Accepting saves whatever is in the field (spun or
/// hand-typed) — the greeting doesn't care which, and "This is me" stays disabled until there is one.
struct ArtistNamePromptSheet: View {
    /// The local profile, if any — its intake answers seed the *first* offered name so it feels
    /// theirs. `nil` (skipped intake / no profile) falls back to a random device seed.
    var profile: Profile?  // defaults to nil in the memberwise init (keeps the no-arg preview compiling)

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var fieldFocused: Bool
    @State private var name = ""
    /// The **fated** seed for the *first* spin — computed from the intake on appear, used once so the
    /// first offered name feels theirs; subsequent spins draw a fresh random seed.
    @State private var firstSeed: UInt64 = 0
    /// Whether the player has spun at least once — the first spin uses `firstSeed`, later ones random,
    /// and the button label shifts "Spin a name" → "Spin another".
    @State private var hasSpun = false
    /// Drives the staged fade/rise-in on appear — the pause before the moment breathes.
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
                    Text("You've put in the work. Sign your name — or spin one up.")
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
    /// field. Starts **blank**; **Spin a name** offers one (typing overrides), so providing the name
    /// is always an explicit act.
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

            Button(action: spinName) {
                Label(hasSpun ? "Spin another" : "Spin a name", systemImage: "sparkles")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .accessibilityHint("Offers a generated name you can keep or edit")
        }
    }

    // MARK: - Choreography & actions

    /// Stage the entrance: prepare the fated seed, then fade/rise the content in and let it settle.
    /// The field stays **blank** and the keyboard is **not** raised — providing a name is the
    /// player's explicit next move (type, or Spin a name). Reduce Motion collapses the choreography
    /// to an instant reveal.
    private func enter() async {
        firstSeed = ArtistNameGenerator.seed(experience: profile?.experience,
                                             genres: profile?.genres ?? [],
                                             dream: profile?.dream)
            ?? UInt64.random(in: UInt64.min...UInt64.max)
        if reduceMotion {
            revealed = true
            return
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) { revealed = true }
    }

    /// Offer a name into the signature. The first spin uses the intake-seeded `firstSeed` (a *fated*
    /// name); every spin after draws a fresh random seed — deterministic-then-random. Dismisses the
    /// keyboard so the offered name is what's on screen; typing over it still overrides.
    private func spinName() {
        let seed = hasSpun ? UInt64.random(in: UInt64.min...UInt64.max) : firstSeed
        name = ArtistNameGenerator.name(seed: seed)
        hasSpun = true
        fieldFocused = false
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
