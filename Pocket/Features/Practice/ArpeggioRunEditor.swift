import SwiftUI

/// The **arpeggio library editor** (ADR 0065 build 2, Slice 3) — the arpeggio sibling of
/// `ScaleRunEditor`. Arpeggios are *picked*, not placed: choose a **quality** (major, minor, maj7,
/// min7, dominant 7), a **root**, a **position** (one of the five CAGED boxes), and **octaves**, and
/// the generator lays the chord-tone box out and walks it. A live preview shows the run before it's
/// saved; "up and back" and the subdivision (Advanced, default eighths) round it out.
///
/// A thin skin over `ArpeggioRun` — each control rebuilds the bound recipe (whose init clamps the
/// position/octaves), and the preview reads `run.expanded()`; no timing logic here (T5). **T10** —
/// every colour is a semantic `PocketColor` role. Shared chrome lives in `FretboardEditorChrome`.
struct ArpeggioRunEditor: View {
    @Binding var run: ArpeggioRun
    /// The exercise's instrument (ADR 0116) — guitar (default) is byte-identical to before; bass renders a
    /// four-string 2-octave chord-tone box.
    var instrument: Instrument = .guitar
    var tint: Color = PocketColor.practice

    @State private var showsAdvanced = false
    /// Note captions are a global viewing preference shared with the scale editor and the live
    /// practice board; the Display menu that sets it lives in the shared options bar.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    /// Per-note duration matching the preview walk, so Hear stays locked to the highlight (ADR 0097 S3).
    private var secondsPerNote: Double {
        60.0 / Double(FretboardDrillPreview.previewBPM) / Double(max(1, run.notesPerBeat))
    }
    /// The run's notes as MIDI, in playing order — what Hear sounds (no rests in a generated arpeggio).
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
            LabeledMenuRow(label: "Arpeggio") { qualityPicker }
            LabeledMenuRow(label: "Root") {
                RootNotePicker(pitchClass: rootBinding, tint: tint, accessibilityValue: run.rootName)
            }
            if run.positionCount(for: instrument) > 1 { positionRow }
            octavesRow
            Toggle("Up and back", isOn: roundTripBinding)
                .font(.futura(.subheadline, weight: .semibold))
                .tint(tint)
            AdvancedSubdivisionRow(isExpanded: $showsAdvanced, notesPerBeat: subdivisionBinding,
                                   accessibilityLabel: "Arpeggio subdivision", tint: tint)
        }
        .hearStopsOnDisappear()
    }

    // MARK: - Title

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(run.title)
                .font(.futura(.headline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(instrument == .guitar
                 ? "CAGED \(run.shapeLetter) shape · from fret \(run.anchorFret)"
                 : "2 octaves · from fret \(run.anchorFret(for: instrument))")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - Menus

    private var qualityPicker: some View {
        Picker("Arpeggio", selection: qualityBinding) {
            ForEach(ArpeggioQuality.allCases) { quality in Text(quality.displayName).tag(quality) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(tint)
        .accessibilityLabel("Arpeggio quality, \(run.quality.displayName)")
    }

    // MARK: - Position + octaves

    /// The box's **root anchor** as the primary label (ADR 0091), the flagship box (root on the low E)
    /// badged "Most common"; the CAGED letter is demoted to the subtitle caption above. The stepper
    /// spans the row so the longer anchor label has room.
    private var positionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                EditorFieldLabel("Position")
                if run.isMostCommon(for: instrument) { MostCommonBadge(tint: tint) }
                Spacer()
            }
            EditorStepper(value: run.positionLabel(for: instrument), width: .expanding,
                          canGoDown: run.position > 1,
                          canGoUp: run.position < run.positionCount(for: instrument),
                          tint: tint,
                          stepDown: { run = rebuilt(position: run.position - 1) },
                          stepUp: { run = rebuilt(position: run.position + 1) })
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
