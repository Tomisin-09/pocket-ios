import SwiftUI

// **Chords on the neck** (ADR 0227 D4): the *Chords* switch, which turns a tap from "replace the note"
// into "one note per string", the rule the My chords placer already uses, so a double-stop, a triad and a
// six-string chord are the same gesture. With it on, the player's saved shapes drop onto the tap in one
// go. Split out for file length.
extension NameTheNotesSheet {

    var chordsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $chordsOn) {
                Text("Chords")
                    .font(.futura(.subheadline))
            }
            .tint(PocketColor.practice)
            if chordsOn {
                Text("Tap other strings to build a chord, one note per string, as in My chords. Tap a note "
                     + "twice to take it out. Bend and vibrato go on the ringed note.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !stamps.isEmpty {
                    pickerLabel("From My chords")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(stamps, id: \.uid) { chord in stampButton(chord) }
                        }
                    }
                }
            }
        }
    }

    /// My chords' shapes that fit this neck. Guitar only for now: bass has no stamps (0227 D4).
    private var stamps: [SavedChord] {
        guard tuning.instrument == .guitar else { return [] }
        return savedChords.filter { $0.voicing.frets.count == tuning.openMidi.count }
    }

    private func stampButton(_ chord: SavedChord) -> some View {
        let frets = chord.voicing.frets
        return Button {
            stamp(frets)
        } label: {
            VStack(spacing: 1) {
                Text(chord.name)
                    .font(.futura(.subheadline, weight: .bold))
                    .lineLimit(1)
                Text(Self.gripText(frets))
                    .font(.pocketMono(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 52, minHeight: 44)
            .foregroundStyle(PocketColor.textPrimary)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PocketColor.surfaceSubtle))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(PocketColor.surfaceBorder))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Place \(chord.name) here")
    }

    /// Drop a saved shape onto the tap being named. The player then moves any note the recording voices
    /// differently. A stamp is a fresh placing, so it carries no join.
    private func stamp(_ frets: [Int?]) {
        guard let label = NeckPlacement.stamp(frets: frets) else { return }
        replacing = nil
        labels[active] = label
        ringed = label.frettedNotes.last?.string
        neckTarget = Self.fret(of: label)
    }

    /// A grip as players write it, lowest string first, `x` for a muted string: "x02210". Frets past 9
    /// are dashed apart so "10" can't read as "1" and "0".
    nonisolated static func gripText(_ frets: [Int?]) -> String {
        let cells = frets.reversed().map { $0.map(String.init) ?? "x" }
        return cells.joined(separator: frets.contains { ($0 ?? 0) > 9 } ? "-" : "")
    }
}
