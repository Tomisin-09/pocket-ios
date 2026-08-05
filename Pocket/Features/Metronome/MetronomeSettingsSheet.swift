import SwiftUI

/// How the metronome's **bar is filled** — time signature, subdivision, and click withdrawal — in one
/// sheet, replacing the nav-bar menu that used to hold all three.
///
/// The menu had grown to fifteen rows across three groups. It scrolled, which meant its first row was
/// always clipped and you could not see which group you were in; "12/8 · Slow blues · doo-wop (in 4)"
/// wrapped onto two lines; and the last group added was stranded at the bottom where you had to
/// scroll blind to find it. A sheet fixes all of that by having room, and — the part a menu could
/// never do — gives each choice a footer.
///
/// **Click withdrawal is why the footers matter.** It moved here from Settings (ADR 0132 §4, as
/// amended) and briefly arrived without the prose that had explained it, which is a bad trade for
/// this feature above all others: a metronome that stops clicking is indistinguishable from one that
/// has broken, and the sentence saying otherwise has to sit beside the control.
///
/// Live edits, applied straight to the engine, matching the menu it replaces — the metronome has no
/// commit step and changing the meter mid-play is a normal thing to do.
struct MetronomeSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let engine: StandaloneMetronomeEngine

    @AppStorage(AppSettings.Key.clickWithdrawal)
    private var withdrawalRaw = ClickWithdrawal.default.rawValue

    /// Bindings rather than direct writes: the engine's setters re-anchor the beat grid, so they must
    /// run on every change and exactly once.
    private var signature: Binding<TimeSignature> {
        Binding(get: { engine.timeSignature }, set: { engine.setTimeSignature($0) })
    }

    private var subdivision: Binding<Subdivision> {
        Binding(get: { engine.subdivision }, set: { engine.setSubdivision($0) })
    }

    private var withdrawal: Binding<ClickWithdrawal> {
        Binding(get: { AppSettings.resolvedClickWithdrawal(storedValue: withdrawalRaw) },
                set: { withdrawalRaw = $0.rawValue })
    }

    var body: some View {
        NavigationStack {
            Form {
                OptionListSection(
                    header: "Time signature",
                    options: TimeSignature.presets.map {
                        PickerItem(value: $0, title: $0.name, context: $0.context)
                    },
                    selection: signature, tint: PocketColor.metronome)

                OptionListSection(
                    header: "Subdivision",
                    footer: "Extra clicks between the beats, quieter than the beat itself.",
                    options: Subdivision.pickerOrder.map { PickerItem(value: $0, title: $0.label) },
                    selection: subdivision, tint: PocketColor.metronome)

                OptionListSection(
                    header: "Click withdrawal",
                    footer: "Every eight bars the click thins out and then comes back, so you carry "
                          + "the pulse yourself and hear for yourself what happened when it returns. "
                          + "Nothing is measured or scored. It applies to this metronome only, and "
                          + "pauses while a tempo ramp is climbing.",
                    options: ClickWithdrawal.allCases.map {
                        PickerItem(value: $0, title: $0.label, context: $0.detail)
                    },
                    selection: withdrawal, tint: PocketColor.metronome)
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Metronome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.metronome)
                }
            }
        }
    }
}
