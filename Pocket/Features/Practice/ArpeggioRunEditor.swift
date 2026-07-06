import SwiftUI

/// The **arpeggio library editor** (ADR 0065 build 2, Slice 3) — the arpeggio sibling of
/// `ScaleRunEditor`. Arpeggios are *picked*, not placed: choose a **quality** (major, minor, maj7,
/// min7, dominant 7), a **root**, a **position** (one of the five CAGED boxes), and **octaves**, and
/// the generator lays the chord-tone box out and walks it. A live preview shows the run before it's
/// saved; "up and back" and the subdivision (Advanced, default eighths) round it out.
///
/// A thin skin over `ArpeggioRun` — each control rebuilds the bound recipe (whose init clamps the
/// position/octaves), and the preview reads `run.expanded()`; no timing logic here (T5). **T10** —
/// every colour is a semantic `PocketColor` role.
struct ArpeggioRunEditor: View {
    @Binding var run: ArpeggioRun
    var tint: Color = PocketColor.practice

    @State private var showsAdvanced = false
    /// Note captions + animation are global viewing preferences shared with the scale editor and the
    /// live practice board.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    @AppStorage(AppSettings.Key.exerciseAnimates) private var animates = false

    /// Root notes in menu order, starting at A (pitch classes, A = 9 … G# = 8).
    private static let noteOrder = [9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8]
    private static let subdivisions: [(perBeat: Int, label: String)] =
        [(1, "Quarters"), (2, "Eighths"), (3, "Triplets"), (4, "Sixteenths")]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            displayOptionsControl
            FretboardDrillPreview(drill: run.expanded(), tint: tint, labelMode: labelMode)
            titleField
            menuRow(label: "Arpeggio", picker: AnyView(qualityPicker))
            menuRow(label: "Root", picker: AnyView(rootPicker))
            positionRow
            octavesRow
            Toggle("Up and back", isOn: roundTripBinding)
                .font(.futura(.subheadline, weight: .semibold))
                .tint(tint)
            advanced
        }
    }

    // MARK: - Display options (labels + animation, global preferences)

    private var displayOptionsControl: some View {
        HStack {
            SoundPreviewButton(drill: run.expanded(), tint: tint)
            Spacer()
            Menu {
                Picker("Labels", selection: $storedLabelMode) {
                    ForEach(FretLabelMode.allCases) { mode in
                        Text(mode.pickerLabel).tag(mode.rawValue)
                    }
                }
                Toggle("Animate", isOn: $animates)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Display")
                }
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(tint)
            }
            .accessibilityLabel("Display options: labels \(labelMode.pickerLabel), "
                                + "animation \(animates ? "on" : "off")")
        }
    }

    // MARK: - Title

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(run.title)
                .font(.futura(.headline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text("Position \(run.position) of \(run.positionCount) · anchored at fret \(run.anchorFret)")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - Menus

    private func menuRow(label: String, picker: AnyView) -> some View {
        HStack {
            fieldLabel(label)
            Spacer()
            picker
        }
    }

    private var qualityPicker: some View {
        Picker("Arpeggio", selection: qualityBinding) {
            ForEach(ArpeggioQuality.allCases) { quality in Text(quality.displayName).tag(quality) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(tint)
        .accessibilityLabel("Arpeggio quality, \(run.quality.displayName)")
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

    private var positionRow: some View {
        HStack {
            fieldLabel("Position")
            Spacer()
            stepper(value: "\(run.position)",
                    canGoDown: run.position > 1,
                    canGoUp: run.position < run.positionCount,
                    stepDown: { run = rebuilt(position: run.position - 1) },
                    stepUp: { run = rebuilt(position: run.position + 1) })
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
            .accessibilityLabel("Arpeggio subdivision")
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

    private func rebuilt(quality: ArpeggioQuality? = nil, rootPitchClass: Int? = nil,
                         position: Int? = nil, octaves: Int? = nil,
                         roundTrip: Bool? = nil, notesPerBeat: Int? = nil) -> ArpeggioRun {
        ArpeggioRun(quality: quality ?? run.quality,
                    rootPitchClass: rootPitchClass ?? run.rootPitchClass,
                    position: position ?? run.position,
                    octaves: octaves ?? run.octaves,
                    roundTrip: roundTrip ?? run.roundTrip,
                    notesPerBeat: notesPerBeat ?? run.notesPerBeat)
    }

    private var qualityBinding: Binding<ArpeggioQuality> {
        Binding(get: { run.quality }, set: { run = rebuilt(quality: $0); haptic(.light) })
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

#Preview("Arpeggio run editor") {
    struct Harness: View {
        @State private var run = ArpeggioRun.aMinorSeventh
        var body: some View {
            ArpeggioRunEditor(run: $run)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
