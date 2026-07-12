import SwiftUI

/// The **scale library editor** (ADR 0065 build 2, Slice 2). Scales are *picked*, not placed: choose
/// a **scale**, a **root note**, a **position** up the neck, and how many **octaves**, and a
/// notes-per-string generator lays the box out and walks it. A live preview shows the run before it's
/// saved; "up and back" and the subdivision (Advanced, default eighths) round it out.
///
/// A thin skin over `ScaleRun` — each control rebuilds the bound recipe (whose init clamps the
/// position/octaves), and the preview reads `run.expanded()`; no timing logic here (T5). **T10** —
/// every colour is a semantic `PocketColor` role.
struct ScaleRunEditor: View {
    @Binding var run: ScaleRun
    var tint: Color = PocketColor.practice

    @State private var showsAdvanced = false
    /// Note captions are a global viewing preference (ADR 0065) so the board reads the same here and
    /// in the live practice run.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    /// A one-shot "watch it" request (ADR 0065) — set by `FretboardPlayOnceButton`, read by the
    /// preview below. The walking-highlight preference itself lives only in Settings ("Animate
    /// exercises") now; Watch covers "see it move once" here without a redundant local toggle.
    @State private var playOnceToken: Date?

    /// Root notes in menu order, starting at A (pitch classes, A = 9 … G# = 8).
    private static let noteOrder = [9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8]
    private static let subdivisions: [(perBeat: Int, label: String)] =
        [(1, "Quarters"), (2, "Eighths"), (3, "Triplets"), (4, "Sixteenths")]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            labelModeControl
            FretboardDrillPreview(drill: run.expanded(), tint: tint, labelMode: labelMode,
                                  playOnceToken: playOnceToken)
            titleField
            menuRow(label: "Scale", picker: AnyView(scalePicker))
            menuRow(label: "Root", picker: AnyView(rootPicker))
            if run.scale.supportedLayouts.count > 1 { layoutRow }
            positionRow
            if run.layout.usesOctaves { octavesRow }
            Toggle("Up and back", isOn: roundTripBinding)
                .font(.futura(.subheadline, weight: .semibold))
                .tint(tint)
            advanced
        }
    }

    // MARK: - Display options (labels, global preference)

    /// A compact menu, top-right of the board, holding how notes are captioned (name / interval /
    /// off) plus Watch — the walking-highlight preference itself lives only in Settings now, since
    /// Watch already covers "see it move once" here (the dead "Sound soon" scaffold was removed in
    /// ADR 0077).
    private var labelModeControl: some View {
        HStack {
            FretboardPlayOnceButton(playToken: $playOnceToken, tint: tint)
            Spacer()
            Menu {
                Picker("Labels", selection: $storedLabelMode) {
                    ForEach(FretLabelMode.allCases) { mode in
                        Text(mode.pickerLabel).tag(mode.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Display")
                }
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(tint)
            }
            .accessibilityLabel("Display options: labels \(labelMode.pickerLabel)")
        }
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

    /// The box layout reads as a CAGED shape at a position; the neck-spanning layouts name themselves
    /// and just report where they start.
    private var subtitle: String {
        switch run.layout {
        case .box:
            return "\(run.shapeLetter) shape · \(run.position) of \(run.scale.positionCount) · "
                + "fret \(run.anchorFret)"
        case .extended, .threePerString:
            return "\(run.layout.displayName) · from fret \(run.anchorFret)"
        }
    }

    // MARK: - Menus

    private var layoutRow: some View {
        HStack {
            fieldLabel("Layout")
            Spacer()
            Picker("Layout", selection: layoutBinding) {
                ForEach(run.scale.supportedLayouts) { layout in Text(layout.displayName).tag(layout) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(tint)
            .accessibilityLabel("Layout, \(run.layout.displayName)")
        }
    }

    private func menuRow(label: String, picker: AnyView) -> some View {
        HStack {
            fieldLabel(label)
            Spacer()
            picker
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

    private var rootPicker: some View {
        Picker("Root", selection: rootBinding) {
            ForEach(Self.noteOrder, id: \.self) { pitchClass in
                Text(GuitarScale.noteName(forPitchClass: pitchClass)).tag(pitchClass)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(tint)
        .accessibilityLabel("Root note, \(run.rootName)")
    }

    // MARK: - Position + octaves

    /// The neck position selector — shown as a CAGED **shape** (E/D/C/A/G) for the box, the two extended
    /// fingerings for the diagonal, or a pattern number for 3-notes-per-string — never a bare index.
    private var positionRow: some View {
        HStack {
            fieldLabel(run.layout == .extended ? "Shape" : "Position")
            Spacer()
            stepper(value: run.positionLabel,
                    canGoDown: run.position > 1,
                    canGoUp: run.position < run.positionCount,
                    stepDown: { setPosition(run.position - 1) },
                    stepUp: { setPosition(run.position + 1) })
        }
    }

    private var octavesRow: some View {
        HStack {
            fieldLabel("Octaves")
            Spacer()
            Picker("Octaves", selection: octavesBinding) {
                Text("1").tag(1)
                Text("2").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .labelsHidden()
        }
    }

    // MARK: - Advanced (subdivision, demoted)

    private var advanced: some View {
        DisclosureGroup(isExpanded: $showsAdvanced) {
            Picker("Subdivision", selection: subdivisionBinding) {
                ForEach(Self.subdivisions, id: \.perBeat) { option in
                    Text(option.label).tag(option.perBeat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 6)
            .accessibilityLabel("Scale subdivision")
        } label: {
            HStack {
                Text("Advanced").font(.futura(.subheadline, weight: .semibold))
                Spacer()
                Text(subdivisionLabel).font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .tint(tint)
    }

    private var subdivisionLabel: String {
        Self.subdivisions.first { $0.perBeat == run.notesPerBeat }?.label ?? "Eighths"
    }

    // MARK: - Shared bits

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.futura(.subheadline, weight: .semibold))
            .foregroundStyle(PocketColor.textPrimary)
    }

    private func stepper(value: String, canGoDown: Bool, canGoUp: Bool,
                         stepDown: @escaping () -> Void, stepUp: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Button { stepDown(); haptic(.light) } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .disabled(!canGoDown)
            Text(value).font(.pocketMono(.body)).frame(minWidth: 20)
                .foregroundStyle(PocketColor.textPrimary)
            Button { stepUp(); haptic(.light) } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .disabled(!canGoUp)
        }
        .font(.title3)
        .tint(tint)
    }

    // MARK: - Edits (rebuild the recipe; its init clamps)

    private func setPosition(_ value: Int) {
        run = rebuilt(position: value)
    }

    private func rebuilt(scale: GuitarScale? = nil, rootPitchClass: Int? = nil,
                         position: Int? = nil, octaves: Int? = nil,
                         roundTrip: Bool? = nil, notesPerBeat: Int? = nil,
                         layout: ScaleLayout? = nil) -> ScaleRun {
        ScaleRun(scale: scale ?? run.scale,
                 rootPitchClass: rootPitchClass ?? run.rootPitchClass,
                 position: position ?? run.position,
                 octaves: octaves ?? run.octaves,
                 roundTrip: roundTrip ?? run.roundTrip,
                 notesPerBeat: notesPerBeat ?? run.notesPerBeat,
                 layout: layout ?? run.layout)
    }

    private var layoutBinding: Binding<ScaleLayout> {
        Binding(get: { run.layout }, set: { run = rebuilt(layout: $0); haptic(.light) })
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
