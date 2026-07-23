import SwiftUI

/// The **opt-in scale-tracing guide** for `FretboardDrillEditor` (ADR 0107) — split into its own file so
/// the editor stays under the file-length ceiling. A scale + key picker ghosts a `ScaleReference`'s notes
/// on the placement board (incl. the symmetric scales the box generator can't produce) so a player traces
/// and taps them. Purely a drawing aid: nothing snaps, the player still places each note by hand.
extension FretboardDrillEditor {
    /// A scale picker (Off + the full `ScaleReference` catalog) and, once a scale is chosen, a key picker.
    /// Setting them ghosts the scale on the board below.
    var guideControls: some View {
        HStack(spacing: 10) {
            Text("Guide")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Menu {
                Button("Off") { referenceScale = nil }
                Divider()
                ForEach(ScaleReference.all) { reference in
                    Button(reference.name) { referenceScale = reference }
                }
            } label: {
                guideMenuLabel(referenceScale?.name ?? "Off")
            }
            if referenceScale != nil {
                Menu {
                    ForEach(0..<12, id: \.self) { pitchClass in
                        Button(GuitarScale.noteName(forPitchClass: pitchClass)) {
                            referenceRoot = pitchClass
                        }
                    }
                } label: {
                    guideMenuLabel("Key: \(GuitarScale.noteName(forPitchClass: referenceRoot))")
                }
            }
            Spacer()
        }
        .tint(PocketColor.practice)
        .accessibilityElement(children: .contain)
    }

    func guideMenuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
        }
        .font(.futura(.caption, weight: .semibold))
        .foregroundStyle(PocketColor.practice)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PocketColor.surfaceSubtle, in: Capsule())
    }
}
