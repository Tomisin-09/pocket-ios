import SwiftUI

/// The **generative fretboard editor** (ADR 0065 build 2, generative authoring). Instead of placing
/// every note by hand, the player declares the *shape* of a warm-up / picking / legato run and the
/// app expands it: a **finger pattern** (e.g. 1-3-2-4) anchored to a **base fret**, travelling a
/// **string span**, optionally **back**. A live preview walks the resulting run so the shape is
/// visible before it's saved.
///
/// **It is several Form rows, not one** (ADR 0293). The body is a `Group`, so the `Section` it sits in
/// gets a row per control: opening **Movement** inserts rows rather than resizing one tall row that also
/// holds the preview, whose `TimelineView` redraws every frame. As a single row, every open and close
/// re-measured all of it, and on device the screen looked as if it rebuilt itself. Each row carries its
/// own clear background and hidden separator, so the editor still reads as one surface.
///
/// A thin skin over `FretboardRun` — every control mutates one field of the bound recipe, and the
/// preview reads `run.expanded()`; the view holds no timing logic (T5). **T10** — every colour is a
/// semantic `PocketColor` role, so it reskins under light/dark and any future theme.
struct FretboardRunEditor: View {
    @Binding var run: FretboardRun
    /// The exercise's instrument (ADR 0116) — guitar (default) is unchanged; bass draws four strings and
    /// offers only the four bass strings in the span picker.
    var instrument: Instrument = .guitar
    /// The drill's template, so the preview plays the run the way the drill will (ADR 0251): a Legato
    /// run walks with its hammer-ons and pull-offs. Any template that doesn't articulate shows it plain.
    var template: ExerciseTemplate = .warmup
    var tint: Color = PocketColor.practice

    /// Whether the Movement rows (Up and back, Coming back, ADR 0083's shifts) are revealed. Collapsed by
    /// default so a plain warm-up stays four taps and the power controls are one tap away.
    @State private var showsMovement = false
    /// The global note-caption preference, so this preview matches the scale editor and practice board.
    /// A warm-up run is a pure finger pattern with no tonal centre, so an inherited Interval mode
    /// resolves to Off here rather than drawing nothing at all (2026-07-28).
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode {
        (FretLabelMode(rawValue: storedLabelMode) ?? .none).resolved(hasRoot: false)
    }
    /// A one-shot "watch it" request (ADR 0065) — set by `FretboardPlayOnceButton`, read by the
    /// preview below. The walking-highlight preference itself lives only in Settings ("Animate
    /// exercises") now; Watch covers "see it move once" here without a redundant local toggle.
    @State private var playOnceToken: Date?

    private static let maxBaseFret = 15
    private static let maxShiftPerPass = 5
    private static let staggerRange = -2...3

    var body: some View {
        Group {
            previewRow
            patternField
            baseFretField
            StringSpanStrip(from: $run.fromString, to: $run.toString,
                            instrument: instrument, tint: tint)
            movementHeader
            if showsMovement { movementRows }
            // Rhythm is a plain row now (ADR 0293): with Up and back moved into Movement it was the only
            // thing left under "Advanced", and a disclosure that opens onto one dropdown is two taps for
            // one value that it also printed twice.
            RhythmRow(notesPerBeat: $run.notesPerBeat, accessibilityLabel: "Fretboard rhythm", tint: tint)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Preview

    /// Watch · Display over the walking board — one row, so the other rows coming and going never
    /// re-measure the board that redraws every frame.
    private var previewRow: some View {
        VStack(alignment: .leading, spacing: 18) {
            FretboardDisplayOptionsBar(playToken: $playOnceToken, tint: tint, hasRoot: false)
            FretboardDrillPreview(drill: template.articulating(run.expanded(instrument: instrument)),
                                  tint: tint, labelMode: labelMode, playOnceToken: playOnceToken)
        }
    }

    // MARK: - Finger pattern

    private var patternField: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel("Finger pattern")
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
                // Tinted like every other action on the editor (the Across reverse, the steppers) —
                // they were grey here and terracotta there for the same kind of button (ADR 0293).
                Button { reverseFingers() } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderless)
                .disabled(run.fingers.count < 2)
                .accessibilityLabel("Reverse the finger pattern")
                Button { removeLastFinger() } label: {
                    Image(systemName: "delete.left")
                }
                .buttonStyle(.borderless)
                .disabled(run.fingers.isEmpty)
                .accessibilityLabel("Remove last finger")
            }
            .tint(tint)
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
            EditorFieldLabel("Starts on fret")
            Spacer()
            EditorStepper(value: "\(run.baseFret)",
                          canGoDown: run.baseFret > 1, canGoUp: run.baseFret < Self.maxBaseFret,
                          tint: tint,
                          stepDown: { run.baseFret = max(1, run.baseFret - 1) },
                          stepUp: { run.baseFret = min(Self.maxBaseFret, run.baseFret + 1) })
        }
    }

    // MARK: - Edits

    private func appendFinger(_ finger: Int) {
        run.fingers.append(finger)
        haptic(.light)
    }

    /// Backspace, **clearable to empty**. It used to stop at one finger — and since appending and
    /// removing the last were the only two mutations, that made `fingers[0]` unreachable and pinned
    /// every generated run in the app to the index finger: a descending 4-3-2-1 could only be typed as
    /// 1-4-3-2-1. The empty state is not a valid run, but it *is* a valid step on the way to one, so
    /// the editor allows it and `canCreate` / Done refuse to ship it.
    private func removeLastFinger() {
        guard !run.fingers.isEmpty else { return }
        run.fingers.removeLast()
        haptic(.light)
    }

    /// Flip the pattern end-for-end — 1-2-3-4 becomes 4-3-2-1 in one tap. Descending is the case the
    /// pinned first finger made impossible, and retyping it is eight taps; this is one.
    private func reverseFingers() {
        guard run.fingers.count > 1 else { return }
        run.fingers.reverse()
        haptic(.light)
    }
}

// MARK: - Movement (Up and back + ADR 0083 position shifting)

/// How the run travels once it has a shape: whether it comes back and how, then ADR 0083's climb and
/// stagger. **Up and back lives here** (ADR 0293). Its own follow-on, Coming back, always did, so turning
/// it on under Advanced used to make a control appear in a different group; now the two sit together,
/// Coming back directly under the switch that reveals it. All of it is rows of the editor's `Section`.
extension FretboardRunEditor {
    var movementHeader: some View {
        EditorDisclosureHeader(title: "Movement", isExpanded: $showsMovement,
                               summaryParts: run.movementSummaryParts, tint: tint)
            .onChange(of: run.baseFret) { _, _ in clampPassCount() }
            .onChange(of: run.fretShiftPerPass) { _, _ in clampPassCount() }
            .onChange(of: run.fretShiftPerString) { _, _ in clampPassCount() }
    }

    @ViewBuilder var movementRows: some View {
        Toggle("Up and back", isOn: $run.roundTrip)
            .font(.futura(.subheadline, weight: .semibold))
            .tint(tint)
        if run.roundTrip { returnStyleField.editorDependentRow(tint: tint) }
        shiftPerPassField
        if run.fretShiftPerPass != 0 { passCountField.editorDependentRow(tint: tint) }
        staggerPerStringField
    }

    private var shiftPerPassField: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                EditorFieldLabel("Shift up after each run")
                Text("Climb the neck a few frets each pass.").font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            EditorStepper(value: run.fretShiftPerPass == 0 ? "Off" : "+\(run.fretShiftPerPass)",
                          canGoDown: run.fretShiftPerPass > 0,
                          canGoUp: run.fretShiftPerPass < Self.maxShiftPerPass,
                          tint: tint,
                          stepDown: { run.fretShiftPerPass = max(0, run.fretShiftPerPass - 1) },
                          stepUp: { run.fretShiftPerPass = min(Self.maxShiftPerPass,
                                                               run.fretShiftPerPass + 1) })
        }
    }

    private var passCountField: some View {
        HStack {
            EditorFieldLabel("Passes")
            Spacer()
            EditorStepper(value: "\(run.passCount)",
                          canGoDown: run.passCount > 1, canGoUp: run.passCount < maxPasses,
                          tint: tint,
                          stepDown: { run.passCount = max(1, run.passCount - 1) },
                          stepUp: { run.passCount = min(maxPasses, run.passCount + 1) })
        }
    }

    private var staggerPerStringField: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                EditorFieldLabel("Stagger per string")
                Text("Land higher (or lower) on each string — a diagonal.").font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            EditorStepper(value: run.fretShiftPerString == 0
                            ? "Off" : FretboardRun.signedFrets(run.fretShiftPerString),
                          canGoDown: run.fretShiftPerString > Self.staggerRange.lowerBound,
                          canGoUp: run.fretShiftPerString < Self.staggerRange.upperBound,
                          tint: tint,
                          stepDown: { run.fretShiftPerString = max(Self.staggerRange.lowerBound,
                                                                   run.fretShiftPerString - 1) },
                          stepUp: { run.fretShiftPerString = min(Self.staggerRange.upperBound,
                                                                 run.fretShiftPerString + 1) })
        }
    }

    private var returnStyleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            EditorFieldLabel("Coming back")
            Picker("Coming back", selection: $run.returnStyle) {
                ForEach(ReturnStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)
            Text(run.returnStyle.caption(fingers: run.fingers)).font(.futura(.caption))
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
}

extension FretboardRun {
    /// The collapsed **Movement** row's read (ADR 0293): the path first, always — *Up and back* or *One
    /// way* — then only the settings that differ from their defaults (*restate*, the climb, the stagger).
    ///
    /// The scale editor's Advanced summary leaves *Up and back* out as noise, because there it sits
    /// beside things that say more. Here the path is what Movement is about: with Up and back inside it,
    /// the old empty read, *Off*, would sit on a row whose run still goes up and back.
    var movementSummaryParts: [String] {
        var parts = [roundTrip ? "Up and back" : "One way"]
        if roundTrip, returnStyle == .restate { parts.append("restate") }
        if fretShiftPerPass != 0 { parts.append("↑\(fretShiftPerPass)/run × \(passCount)") }
        if fretShiftPerString != 0 { parts.append("diag \(Self.signedFrets(fretShiftPerString))") }
        return parts
    }

    /// A signed fret count for a stagger/shift read (`+2`, `−1`, with a true minus sign).
    static func signedFrets(_ value: Int) -> String {
        value < 0 ? "−\(abs(value))" : "+\(value)"
    }
}

#Preview("Fretboard run editor") {
    struct Harness: View {
        @State private var run = FretboardRun.chromaticWarmup
        var body: some View {
            // A Form, as in the app: the editor is a run of rows (ADR 0293), and outside a List its
            // `Group` would just stack them with each row's modifiers doing nothing.
            Form {
                Section { FretboardRunEditor(run: $run) }
            }
        }
    }
    return Harness().preferredColorScheme(.dark)
}
