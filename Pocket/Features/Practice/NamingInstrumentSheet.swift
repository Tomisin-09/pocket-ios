import SwiftUI

/// **Where did you play it?** for one piece (ADR 0227 D3): the instrument, then the tuner's curated
/// tunings for it. A list sheet over `OptionListSection` rather than a menu: twelve choices and an
/// explanation are past what a menu may hold.
///
/// For this piece only; the tuner keeps its own setting. A new tuning keeps the frets. A new instrument
/// clears them, so when any are placed it asks first, inline, before handing the change back.
struct NamingInstrumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: NamingTuning
    /// How many answers are placed on the neck: what a new instrument would clear.
    let placed: Int
    let onChoose: (NamingTuning) -> Void
    /// An instrument waiting on the player's say-so, because switching to it clears their frets.
    @State private var pending: Instrument?

    var body: some View {
        NavigationStack {
            Form {
                OptionListSection(
                    header: "Instrument",
                    options: Instrument.allCases.map { PickerItem(value: $0, title: $0.displayName) },
                    selection: instrumentChoice)
                if let pending {
                    Section { confirm(pending) }
                }
                OptionListSection(
                    header: "Tuning",
                    footer: "For this piece only; your tuner keeps its own setting. A new tuning keeps your "
                        + "frets and renames their notes. A new instrument clears them, since a six-string "
                        + "position has nowhere to go on four strings.",
                    options: current.instrument.tunings.map {
                        PickerItem(value: $0.name, title: $0.name, context: Self.stringLetters($0))
                    },
                    selection: tuningChoice)
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Instrument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.practice)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Picking an instrument switches at once when nothing is on the neck, else waits on the question.
    /// The tick stays on the current one until the player says yes.
    private var instrumentChoice: Binding<Instrument> {
        Binding(get: { current.instrument }, set: { next in
            guard next != current.instrument else {
                pending = nil
                return
            }
            if placed == 0 {
                switchTo(next)
            } else {
                pending = next
            }
        })
    }

    /// A new tuning of the same instrument keeps the frets, so it just applies.
    private var tuningChoice: Binding<String> {
        Binding(get: { current.tuning?.name ?? "" }, set: { name in
            let tuning = current.instrument.tuning(named: name)
            onChoose(NamingTuning(instrument: current.instrument, tuning: tuning))
        })
    }

    private func confirm(_ next: Instrument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Switch to \(next.displayName.lowercased())? This clears the \(placed) "
                 + "note\(placed == 1 ? "" : "s") you’ve placed on the neck.")
                .font(.futura(.subheadline))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Switch to \(next.displayName.lowercased())") { switchTo(next) }
                    .buttonStyle(.borderedProminent)
                Button("Keep \(current.instrument.displayName.lowercased())") { pending = nil }
                    .buttonStyle(.bordered)
            }
            .font(.futura(.subheadline))
            .tint(PocketColor.practice)
        }
        .padding(.vertical, 4)
    }

    private func switchTo(_ next: Instrument) {
        pending = nil
        onChoose(NamingTuning(instrument: next, tuning: next.standardTuning))
    }

    /// A tuning's open strings, lowest first as a player says them: "D A D G A D".
    nonisolated static func stringLetters(_ tuning: Tuning) -> String {
        tuning.midiNotes.map { GuitarScale.noteName(forPitchClass: (($0 % 12) + 12) % 12) }.joined(separator: " ")
    }
}
