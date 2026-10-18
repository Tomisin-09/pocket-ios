import SwiftUI

extension SongDetailsSheet {
    /// The way into **Map the song** (ADR 0232 D1): the song's loops laid out where they play. The map is
    /// per song, so the song is its home. The first row of **Practise** (ADR 0258), its explanation now
    /// a line under the name rather than a footer of its own.
    var mapRow: some View {
        Button { mappingSong = true } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Map the song")
                        Text("Your loops laid out where they play")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                } icon: {
                    Image(systemName: "puzzlepiece")
                }
                .foregroundStyle(PocketColor.library)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map the song")
        .accessibilityHint("Your loops laid out where they play, section by section")
    }
}
