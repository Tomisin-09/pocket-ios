import SwiftUI

/// A one-section sheet for choosing a **time signature**, over `OptionListSection`.
///
/// Small on purpose. It exists so the run screen's meter control and the metronome's settings sheet
/// present the same seven choices the same way, rather than one being a truncating popup menu and the
/// other a legible list. The musical context — "Slow blues · doo-wop (in 4)" — is the half of each
/// label that tells you which meter you actually want, and it is the half a menu drops first.
struct MeterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var signature: TimeSignature
    var tint: Color = PocketColor.practice

    var body: some View {
        NavigationStack {
            Form {
                OptionListSection(
                    header: "Time signature",
                    footer: "Sets which beats the click accents, and how long the count-in runs.",
                    options: TimeSignature.presets.map {
                        PickerItem(value: $0, title: $0.name, context: $0.context)
                    },
                    selection: $signature, tint: tint)
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Meter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .bold))
                        .tint(tint)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
