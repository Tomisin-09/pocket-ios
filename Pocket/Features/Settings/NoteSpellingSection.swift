import SwiftUI

/// The **accidental preference** row in Settings (ADR 0123) — sharps or flats, with the footer that
/// makes the policy honest: this is a *tiebreaker*, not a global override. Anywhere the music states a
/// key, the key spells the note (the fourth degree of F major is B♭ whatever this says); the preference
/// decides only where nothing does — the tuner, a custom chord, a rootless drill, a bare root menu.
///
/// Its own section so the footer isn't buried under neighbouring rows. Hosted by
/// `AppearanceSettingsView` since ADR 0162 — accidentals are *how a note is written*, so they group
/// with what you see rather than with the tuner that consumes them.
struct NoteSpellingSection: View {
    @AppStorage(AppSettings.Key.accidentalPreference)
    private var accidentalRaw = NoteSpelling.default.rawValue

    private var selection: Binding<NoteSpelling> {
        Binding(get: { NoteSpelling(rawValue: accidentalRaw) ?? .default },
                set: { accidentalRaw = $0.rawValue })
    }

    var body: some View {
        Section {
            Picker("Accidentals", selection: selection) {
                ForEach(NoteSpelling.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Note names")
        } footer: {
            Text("Used where the music doesn't say — the tuner, custom chords, a drill with no key. "
                 + "Scales, arpeggios and songs always spell by their own key, so F major reads B♭ "
                 + "either way.")
        }
    }
}

#Preview {
    Form { NoteSpellingSection() }
}
