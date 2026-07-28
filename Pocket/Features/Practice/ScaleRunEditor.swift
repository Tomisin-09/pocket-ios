import SwiftUI

/// The **scale library editor** (ADR 0065 build 2, Slice 2). Scales are *picked*, not placed: choose
/// a **scale**, a **root note**, a **position** up the neck, and how many **octaves**, and a
/// notes-per-string generator lays the box out and walks it. A live preview shows the run before it's
/// saved; "up and back" and the subdivision (Advanced, default eighths) round it out.
///
/// A thin skin over `ScaleRun` — each control rebuilds the bound recipe (whose init clamps the
/// position/octaves), and the preview reads `run.expanded()`; no timing logic here (T5). **T10** —
/// every colour is a semantic `PocketColor` role. Shared chrome (Hear/Watch/Display bar, field labels,
/// stepper, root picker, badge, subdivision row) lives in `FretboardEditorChrome`.
struct ScaleRunEditor: View {
    @Binding var run: ScaleRun
    /// The exercise's instrument (ADR 0116) — fixes which neck the preview draws and how the box is
    /// generated. Guitar (the default) is byte-identical to before; bass renders a four-string 2-octave box.
    var instrument: Instrument = .guitar
    var tint: Color = PocketColor.practice

    @State private var showsAdvanced = false
    /// Note captions are a global viewing preference (ADR 0065) so the board reads the same here and
    /// in the live practice run; the Display menu that sets it lives in the shared options bar.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    /// Per-note duration matching the preview walk, so Hear stays locked to the highlight (ADR 0097 S3).
    private var secondsPerNote: Double {
        60.0 / Double(FretboardDrillPreview.previewBPM) / Double(max(1, run.notesPerBeat))
    }
    /// The run's notes as MIDI, in playing order — what Hear sounds (no rests in a generated scale run).
    /// Resolved through the instrument so a bass run sounds an octave lower on the right strings.
    private var heardNotes: [Int?] { run.heardMidi(for: instrument).map { Optional($0) } }
    /// A one-shot "watch it" request (ADR 0065) — set by the options bar's Hear/Watch, read by the
    /// preview below.
    @State private var playOnceToken: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FretboardDisplayOptionsBar(heardNotes: heardNotes, secondsPerNote: secondsPerNote,
                                       playToken: $playOnceToken, tint: tint)
            FretboardDrillPreview(drill: run.expanded(instrument: instrument), tint: tint,
                                  labelMode: labelMode, playOnceToken: playOnceToken)
            titleField
            LabeledMenuRow(label: "Scale") { scalePicker }
            LabeledMenuRow(label: "Root") {
                RootNotePicker(pitchClass: rootBinding, tint: tint, accessibilityValue: run.rootName)
            }
            // Bass is box-only (the diagonal / 3-notes-per-string layouts are guitar techniques, ADR 0116).
            if instrument == .guitar, run.scale.supportedLayouts.count > 1 { layoutRow }
            if run.positionCount(for: instrument) > 1 { positionRow }
            advanced
        }
        .hearStopsOnDisappear()
    }

    // MARK: - Advanced

    /// **Scale · Root · Layout · Position stay above the fold**; everything that shapes how the box is
    /// *played* rather than which box it is drops into one Advanced disclosure (2026-07-28) — Rhythm,
    /// Octaves, Sequence, Up-and-back and the starting note. The collapsed summary carries whatever
    /// deviates from the defaults, so a run stays legible without opening it.
    private var advanced: some View {
        EditorDisclosure(title: "Advanced", isExpanded: $showsAdvanced,
                         summaryParts: advancedSummary, tint: tint) {
            RhythmRow(notesPerBeat: subdivisionBinding, accessibilityLabel: "Scale rhythm", tint: tint)
            if run.layout.usesOctaves { octavesRow }
            sequenceRow
            Toggle("Up and back", isOn: roundTripBinding)
                .font(.futura(.subheadline, weight: .semibold))
                .tint(tint)
            // Box-only: the diagonal and 3-notes-per-string patterns are defined by their string-by-string
            // fingering, so starting one part-way through would break the pattern being taught.
            if run.layout == .box { lowestRootToggle }
        }
    }

    private var lowestRootToggle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Start from the lowest root note", isOn: lowestRootBinding)
                .font(.futura(.subheadline, weight: .semibold))
                .tint(tint)
            Text("Begin on \(run.rootName) instead of the box's lowest note.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A terse read of what's inside the closed disclosure: the rhythm always, then only what *differs*
    /// from the defaults — showing "Up and back" when it's on (the default) would be pure noise.
    /// `EditorDisclosure` spells out the first couple and counts the rest, so this can grow safely.
    private var advancedSummary: [String] {
        var parts = [FretboardSubdivisions.label(forPerBeat: run.notesPerBeat)]
        if run.layout.usesOctaves, run.octaves == 1 { parts.append("1 octave") }
        if run.sequencePattern != .straight { parts.append(run.sequencePattern.displayName) }
        if !run.roundTrip { parts.append("One way") }
        if run.layout == .box, !run.startsFromLowestRoot { parts.append("From lowest note") }
        return parts
    }

    // MARK: - Title

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(run.title)
                .font(.futura(.headline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(subtitle)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    /// The box's primary label is now its root anchor (in the position row); the subtitle carries the
    /// demoted CAGED letter and the fret span (ADR 0091). The neck-spanning layouts name themselves.
    private var subtitle: String {
        // Bass has no CAGED letter — just the 2-octave box's start (ADR 0116).
        guard instrument == .guitar else {
            return "2 octaves · from fret \(run.anchorFret(for: instrument))"
        }
        switch run.layout {
        case .box:
            return "CAGED \(run.shapeLetter) shape · from fret \(run.anchorFret)"
        case .extended, .threePerString:
            return "\(run.layout.displayName) · from fret \(run.anchorFret)"
        }
    }

    // MARK: - Menus

    private var layoutRow: some View {
        LabeledMenuRow(label: "Layout") {
            Picker("Layout", selection: layoutBinding) {
                ForEach(run.scale.supportedLayouts) { layout in Text(layout.displayName).tag(layout) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(tint)
            .accessibilityLabel("Layout, \(run.layout.displayName)")
        }
    }

    private var scalePicker: some View {
        Picker("Scale", selection: scaleBinding) {
            ForEach(GuitarScale.allCases) { scale in Text(scale.displayName).tag(scale) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(tint)
        .accessibilityLabel("Scale, \(run.scale.displayName)")
    }

    /// The **sequence** picker (ADR 0108) — straight, or the run reordered into thirds / fourths /
    /// rolling groups. Orthogonal to scale/root/box, so it's offered for every layout.
    private var sequenceRow: some View {
        LabeledMenuRow(label: "Sequence") {
            Picker("Sequence", selection: sequenceBinding) {
                ForEach(SequencePattern.allCases) { pattern in
                    Text(pattern.displayName).tag(pattern)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(tint)
            .accessibilityLabel("Sequence, \(run.sequencePattern.displayName)")
        }
    }

    // MARK: - Position + octaves

    /// The neck position selector — the box's **root anchor** as the primary label ("root on low E ·
    /// fret 5", ADR 0091), the two extended fingerings for the diagonal, or a pattern number for
    /// 3-notes-per-string. The flagship box (root on the low E) carries a "Most common" badge, and the
    /// stepper spans the row so the longer anchor label has room.
    private var positionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                EditorFieldLabel(run.layout == .extended ? "Shape" : "Position")
                if run.isMostCommon(for: instrument) { MostCommonBadge(tint: tint) }
                Spacer()
            }
            EditorStepper(value: run.positionLabel(for: instrument), width: .expanding,
                          canGoDown: run.position > 1,
                          canGoUp: run.position < run.positionCount(for: instrument),
                          tint: tint,
                          stepDown: { setPosition(run.position - 1) },
                          stepUp: { setPosition(run.position + 1) })
        }
    }

    private var octavesRow: some View {
        LabeledMenuRow(label: "Octaves") {
            Picker("Octaves", selection: octavesBinding) {
                Text("1").tag(1)
                Text("2").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .labelsHidden()
        }
    }

    // MARK: - Edits (rebuild the recipe; its init clamps)

    private func setPosition(_ value: Int) {
        run = rebuilt(position: value)
    }

    private func rebuilt(scale: GuitarScale? = nil, rootPitchClass: Int? = nil,
                         position: Int? = nil, octaves: Int? = nil,
                         roundTrip: Bool? = nil, notesPerBeat: Int? = nil,
                         layout: ScaleLayout? = nil, sequence: SequencePattern? = nil,
                         startsFromLowestRoot: Bool? = nil) -> ScaleRun {
        ScaleRun(scale: scale ?? run.scale,
                 rootPitchClass: rootPitchClass ?? run.rootPitchClass,
                 position: position ?? run.position,
                 octaves: octaves ?? run.octaves,
                 roundTrip: roundTrip ?? run.roundTrip,
                 notesPerBeat: notesPerBeat ?? run.notesPerBeat,
                 layout: layout ?? run.layout,
                 sequence: sequence ?? run.sequencePattern,
                 startsFromLowestRoot: startsFromLowestRoot ?? run.startsFromLowestRoot)
    }

    private var lowestRootBinding: Binding<Bool> {
        Binding(get: { run.startsFromLowestRoot },
                set: { run = rebuilt(startsFromLowestRoot: $0); haptic(.light) })
    }

    private var layoutBinding: Binding<ScaleLayout> {
        Binding(get: { run.layout }, set: { run = rebuilt(layout: $0); haptic(.light) })
    }

    private var sequenceBinding: Binding<SequencePattern> {
        Binding(get: { run.sequencePattern }, set: { run = rebuilt(sequence: $0); haptic(.light) })
    }

    private var scaleBinding: Binding<GuitarScale> {
        Binding(get: { run.scale }, set: { run = rebuilt(scale: $0); haptic(.light) })
    }

    private var rootBinding: Binding<Int> {
        Binding(get: { run.rootPitchClass }, set: { run = rebuilt(rootPitchClass: $0); haptic(.light) })
    }

    private var octavesBinding: Binding<Int> {
        Binding(get: { run.octaves }, set: { run = rebuilt(octaves: $0) })
    }

    private var roundTripBinding: Binding<Bool> {
        Binding(get: { run.roundTrip }, set: { run = rebuilt(roundTrip: $0) })
    }

    private var subdivisionBinding: Binding<Int> {
        Binding(get: { run.notesPerBeat }, set: { run = rebuilt(notesPerBeat: $0) })
    }
}

#Preview("Scale run editor") {
    struct Harness: View {
        @State private var run = ScaleRun.aMinorPentatonic
        var body: some View {
            ScaleRunEditor(run: $run)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}

#Preview("Extended pentatonic (diagonal)") {
    struct Harness: View {
        @State private var run = ScaleRun.aMinorPentatonicExtended
        var body: some View {
            ScaleRunEditor(run: $run)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}

#Preview("3 notes per string") {
    struct Harness: View {
        @State private var run = ScaleRun.gMajorThreePerString
        var body: some View {
            ScaleRunEditor(run: $run)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
