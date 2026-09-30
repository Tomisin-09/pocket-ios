import SwiftUI

extension SongDetailsSheet {
    /// The way into **Map the song** (ADR 0232 D1): the song's loops laid out where they play. The map is
    /// per song, so the song is its home.
    var mapSection: some View {
        Section {
            Button { mappingSong = true } label: {
                HStack {
                    Label("Map the song", systemImage: "puzzlepiece")
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
        } footer: {
            Text("Your loops laid out where they play, section by section, with what you've counted and "
                 + "named in each.")
        }
    }
}
