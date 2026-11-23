import SwiftData
import SwiftUI

/// The **Triads** editor (ADR 0313 D2, D5, D6, D10): the Arpeggios exercise's second shape, beside the
/// box. Pick a key, three strings, where the chords come from, and where on the neck they're played; the
/// board walks the shapes the finder chose. A thin skin over `TriadRun`, which decides every shape.
///
/// **Rows, not one stack** (ADR 0293 D1), for the reason `ArpeggioRunEditor` gives: opening Advanced, or
/// the rows a choice adds (the progression menu, the frets, the range help), inserts rows instead of
/// re-measuring the one that holds the every-frame preview.
///
/// **A range that can't hold a chord isn't refused** (D6). The editor names the chord with no shape and
/// offers the nearest ranges that hold them all; Save stays on. **T10** — every colour is a `PocketColor`
/// role.
struct TriadRunEditor: View {
    @Binding var run: TriadRun
    var tint: Color = PocketColor.practice
    /// The exercise's bar: a progression's chords hold for their bars of it (D4).
    var beatsPerBar: Int = 4

    /// The progressions the player wrote, for the Progression menu (D5). Copied in when chosen.
    @Query(sort: \SavedProgression.createdAt, order: .reverse) private var savedProgressions: [SavedProgression]
    @State private var showsAdvanced = false
    /// Note captions are the global viewing preference the other fretboard editors share.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    /// The key spells chords and notes first; this decides only where it's silent (ADR 0123).
    @AppStorage(AppSettings.Key.accidentalPreference) private var accidentalRaw = NoteSpelling.default.rawValue

    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    private var preference: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }

    var body: some View {
        Group {
            previewRow
            Group {
                titleField
                keyRow
                stackedRow("Strings") { stringsPicker }
                stackedRow("Chords") { sourcePicker }
                if run.playedProgression != nil { progressionRow }
                stackedRow("Where") { placementPicker }
                if run.placement == .stayInFrets {
                    fretsRow
                    let missing = run.chordsWithNoShape(preference: preference)
                    if !missing.isEmpty { rangeHelp(missing: missing) }
                }
                EditorDisclosureHeader(title: "Advanced", isExpanded: $showsAdvanced,
                                       summaryParts: advancedSummary, tint: tint)
                if showsAdvanced { advancedRows }
            }
            .editorRowInsets()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// The board row, worked out once per change to the run: the shape finder runs here, not each time the
    /// chord being played changes (`TriadPreviewRow`).
    private var previewRow: some View {
        TriadPreviewRow(drill: run.expanded(beatsPerBar: beatsPerBar), chips: run.chips(preference: preference),
                        tint: tint, labelMode: labelMode)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(run.title(preference: preference))
                .font(.futura(.headline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(run.caption(preference: preference))
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    /// A field label over a control that wants the row's whole width.
    private func stackedRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(label)
            control()
        }
    }

    // MARK: - Key, strings, chords, where

    /// The tonic, and major or minor. A progression reads its own major or minor (D5), so with one chosen
    /// the segment shows the progression's reading and doesn't take a tap.
    private var keyRow: some View {
        LabeledMenuRow(label: "Key") {
            HStack(spacing: 10) {
                RootNotePicker(pitchClass: binding(\.tonic), tint: tint,
                               accessibilityValue: run.key.tonicName(preference: preference),
                               name: { rootName(pitchClass: $0) })
                Picker("Major or minor", selection: minorBinding) {
                    Text("Major").tag(false)
                    Text("Minor").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
                .disabled(run.playedProgression != nil)
                .accessibilityLabel(run.playedProgression == nil
                                    ? "Major or minor" : "Major or minor, set by the progression")
            }
        }
    }

    /// How a candidate tonic reads if it were chosen: spelled by the key it would make (ADR 0123).
    private func rootName(pitchClass: Int) -> String {
        NoteSpelling.forKey(root: pitchClass, relativeMajorSemitones: run.readsAsMinor ? 3 : 0,
                            preference: preference).name(pitchClass: pitchClass)
    }

    private var stringsPicker: some View {
        Picker("Strings", selection: binding(\.strings)) {
            ForEach(TriadStrings.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// One chord, the key's seven, or a progression (D5). *One chord* is named for the chord it plays.
    private var sourcePicker: some View {
        Picker("Chords", selection: sourceBinding) {
            Text("Just \(TriadRun.Chord.keysOwnName(of: run, preference: preference))").tag(TriadRun.Source.oneChord)
            Text("Key\u{2019}s seven").tag(TriadRun.Source.keysSeven)
            Text("Progression").tag(TriadRun.Source.progression)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var placementPicker: some View {
        Picker("Where", selection: binding(\.placement)) {
            ForEach(TriadRun.Placement.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: - The progression (D5)

    /// The menu of built-ins and *My progressions*, and what the chosen one plays. Choosing copies its
    /// chords in, as *Use a progression* does, so a later edit to the progression leaves this run alone.
    private var progressionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                EditorFieldLabel("Progression")
                Spacer(minLength: 8)
                progressionMenu
            }
            Text(progressionHint)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressionMenu: some View {
        Menu {
            Section("Built in") {
                ForEach(ProgressionTemplate.catalog) { template in
                    progressionButton(name: template.displayTitle, detail: template.detail, steps: template.steps)
                }
            }
            let mine = savedProgressions.filter { !$0.steps.isEmpty }
            if !mine.isEmpty {
                Section("My progressions") {
                    ForEach(mine) { saved in
                        progressionButton(name: saved.name, detail: saved.steps.numerals, steps: saved.steps)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(run.playedProgression?.name ?? "")
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .font(.futura(.subheadline))
            .foregroundStyle(tint)
        }
        .accessibilityLabel("Progression")
        .accessibilityValue(run.playedProgression?.name ?? "")
    }

    private func progressionButton(name: String, detail: String, steps: [ProgressionStep]) -> some View {
        let candidate = TriadRun.Progression(name: name, steps: steps)
        return Button {
            run.progression = candidate
            haptic(.light)
        } label: {
            if run.progression == candidate {
                Label(name, systemImage: "checkmark")
            } else {
                Text(name)
            }
            Text(detail)
        }
    }

    /// "C, G, Am, F. Major, from the progression. Change the key to move it."
    private var progressionHint: String {
        var names: [String] = []
        for chord in run.chords(preference: preference) where !names.contains(chord.name) { names.append(chord.name) }
        let reading = run.readsAsMinor ? "Minor" : "Major"
        return "\(names.joined(separator: ", ")). \(reading), from the progression. Change the key to move it."
    }
}

// MARK: - The board row

/// Watch · Display over the walking board, as one row (see `ScaleRunEditor.previewRow`), with the chord
/// under the hand named at its head and the run's chords in order under it (D8).
///
/// **It owns the chord being played**, so a chord change redraws this row alone. While the editor held it,
/// every change re-ran the editor's whole body, and with it the shape finder three times (the board, the
/// chips and the caption), which is at its slowest for a progression up the neck.
private struct TriadPreviewRow: View {
    let drill: FretboardDrill
    let chips: [TriadChip]
    let tint: Color
    let labelMode: FretLabelMode

    /// A one-shot "watch it" request, set by the options bar's Watch (ADR 0065).
    @State private var playOnceToken: Date?
    /// The chord under the hand, which the board reports so the line above it and the chips can name it.
    @State private var playingChord: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                DrillChordLine(drill: drill, chord: playingChord).layoutPriority(1)
                FretboardDisplayOptionsBar(playToken: $playOnceToken, tint: tint)
            }
            FretboardDrillPreview(drill: drill, tint: tint, labelMode: labelMode, playOnceToken: playOnceToken,
                                  playingChord: $playingChord)
            TriadChipStrip(chips: chips, playing: playingChord)
        }
    }
}

// MARK: - Frets and the range help (Advanced and the bindings are in TriadRunEditor+Advanced.swift)

private extension TriadRunEditor {
    // MARK: - Frets (D6)

    /// The two frets the chords stay between, each set on its own.
    var fretsRow: some View {
        let width = run.highFret - run.lowFret + 1
        return HStack(spacing: 6) {
            EditorFieldLabel("Frets")
            Spacer(minLength: 6)
            fretStepper(label: "From fret", value: run.lowFret,
                        canGoDown: run.lowFret > 0 && width < TriadRun.maxFretSpan,
                        canGoUp: width > TriadRun.minFretSpan,
                        step: { setRange(low: run.lowFret + $0, high: run.highFret) })
            Text("to")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            fretStepper(label: "To fret", value: run.highFret,
                        canGoDown: width > TriadRun.minFretSpan,
                        canGoUp: run.highFret < TriadShapes.maxFret && width < TriadRun.maxFretSpan,
                        step: { setRange(low: run.lowFret, high: run.highFret + $0) })
        }
    }

    /// A stepper VoiceOver reads as one adjustable fret, since two bare pairs of chevrons in a row don't
    /// say which end they move.
    func fretStepper(label: String, value: Int, canGoDown: Bool, canGoUp: Bool,
                     step: @escaping (Int) -> Void) -> some View {
        EditorStepper(value: "\(value)", canGoDown: canGoDown, canGoUp: canGoUp, tint: tint,
                      stepDown: { step(-1) }, stepUp: { step(1) })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue("\(value)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if canGoUp { step(1) }
                case .decrement: if canGoDown { step(-1) }
                @unknown default: break
                }
            }
    }

    func setRange(low: Int, high: Int) {
        (run.lowFret, run.highFret) = TriadRun.clampedRange(low: low, high: high)
    }

    /// The chord with no shape, named, and the nearest ranges that hold every chord (D6).
    func rangeHelp(missing: [String]) -> some View {
        let list = missing.count == 1 ? missing[0]
            : missing.dropLast().joined(separator: ", ") + " or " + (missing.last ?? "")
        let fixes = run.rangesThatHoldEveryChord()
        return VStack(alignment: .leading, spacing: 8) {
            Text("No shape for **\(list)** between frets \(run.lowFret) and \(run.highFret) on \(run.strings.label).")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !fixes.isEmpty {
                Text(holdsLabel)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                HStack(spacing: 8) {
                    ForEach(fixes, id: \.lowerBound) { range in
                        Button("Frets \(range.lowerBound)–\(range.upperBound)") {
                            setRange(low: range.lowerBound, high: range.upperBound)
                            haptic(.light)
                        }
                        .font(.futura(.subheadline, weight: .semibold))
                        .buttonStyle(.bordered)
                        .tint(tint)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.12)))
    }

    var holdsLabel: String {
        if run.playedProgression != nil { return "These hold every chord:" }
        return run.source == .oneChord ? "These hold it:" : "These hold all seven:"
    }
}

#Preview("Triads editor") {
    struct Harness: View {
        @State private var run = TriadRun.starter
        var body: some View {
            Form { Section { TriadRunEditor(run: $run) } }
        }
    }
    return Harness()
        .modelContainer(for: SavedProgression.self, inMemory: true)
        .preferredColorScheme(.dark)
}
