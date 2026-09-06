import SwiftUI

/// The **Jump back in** row in Settings (ADR 0193) — which kind of unit Home's resume card offers.
///
/// Its own section so the footer can say what the four values actually do without crowding the
/// Practice toggles it sits under, exactly as `TempoWarningSection` does. Inside
/// `PracticeSettingsView` rather than as an eleventh Settings destination: the hub is nine
/// preference destinations plus two state rows, and one picker does not earn a screen. Practice is
/// the right one of the nine — what Home offers you to resume is what you end up practising, the
/// same argument ADR 0186's reminders were placed on.
///
/// A **menu** picker, not the segmented control the tempo warning uses: four values whose longest
/// label is *Most recent* would be four unreadable segments, and the menu form is also what lets the
/// hub-style "row states its current value on the right" reading hold.
struct JumpBackInSection: View {
    // Bound to the constant, never a literal — the `@AppStorage` default is what SwiftUI uses for an
    // unset key and it does not consult the accessor. `HomeView` binds the same key the same way.
    @AppStorage(AppSettings.Key.jumpBackIn)
    private var preferenceRaw = AppSettings.jumpBackInPreferenceDefault.rawValue

    private var selection: Binding<JumpBackInPreference> {
        Binding(get: { AppSettings.resolvedJumpBackIn(storedValue: preferenceRaw) },
                set: { preferenceRaw = $0.rawValue })
    }

    var body: some View {
        Section {
            Picker("Jump back in", selection: selection) {
                ForEach(JumpBackInPreference.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } header: {
            Text("Home")
        } footer: {
            Text("The card under today's session carries the last thing you practised. Pin it to a "
                 + "song, a routine or an exercise if that is what you always come back to. You can "
                 + "also hold the card itself to change this. Whichever you pick, the most recent "
                 + "of any kind shows until there is one of that kind to show.")
        }
    }
}

#Preview {
    Form { JumpBackInSection() }
}
