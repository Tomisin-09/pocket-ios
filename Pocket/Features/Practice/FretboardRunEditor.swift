import SwiftUI

/// The **generative fretboard editor** (ADR 0065 build 2, generative authoring). Instead of placing
/// every note by hand, the player declares the *shape* of a warm-up / picking / legato run and the
/// app expands it: a **finger pattern** (e.g. 1-3-2-4) anchored to a **base fret**, travelling a
/// **string span**, optionally **back**. A live preview walks the resulting run so the shape is
/// visible before it's saved; the subdivision is demoted to an "Advanced" row (default eighths) so
/// the common controls stay uncluttered.
///
/// A thin skin over `FretboardRun` — every control mutates one field of the bound recipe, and the
/// preview reads `run.expanded()`; the view holds no timing logic (T5). **T10** — every colour is a
/// semantic `PocketColor` role, so it reskins under light/dark and any future theme.
struct FretboardRunEditor: View {
    @Binding var run: FretboardRun
    var tint: Color = PocketColor.practice

    /// Whether the demoted subdivision control is revealed — eighths suits nearly every run, so it
    /// starts collapsed (the feedback that the subdivision picker was confusing up front).
    @State private var showsAdvanced = false
    /// Whether the position-shifting controls (ADR 0083) are revealed — off by default so a plain
    /// warm-up stays four taps and the power controls are one tap away.
    @State private var showsMovement = false
    /// The global note-caption preference, so this preview matches the scale editor and practice board.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    /// A one-shot "watch it" request (ADR 0065) — set by `FretboardPlayOnceButton`, read by the
    /// preview below. The walking-highlight preference itself lives only in Settings ("Animate
    /// exercises") now; Watch covers "see it move once" here without a redundant local toggle.
    @State private var playOnceToken: Date?
    /// Per-note duration matching the preview walk, so Hear stays locked to the highlight (ADR 0097 S4).
    private var secondsPerNote: Double {
        60.0 / Double(FretboardDrillPreview.previewBPM) / Double(max(1, run.notesPerBeat))
    }
    /// The run's notes as MIDI, in playing order — what Hear sounds (a generated picking run has no rests).
    private var heardNotes: [Int?] { run.sequence.map { Optional(CAGEDShape.midi($0)) } }

    private static let maxBaseFret = 15
    private static let maxShiftPerPass = 5
    private static let staggerRange = -2...3
    private static let stringOrder = [5, 4, 3, 2, 1, 0]   // low E → high e, as the neck reads
    private static let subdivisions: [(perBeat: Int, label: String)] =
        [(1, "Quarters"), (2, "Eighths"), (3, "Triplets"), (4, "Sixteenths")]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            displayOptionsControl
            FretboardDrillPreview(drill: run.expanded(), tint: tint, labelMode: labelMode,
                                  playOnceToken: playOnceToken)
            patternField
            baseFretField
            spanField
            Toggle("Up and back", isOn: $run.roundTrip)
                .font(.futura(.subheadline, weight: .semibold))
                .tint(tint)
            movement
            advanced
            Text("Set the finger pattern, then where it sits and how far it travels — the run builds "
                 + "itself. Watch it walk above before you save.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .onDisappear { ToneEngine.shared.stop() }
    }

    // MARK: - Display options (labels, global preference)

    /// A compact menu, top of the board, holding how notes are captioned (name / interval / off)
    /// plus Watch — the same row the Scale/Arpeggio editors carry (ADR 0065; the dead "Sound soon"
    /// scaffold was removed in ADR 0077). The walking-highlight preference itself lives only in
    /// Settings now, since Watch already covers "see it move once" here.
    private var displayOptionsControl: some View {
        HStack(spacing: 16) {
            FretboardHearButton(notes: heardNotes, secondsPerNote: secondsPerNote,
                                playToken: $playOnceToken, tint: tint)
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

    // MARK: - Finger pattern

    private var patternField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Finger pattern")
            HStack(spacing: 6) {
                if run.fingers.isEmpty {
                    Text("Tap a finger below").font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    ForEach(Array(run.fingers.enumerated()), id: \.offset) { _, finger in
                        fingerChip(finger)
                    }
                }
                Spacer()
                Button { removeLastFinger() } label: {
                    Image(systemName: "delete.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(PocketColor.textSecondary)
                .disabled(run.fingers.count <= 1)
                .accessibilityLabel("Remove last finger")
            }
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { finger in
                    Button { appendFinger(finger) } label: {
                        Text("\(finger)")
                            .font(.futura(.headline, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: 9)
                                .fill(PocketColor.surfaceSubtle))
                            .foregroundStyle(PocketColor.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add finger \(finger)")
                }
            }
        }
    }

    private func fingerChip(_ finger: Int) -> some View {
        Text("\(finger)")
            .font(.futura(.subheadline, weight: .semibold))
            .foregroundStyle(PocketColor.background)
            .frame(width: 26, height: 26)
            .background(Circle().fill(tint))
            .accessibilityLabel("Finger \(finger), fret \(run.fret(forFinger: finger))")
    }

    // MARK: - Base fret

    private var baseFretField: some View {
        HStack {
            fieldLabel("Starts on fret")
            Spacer()
            stepper(stepDown: { run.baseFret = max(1, run.baseFret - 1) },
                    stepUp: { run.baseFret = min(Self.maxBaseFret, run.baseFret + 1) },
                    value: "\(run.baseFret)",
                    canGoDown: run.baseFret > 1,
                    canGoUp: run.baseFret < Self.maxBaseFret)
        }
    }

    // MARK: - String span

    private var spanField: some View {
        HStack {
            fieldLabel("Across")
            Spacer()
            stringMenu(selection: $run.fromString)
            Image(systemName: "arrow.right")
                .font(.footnote)
                .foregroundStyle(PocketColor.textSecondary)
            stringMenu(selection: $run.toString)
        }
    }

    private func stringMenu(selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(Self.stringOrder, id: \.self) { index in
                Text(stringLabel(index)).tag(index)
            }
        }
        .pickerStyle(.menu)
        .tint(tint)
        .accessibilityLabel("String \(stringLabel(selection.wrappedValue))")
    }

    /// A full string name for the menu (the single-letter board label is too terse in a picker).
    private func stringLabel(_ index: Int) -> String {
        let names = ["high e", "B", "G", "D", "A", "low E"]
        return names.indices.contains(index) ? names[index] : "String \(index + 1)"
    }

    // MARK: - Advanced (subdivision, demoted)

    private var advanced: some View {
        DisclosureGroup(isExpanded: $showsAdvanced) {
            Picker("Subdivision", selection: $run.notesPerBeat) {
                ForEach(Self.subdivisions, id: \.perBeat) { option in
                    Text(option.label).tag(option.perBeat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 6)
            .accessibilityLabel("Fretboard subdivision")
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

    private func stepper(stepDown: @escaping () -> Void, stepUp: @escaping () -> Void,
                         value: String, canGoDown: Bool, canGoUp: Bool) -> some View {
        HStack(spacing: 14) {
            Button { stepDown(); haptic(.light) } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .disabled(!canGoDown)
            Text(value).font(.pocketMono(.body)).frame(minWidth: 28)
                .foregroundStyle(PocketColor.textPrimary)
            Button { stepUp(); haptic(.light) } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .disabled(!canGoUp)
        }
        .font(.title3)
        .tint(tint)
    }

    // MARK: - Edits

    private func appendFinger(_ finger: Int) {
        run.fingers.append(finger)
        haptic(.light)
    }

    private func removeLastFinger() {
        guard run.fingers.count > 1 else { return }
        run.fingers.removeLast()
        haptic(.light)
    }
}

// MARK: - Movement (position-shifting, ADR 0083 — demoted)

/// The ADR 0083 position-shifting controls, split into their own extension so the primary editor
/// body stays lean: climb the neck after each run, stagger the pattern diagonally per string, and —
/// when the run comes back — pick how the descent is fingered. All default off, tucked under a
/// disclosure so the common path stays calm (S3, the ADR 0065 over-busy-editor caution).
extension FretboardRunEditor {
    var movement: some View {
        DisclosureGroup(isExpanded: $showsMovement) {
            VStack(alignment: .leading, spacing: 16) {
                shiftPerPassField
                if run.fretShiftPerPass != 0 { passCountField }
                staggerPerStringField
                if run.roundTrip { returnStyleField }
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Text("Movement").font(.futura(.subheadline, weight: .semibold))
                Spacer()
                Text(movementSummary).font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .tint(tint)
        .onChange(of: run.baseFret) { _, _ in clampPassCount() }
        .onChange(of: run.fretShiftPerPass) { _, _ in clampPassCount() }
        .onChange(of: run.fretShiftPerString) { _, _ in clampPassCount() }
    }

    /// A terse "what's on" read for the collapsed row, so a run's movement is legible without opening.
    private var movementSummary: String {
        var parts: [String] = []
        if run.fretShiftPerPass != 0 {
            parts.append("↑\(run.fretShiftPerPass)/run × \(run.passCount)")
        }
        if run.fretShiftPerString != 0 { parts.append("diag \(signed(run.fretShiftPerString))") }
        if run.roundTrip, run.returnStyle == .restate { parts.append("restate") }
        return parts.isEmpty ? "Off" : parts.joined(separator: " · ")
    }

    private var shiftPerPassField: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                fieldLabel("Shift up after each run")
                Text("Climb the neck a few frets each pass.").font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            stepper(stepDown: { run.fretShiftPerPass = max(0, run.fretShiftPerPass - 1) },
                    stepUp: { run.fretShiftPerPass = min(Self.maxShiftPerPass, run.fretShiftPerPass + 1) },
                    value: run.fretShiftPerPass == 0 ? "Off" : "+\(run.fretShiftPerPass)",
                    canGoDown: run.fretShiftPerPass > 0,
                    canGoUp: run.fretShiftPerPass < Self.maxShiftPerPass)
        }
    }

    private var passCountField: some View {
        HStack {
            fieldLabel("Passes")
            Spacer()
            stepper(stepDown: { run.passCount = max(1, run.passCount - 1) },
                    stepUp: { run.passCount = min(maxPasses, run.passCount + 1) },
                    value: "\(run.passCount)",
                    canGoDown: run.passCount > 1,
                    canGoUp: run.passCount < maxPasses)
        }
    }

    private var staggerPerStringField: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                fieldLabel("Stagger per string")
                Text("Land higher (or lower) on each string — a diagonal.").font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            stepper(stepDown: { run.fretShiftPerString = max(Self.staggerRange.lowerBound,
                                                             run.fretShiftPerString - 1) },
                    stepUp: { run.fretShiftPerString = min(Self.staggerRange.upperBound,
                                                           run.fretShiftPerString + 1) },
                    value: run.fretShiftPerString == 0 ? "Off" : signed(run.fretShiftPerString),
                    canGoDown: run.fretShiftPerString > Self.staggerRange.lowerBound,
                    canGoUp: run.fretShiftPerString < Self.staggerRange.upperBound)
        }
    }

    private var returnStyleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Coming back")
            Picker("Coming back", selection: $run.returnStyle) {
                ForEach(ReturnStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)
            Text(run.returnStyle.caption).font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// The pass count the editor allows — the neck-fit cap (S10) held under the UI ceiling.
    private var maxPasses: Int { min(FretboardRun.passCountUICap, run.maxPassCount) }

    /// Keep `passCount` within the neck-fit cap as the base fret, climb, or stagger change (S10).
    private func clampPassCount() {
        if run.passCount > maxPasses { run.passCount = maxPasses }
    }

    /// A signed fret count for a stagger/shift read (`+2`, `−1`).
    private func signed(_ value: Int) -> String {
        value < 0 ? "−\(abs(value))" : "+\(value)"
    }
}

#Preview("Fretboard run editor") {
    struct Harness: View {
        @State private var run = FretboardRun.chromaticWarmup
        var body: some View {
            FretboardRunEditor(run: $run)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
