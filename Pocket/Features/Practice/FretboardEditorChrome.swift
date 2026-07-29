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
/// `perBeat == 1` reads "Quarters", because a run's density is a musical, not a click-count, choice —
/// which is exactly what `NoteRate` models, so the **labels come from there** and the editors' Rhythm
/// dropdown, the library rows and the detail sheet can't drift into three vocabularies.
enum FretboardSubdivisions {
    /// The four authored options, in increasing density — what the Rhythm dropdown lists.
    static let options: [(perBeat: Int, label: String)] =
        [NoteRate.quarters, .eighths, .triplets, .sixteenths].map { ($0.perBeat, $0.label) }

    /// The label for a notes-per-beat value. A value outside the table (only reachable from a decoded
    /// blob) describes itself — "6 per beat" — rather than being mislabelled as one of the four.
    static func label(forPerBeat perBeat: Int) -> String {
        NoteRate(perBeat: perBeat).label
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
    /// Whether this surface's drill names a tonal centre. `false` hides the **Interval** caption mode,
    /// which needs `FretboardDrill.rootPitchClass` and silently draws nothing without one — conditioned
    /// here, once, so a future rootless editor is covered without touching it (device feedback 2026-07-28).
    var hasRoot: Bool = true

    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode {
        (FretLabelMode(rawValue: storedLabelMode) ?? .none).resolved(hasRoot: hasRoot)
    }

    /// Reads the *resolved* mode so the picker never selects a hidden row (an inherited `.interval` on a
    /// rootless board shows as Off), but writes the raw choice straight to the global preference.
    private var labelModeBinding: Binding<String> {
        Binding(get: { labelMode.rawValue }, set: { storedLabelMode = $0 })
    }

    var body: some View {
        HStack(spacing: 16) {
            FretboardHearButton(notes: heardNotes, secondsPerNote: secondsPerNote,
                                playToken: $playToken, tint: tint)
            FretboardPlayOnceButton(playToken: $playToken, tint: tint)
            Spacer()
            Menu {
                Picker("Labels", selection: labelModeBinding) {
                    ForEach(FretLabelMode.available(hasRoot: hasRoot)) { mode in
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

/// A ‹ › stepper row shared by the run editors. `.expanding` centres a long value between the controls
/// (the scale/arpeggio root-anchor label, "Root on low E · Fret 5", ADR 0091); `.compact` keeps a
/// short numeric value snug against them (the picking-run's base fret / shift counts). Both fire a
/// light haptic on each step.
///
/// The arrows are **chevrons**, not ∓: minus/plus read as "remove/add a thing" rather than "move
/// through a list of positions", which is what these actually do (device feedback 2026-07-28). Note the
/// stepper is shared by all four fretboard editors, so this lands on every one of them — deliberately,
/// since the same misreading applies to the base-fret and shift counts.
struct EditorStepper: View {
    enum Width { case expanding, compact }

    let value: String
    var width: Width = .compact
    let canGoDown: Bool
    let canGoUp: Bool
    var tint: Color = PocketColor.practice
    let stepDown: () -> Void
    let stepUp: () -> Void

    /// Tap target for the bare chevrons — the glyph itself is far smaller than the old filled circles,
    /// so the hit area is set explicitly rather than left to the glyph's bounds.
    private static let arrowHitSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 14) {
            arrow("chevron.left", enabled: canGoDown, action: stepDown)
            if width == .expanding { Spacer(minLength: 12) }
            valueText
            if width == .expanding { Spacer(minLength: 12) }
            arrow("chevron.right", enabled: canGoUp, action: stepUp)
        }
        .font(.title3)
        .tint(tint)
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); haptic(.light) } label: {
            Image(systemName: symbol)
                .fontWeight(.semibold)
                .frame(width: Self.arrowHitSize, height: Self.arrowHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
    }

    @ViewBuilder private var valueText: some View {
        switch width {
        case .expanding:
            // Futura, not the monospace used for numeric readouts: this slot carries prose ("Root on
            // low E · Fret 10"), and mono made it read like code rather than a place on the neck.
            Text(value).font(.futura(.body, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .multilineTextAlignment(.center)
        case .compact:
            Text(value).font(.pocketMono(.body)).frame(minWidth: 28)
                .foregroundStyle(PocketColor.textPrimary)
        }
    }
}

// MARK: - Root-note picker (scale + arpeggio)

/// The root-note menu shared by the scale and arpeggio editors — pitch classes in menu order from A.
/// Each entry is named by `name`, which the editor supplies so a root reads the way the run it would
/// make reads: the scale/quality already chosen decides the spelling for each candidate root, and only
/// where that key declines (C, F♯/G♭) does the accidental preference show through (ADR 0123). The
/// default keeps a caller that supplies nothing on the sharp reading.
struct RootNotePicker: View {
    @Binding var pitchClass: Int
    var tint: Color = PocketColor.practice
    /// The current root's name, for VoiceOver ("Root note, C♯").
    let accessibilityValue: String
    /// How to name a candidate root pitch class.
    var name: (Int) -> String = { NoteSpelling.default.name(pitchClass: $0) }

    /// Root notes in menu order, starting at A (pitch classes, A = 9 … G♯ = 8).
    private static let noteOrder = [9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8]

    var body: some View {
        Picker("Root", selection: $pitchClass) {
            ForEach(Self.noteOrder, id: \.self) { pitchClass in
                Text(name(pitchClass)).tag(pitchClass)
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

// MARK: - Disclosure (Advanced / Movement)

/// A named, collapsed-by-default disclosure carrying a terse summary of what's inside, so a run's
/// settings are legible without opening it. Its title is an `EditorFieldLabel` — the same component
/// every other setting row uses — because the hand-rolled title it replaced rendered a shade lighter
/// and read as secondary chrome next to the controls it governs (device feedback 2026-07-28).
///
/// **"Advanced" means one thing** (triage decision, 2026-07-28): each editor has at most one
/// disclosure by that name. The picking editor's second group is named **Movement** and uses this
/// same shell, so the two read as siblings rather than as two flavours of "advanced".
struct EditorDisclosure<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    /// What's on inside, one item per setting that deviates from its default — spelled out for the
    /// first couple and counted after that (see `EditorSummary.line`).
    let summaryParts: [String]
    /// What the row reads when nothing deviates ("Off" for Movement; blank for Advanced, whose Rhythm
    /// item is always present).
    var emptyLabel: String = ""
    var tint: Color = PocketColor.practice
    @ViewBuilder let content: Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(.top, 10)
        } label: {
            HStack {
                EditorFieldLabel(title)
                Spacer()
                Text(summaryParts.isEmpty ? emptyLabel : EditorSummary.line(summaryParts))
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
                    // VoiceOver gets the whole list — the "+N" is a *visual* budget, not a decision to
                    // withhold the settings from someone who can't open the row to look.
                    .accessibilityLabel(summaryParts.isEmpty
                                        ? emptyLabel : summaryParts.joined(separator: ", "))
            }
        }
        .tint(tint)
    }
}

/// The collapsed-disclosure summary line. Spells out the first `limit` items and counts the rest as
/// `+N`, so the row stays one line and legible however many settings deviate — the alternative, letting
/// it truncate mid-word, hid *that* there was more as well as what (2026-07-28). The count is the
/// affordance: it says the row is holding something without pretending to list it.
enum EditorSummary {
    static func line(_ parts: [String], showing limit: Int = 2) -> String {
        guard limit > 0 else { return parts.isEmpty ? "" : "+\(parts.count)" }
        guard parts.count > limit else { return parts.joined(separator: " · ") }
        return parts.prefix(limit).joined(separator: " · ") + " +\(parts.count - limit)"
    }
}

// MARK: - Rhythm

/// The note-density control, **renamed from "Subdivision" to "Rhythm"** and demoted from a segmented
/// control to a dropdown (2026-07-28): "subdivision" is engine vocabulary, and four segments ate a
/// full row inside a disclosure that now holds several settings. Lives inside `EditorDisclosure`;
/// the custom-drill editor keeps its own inline picker, because changing it there re-grids the drill.
struct RhythmRow: View {
    @Binding var notesPerBeat: Int
    let accessibilityLabel: String
    var tint: Color = PocketColor.practice

    var body: some View {
        LabeledMenuRow(label: "Rhythm") {
            Picker("Rhythm", selection: $notesPerBeat) {
                ForEach(FretboardSubdivisions.options, id: \.perBeat) { option in
                    Text(option.label).tag(option.perBeat)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(tint)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(FretboardSubdivisions.label(forPerBeat: notesPerBeat))
        }
    }
}
