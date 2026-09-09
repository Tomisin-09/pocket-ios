import SwiftUI

/// **The player's own words, handed back to them** — italic, indented behind a coloured rule.
///
/// Lifted out of `OracleView.ParagraphView` (ADR 0187) when the Journal's look-back card needed the
/// same treatment (ADR 0207 D8). It is eight lines of layout, and two copies of eight lines is
/// exactly how two surfaces that mean the same thing start looking different — the Oracle quotes a
/// note to say *this is what you said*, and so does the look-back card.
///
/// The **tint is a parameter** because the rule takes the colour of the surface doing the quoting:
/// crimson in the Oracle, gold in the Journal. That is the one thing the two must *not* share, since
/// the hue is how a player knows which space they are standing in.
struct QuotedNoteView: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 3)
            Text(text)
                .font(.futura(.body))
                .italic()
                .foregroundStyle(PocketColor.textPrimary)
        }
        // Without this the quote is squeezed to one truncated line whenever its host offers it a
        // flexible height — which is what a `.medium` detent and a `List` row both do.
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Quoted note") {
    VStack(alignment: .leading, spacing: 20) {
        QuotedNoteView(text: "Can't get past bar 9 at any tempo. Might be the wrong fingering "
                       + "entirely.", tint: PocketColor.journal)
        QuotedNoteView(text: "Shoulders tight for the first twenty minutes.",
                       tint: PocketColor.oracle)
    }
    .padding(24)
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
