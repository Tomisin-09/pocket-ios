import SwiftUI

/// A compact, **read-only** "Looks like …" caption — the single best reverse-lookup reading (ADR 0093) of
/// a voicing, for surfaces where the name is *derived* (the movable-shape preview) or *stored* (progression
/// rows) rather than typed. It is the informational sibling of `ChordIdentifierPanel`: where the panel is a
/// tappable set of chips that fills a name field, this is one line that names nothing and gates nothing.
///
/// Purely additive (ADR 0070/0093 N7): it renders **nothing** when the shape spells no common chord (the
/// honest "no name" case stays silent here rather than nagging), and it can be told to stay quiet when its
/// reading merely echoes a name the surface already shows, so it only appears when it adds information —
/// an inversion, or a voicing whose stored name isn't the theoretical one.
struct ChordIdentityCaption: View {
    /// The voicing to read. Its lowest string is treated as the bass, so inversions are detected.
    let voicing: ChordVoicing

    /// When set, the caption is suppressed if its reading exactly equals this string — e.g. pass the row's
    /// stored name so a plain "C" isn't captioned "Looks like C". `nil` always shows (the movable sheet's
    /// confirmation use).
    var suppressIfMatches: String?

    private var candidate: ChordCandidate? { ChordNamer.candidates(for: voicing).first }

    var body: some View {
        if let candidate, shouldShow(candidate) {
            HStack(spacing: 5) {
                Text("Looks like")
                Text(candidate.displayName)
                    .fontWeight(.semibold)
                if let tag = candidate.inversionLabel {
                    Text("· \(tag)")
                        .opacity(0.8)
                }
            }
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Looks like \(candidate.displayName)"
                + (candidate.inversionLabel.map { ", \($0)" } ?? ""))
        }
    }

    /// Show unless the reading merely repeats a name the surface already displays.
    private func shouldShow(_ candidate: ChordCandidate) -> Bool {
        guard let matching = suppressIfMatches else { return true }
        return candidate.displayName != matching
    }
}

#Preview("Identity captions") {
    VStack(alignment: .leading, spacing: 12) {
        ChordIdentityCaption(voicing: .cMajor7)                       // "Looks like Cmaj7"
        ChordIdentityCaption(voicing: .cMajor7, suppressIfMatches: "Cmaj7") // hidden (echoes name)
        ChordIdentityCaption(voicing: ChordVoicing("Cmaj7", frets: [nil, 1, 0, 2, 3, nil])) // an inversion
    }
    .padding()
    .preferredColorScheme(.dark)
}
