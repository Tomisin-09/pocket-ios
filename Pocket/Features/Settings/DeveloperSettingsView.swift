#if DEBUG
import SwiftData
import SwiftUI

/// **Settings ▸ Developer** — DEBUG-only scaffolding, gathered behind one row (ADR 0162 D8).
///
/// The whole file is inside `#if DEBUG`, so none of this exists in a shipping build. Gathering it
/// here is not only tidiness: on the flat screen these three sections were a meaningful share of both
/// the scroll and `SettingsView`'s line count, and none of them belong in a player's field of view
/// even in a TestFlight build.
struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store

    /// Re-arms the one-time "you've earned a name" prompt without a data-wiping reinstall.
    @AppStorage(AppSettings.Key.artistNamePromptSeen) private var artistNamePromptSeen = false
    /// Re-arms the first-launch curation intake (ADR 0113 S2).
    @AppStorage(AppSettings.Key.artistIntakeSeen) private var artistIntakeSeen = false
    /// Force the Red Moon Pro entitlement on/off and preview the paywall (ADR 0112).
    @State private var showingDebugPaywall = false

    /// The three debug entitlement choices, bridging `StoreManager.debugProOverride` (a `Bool?`).
    private enum ProOverrideChoice: Hashable { case defaultReal, free, pro }
    private var proOverride: Binding<ProOverrideChoice> {
        Binding(
            get: {
                switch store.debugProOverride {
                case .none: return .defaultReal
                case .some(true): return .pro
                case .some(false): return .free
                }
            },
            set: { choice in
                switch choice {
                case .defaultReal: store.debugProOverride = nil
                case .free: store.debugProOverride = false
                case .pro: store.debugProOverride = true
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Entitlement", selection: proOverride) {
                    Text("Default").tag(ProOverrideChoice.defaultReal)
                    Text("Free").tag(ProOverrideChoice.free)
                    Text("Pro").tag(ProOverrideChoice.pro)
                }
                .pickerStyle(.segmented)
                LabeledContent("Currently", value: store.isPro ? "Pro" : "Free")
                Button("Show paywall") { showingDebugPaywall = true }
            } header: {
                Text("Red Moon Pro")
            } footer: {
                Text("Force the Pro entitlement on or off to exercise the paywall gates before "
                     + "StoreKit sandbox exists. “Default” uses the real StoreKit entitlement.")
            }

            // A/B the stretcher-latency correction (ADR 0140 §3).
            DebugAudioSection()

            Section {
                Button("Reset naming prompt", role: .destructive, action: resetNamingPrompt)
                Button("Reset first-launch intake", role: .destructive, action: resetIntake)
            } header: {
                Text("First-run flows")
            } footer: {
                Text("Clears your artist name and re-arms the “you've earned a name” prompt; the "
                     + "second row re-arms the first-launch curation intake.")
            }
        }
        .settingsScreen(title: "Developer")
        .sheet(isPresented: $showingDebugPaywall) {
            PaywallView(trigger: .general).environment(store)
        }
    }

    /// Clear the artist name and re-arm the one-time naming prompt, so the "you've earned a name"
    /// ceremony can be exercised again on a real install (no reinstall / data loss).
    private func resetNamingPrompt() {
        Profile.setArtistName(nil, in: context)
        artistNamePromptSeen = false
    }

    /// Re-arm the one-time first-launch curation intake. Leaves the stored curation in place (it stays
    /// visible/editable under "You"); this only flips the "seen" gate so Home offers the flow again.
    private func resetIntake() {
        artistIntakeSeen = false
    }
}

#Preview {
    NavigationStack { DeveloperSettingsView() }
        .modelContainer(for: Profile.self, inMemory: true)
        .environment(StoreManager())
}
#endif
