import SwiftUI

/// The reverse-lookup **name suggestions** shown under the custom-chord board (ADR 0093 slice 2). Purely
/// presentational: it's handed the ranked `ChordCandidate`s (from `ChordNamer`) and reports which name the
/// player tapped. Factual and additive — it never gates anything and never says a shape is "wrong"; an
/// empty list reads "No common name", the honest fallback (ADR 0093 N7). Tapping a chip fills the caller's
/// name field, but the player stays the namer of record and can always override.
struct ChordIdentifierPanel: View {
    /// Ranked readings of the shape, best first; empty ⇒ the shape spells no common chord.
    let candidates: [ChordCandidate]
    /// Called with the chosen display name when the player taps a suggestion.
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(candidates.isEmpty ? "No common name" : "Looks like")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            if candidates.isEmpty {
                Text("Name it yourself below.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                            chip(candidate.displayName, tag: candidate.inversionLabel, isPrimary: index == 0)
                        }
                        // When the best reading is an inversion, also offer the plain root-position name,
                        // so a slid triad like "B/F♯" is unmistakably a "B" chord (ADR 0093 N5).
                        if let primary = candidates.first, primary.isInversion {
                            chip(primary.name, tag: nil, isPrimary: false)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A tappable suggestion — the top-ranked reading is filled, the rest outlined. An optional `tag`
    /// (e.g. "2nd inv") rides alongside the name without changing what tapping fills.
    private func chip(_ name: String, tag: String?, isPrimary: Bool) -> some View {
        Button { onPick(name) } label: {
            HStack(spacing: 5) {
                Text(name)
                    .font(.futura(.subheadline, weight: isPrimary ? .bold : .semibold))
                if let tag {
                    Text(tag)
                        .font(.futura(.caption2, weight: .semibold))
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(isPrimary ? PocketColor.practice : PocketColor.practice.opacity(0.14)))
            .foregroundStyle(isPrimary ? .white : PocketColor.practice)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Name this chord \(name)\(tag.map { ", \($0)" } ?? "")")
        .accessibilityHint("Uses this name")
    }
}

#Preview("Identified") {
    ChordIdentifierPanel(candidates: ChordNamer.candidates(for: .cMajor7)) { _ in }
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("No common name") {
    ChordIdentifierPanel(candidates: []) { _ in }
        .padding()
        .preferredColorScheme(.dark)
}
