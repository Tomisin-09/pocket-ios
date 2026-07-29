import SwiftUI

/// The **opt-in tracing guide** for `FretboardDrillEditor` (ADR 0107) — split into its own file so the
/// editor stays under the file-length ceiling. A reference + key picker ghosts a `ScaleReference`'s notes
/// on the placement board so a player traces and taps them: scales on the Scales canvas (incl. the
/// symmetric ones the box generator can't produce), or chord tones on the Arpeggios canvas, per the
/// editor's `guideCatalog`. Purely a drawing aid: nothing snaps, the player still places each note by hand.
extension FretboardDrillEditor {
    /// A reference picker (Off + the editor's `guideCatalog` — scales, or the arpeggio chord-tone shapes)
    /// and, once one is chosen, a key picker. Setting them ghosts the reference's notes on the board below.
    var guideControls: some View {
        HStack(spacing: 10) {
            Text("Guide")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Menu {
                Button("Off") { referenceScale = nil }
                Divider()
                ForEach(guideCatalog) { reference in
                    Button(reference.name) { referenceScale = reference }
                }
            } label: {
                guideMenuLabel(referenceScale?.name ?? "Off")
            }
            if referenceScale != nil {
                Menu {
                    ForEach(0..<12, id: \.self) { pitchClass in
                        Button(guideSpelling.name(pitchClass: pitchClass)) {
                            referenceRoot = pitchClass
                        }
                    }
                } label: {
                    guideMenuLabel("Key: \(guideSpelling.name(pitchClass: referenceRoot))")
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
