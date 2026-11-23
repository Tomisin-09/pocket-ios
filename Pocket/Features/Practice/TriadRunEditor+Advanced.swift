import SwiftUI

// `TriadRunEditor`'s Advanced rows and its bindings (ADR 0313 D7), out of the editor's file for its length.
// They read only the run and the tint, so they don't need the editor's private state.

extension TriadRunEditor {
    // MARK: - Advanced

    /// *Climb in* only where it means something: the key's seven, up the neck. *Up and back* is for one
    /// chord and the key's seven, since a progression's order is the music (D7).
    var climbsInOneInversion: Bool {
        run.playedProgression == nil && run.source != .oneChord && run.placement == .upTheNeck
    }

    @ViewBuilder var advancedRows: some View {
        if climbsInOneInversion { climbRow }
        playAsRow
        RhythmRow(notesPerBeat: binding(\.notesPerBeat), accessibilityLabel: "Triads rhythm", tint: tint)
        if run.playedProgression == nil {
            Toggle("Up and back", isOn: binding(\.roundTrip))
                .font(.futura(.subheadline, weight: .semibold))
                .tint(tint)
        }
    }

    /// Broken or Together (D7), with the mockup's line saying what each does. Together takes Broken's time,
    /// so switching never changes how long the run is.
    var playAsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel("Play as")
            Picker("Play as", selection: binding(\.playAs)) {
                ForEach(TriadRun.PlayAs.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Play as")
            Text(run.playAs.hint)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    /// A menu around a picker, so the value reads in Futura like `RhythmRow`'s.
    var climbRow: some View {
        LabeledMenuRow(label: "Climb in") {
            Menu {
                Picker("Climb in", selection: binding(\.climbInversion)) {
                    ForEach(0..<3) { Text(TriadRun.inversionName($0)).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(TriadRun.inversionName(run.climbInversion))
                    Image(systemName: "chevron.up.chevron.down").imageScale(.small)
                }
                .font(.futura(.subheadline))
                .foregroundStyle(tint)
            }
            .accessibilityLabel("Climb in")
            .accessibilityValue(TriadRun.inversionName(run.climbInversion))
        }
    }

    /// The rhythm, then only what differs from the defaults.
    var advancedSummary: [String] {
        var parts = [FretboardSubdivisions.label(forPerBeat: run.notesPerBeat)]
        if climbsInOneInversion, run.climbInversion != 0 { parts.append(TriadRun.inversionName(run.climbInversion)) }
        if run.playAs != .broken { parts.append(run.playAs.label) }
        if run.playedProgression == nil, run.roundTrip { parts.append("Up and back") }
        return parts
    }

    // MARK: - Bindings

    func binding<Value>(_ keyPath: WritableKeyPath<TriadRun, Value>) -> Binding<Value> {
        Binding(get: { run[keyPath: keyPath] }, set: { run[keyPath: keyPath] = $0; haptic(.light) })
    }

    /// Major or minor: shows the progression's reading when there is one.
    var minorBinding: Binding<Bool> {
        Binding(get: { run.readsAsMinor }, set: { run.isMinor = $0; haptic(.light) })
    }

    /// Choosing *Progression* with none held copies in the four-chord loop, so the rows have a progression
    /// to show before the menu is opened.
    var sourceBinding: Binding<TriadRun.Source> {
        Binding(get: { run.playedProgression == nil && run.source == .progression ? .keysSeven : run.source },
                set: { source in
                    if source == .progression, run.progression?.steps.isEmpty ?? true {
                        run.progression = TriadRun.defaultProgression
                    }
                    run.source = source
                    haptic(.light)
                })
    }
}
