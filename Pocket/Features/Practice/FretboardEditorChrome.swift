import SwiftUI

// Shared UI chrome for the fretboard-family editors (scale, arpeggio, picking-run, custom-drill).
// These four editors grew as siblings and hand-repeated the same header row, field labels, steppers,
// subdivision table and root-note picker; this file is the one home for those pieces so a fifth
// editor is cheap and a tweak lands everywhere at once. Nothing here holds timing logic — it's pure
// presentation over bindings the editors already own.

// MARK: - Hear lifecycle

extension View {
    /// Silence the shared `ToneEngine` when the view leaves the screen, so a Hear preview never keeps
    /// ringing after its editor (or chord sheet) is dismissed. Replaces a hand-repeated
    /// `.onDisappear { ToneEngine.shared.stop() }` across every Hear surface (ADR 0097).
    func hearStopsOnDisappear() -> some View {
        onDisappear { ToneEngine.shared.stop() }
    }
}

// MARK: - Subdivisions (shared table + label)

/// The note-density options the generative/fretboard editors offer, mapped to notes-per-beat. Distinct
/// from `Subdivision` (the metronome's sub-beat click model, whose `perBeat == 1` reads "None"); here
/// `perBeat == 1` reads "Quarters", because a run's density is a musical, not a click-count, choice.
enum FretboardSubdivisions {
    static let options: [(perBeat: Int, label: String)] =
        [(1, "Quarters"), (2, "Eighths"), (3, "Triplets"), (4, "Sixteenths")]

    /// The label for a notes-per-beat value, defaulting to "Eighths" (the editors' own default) for any
    /// value outside the table.
    static func label(forPerBeat perBeat: Int) -> String {
        options.first { $0.perBeat == perBeat }?.label ?? "Eighths"
    }
}

// MARK: - Display options bar (Hear · Watch · Display)

/// The header row every fretboard-family editor carries: **Hear** (sound the run, locked to the
/// walking highlight), **Watch** (a one-shot walk-through when the board isn't already animating), and
/// a **Display** menu for the note-caption mode. Owns the caption preference through `@AppStorage` so
/// the menu label stays correct; each editor reads the same key for its own preview, and SwiftUI keeps
/// the two in step.
struct FretboardDisplayOptionsBar: View {
    /// The run's notes as MIDI in playing order (a `nil` entry is a rest) — what Hear sounds.
    let heardNotes: [Int?]
    /// Seconds per note on the preview walk, so tone and highlight advance together (ADR 0097 S3/S4).
    let secondsPerNote: Double
    /// The shared one-shot token — Hear and Watch both set it to restart the synced walk from note 0.
    @Binding var playToken: Date?
    var tint: Color = PocketColor.practice

    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    var body: some View {
        HStack(spacing: 16) {
            FretboardHearButton(notes: heardNotes, secondsPerNote: secondsPerNote,
                                playToken: $playToken, tint: tint)
            FretboardPlayOnceButton(playToken: $playToken, tint: tint)
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
}

// MARK: - Field label

/// A form field's leading label — the semibold Futura subheadline every editor row uses.
struct EditorFieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.futura(.subheadline, weight: .semibold))
            .foregroundStyle(PocketColor.textPrimary)
    }
}

// MARK: - A form row: label + trailing control

/// A form row: a field label on the left, a trailing control (usually a menu picker) on the right.
/// Generic over the trailing view, so callers pass the picker directly without `AnyView` erasure.
struct LabeledMenuRow<Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            EditorFieldLabel(label)
            Spacer()
            trailing
        }
    }
}

// MARK: - Stepper

/// A ∓ stepper row shared by the run editors. `.expanding` centres a long value between the controls
/// (the scale/arpeggio root-anchor label, "root on low E · fret 5", ADR 0091); `.compact` keeps a
/// short numeric value snug against them (the picking-run's base fret / shift counts). Both fire a
/// light haptic on each step.
struct EditorStepper: View {
    enum Width { case expanding, compact }

    let value: String
    var width: Width = .compact
    let canGoDown: Bool
    let canGoUp: Bool
    var tint: Color = PocketColor.practice
    let stepDown: () -> Void
    let stepUp: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button { stepDown(); haptic(.light) } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .disabled(!canGoDown)
            if width == .expanding { Spacer(minLength: 12) }
            valueText
            if width == .expanding { Spacer(minLength: 12) }
            Button { stepUp(); haptic(.light) } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .disabled(!canGoUp)
        }
        .font(.title3)
        .tint(tint)
    }

    @ViewBuilder private var valueText: some View {
        switch width {
        case .expanding:
            Text(value).font(.pocketMono(.body))
                .foregroundStyle(PocketColor.textPrimary)
                .multilineTextAlignment(.center)
        case .compact:
            Text(value).font(.pocketMono(.body)).frame(minWidth: 28)
                .foregroundStyle(PocketColor.textPrimary)
        }
    }
}

// MARK: - Root-note picker (scale + arpeggio)

/// The root-note menu shared by the scale and arpeggio editors — pitch classes in menu order from A,
/// named sharp so the caption agrees with the board (ADR 0086/0091, keyless).
struct RootNotePicker: View {
    @Binding var pitchClass: Int
    var tint: Color = PocketColor.practice
    /// The current root's name, for VoiceOver ("Root note, C#").
    let accessibilityValue: String

    /// Root notes in menu order, starting at A (pitch classes, A = 9 … G# = 8).
    private static let noteOrder = [9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8]

    var body: some View {
        Picker("Root", selection: $pitchClass) {
            ForEach(Self.noteOrder, id: \.self) { pitchClass in
                Text(GuitarScale.noteName(forPitchClass: pitchClass)).tag(pitchClass)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(tint)
        .accessibilityLabel("Root note, \(accessibilityValue)")
    }
}

// MARK: - "Most common" badge (flagship box)

/// A tint capsule flagging the flagship box (ADR 0091) so the common shape reads as the front door
/// without hiding the others. Shared by the scale and arpeggio position rows.
struct MostCommonBadge: View {
    var tint: Color = PocketColor.practice

    var body: some View {
        Text("Most common")
            .font(.futura(.caption, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
            .accessibilityLabel("Most common position")
    }
}

// MARK: - Advanced subdivision disclosure

/// The demoted "Advanced" disclosure holding the subdivision segmented picker — collapsed by default,
/// since eighths suit nearly every run (the ADR 0065 feedback that the picker was confusing up front).
/// Shared by the scale, arpeggio and picking-run editors; the custom-drill editor shows its
/// resolution picker inline instead (re-gridding on change), so it uses only the table above.
struct AdvancedSubdivisionRow: View {
    @Binding var isExpanded: Bool
    @Binding var notesPerBeat: Int
    let accessibilityLabel: String
    var tint: Color = PocketColor.practice

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Picker("Subdivision", selection: $notesPerBeat) {
                ForEach(FretboardSubdivisions.options, id: \.perBeat) { option in
                    Text(option.label).tag(option.perBeat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 6)
            .accessibilityLabel(accessibilityLabel)
        } label: {
            HStack {
                Text("Advanced").font(.futura(.subheadline, weight: .semibold))
                Spacer()
                Text(FretboardSubdivisions.label(forPerBeat: notesPerBeat)).font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .tint(tint)
    }
}
