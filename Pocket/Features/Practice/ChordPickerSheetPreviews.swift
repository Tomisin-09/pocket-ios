import SwiftData
import SwiftUI

/// `ChordPickerSheet`'s previews, split out so the sheet itself stays under the 400-line ceiling —
/// the same treatment `LibraryView` and `RoutineDetailView` already give theirs.
#Preview("Chord picker — populated") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SavedChord.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    for chord in [ChordVoicing("Aadd9", frets: [0, 0, 2, 4, 2, nil]),
                  ChordVoicing("Cm9", frets: [3, 4, 3, 5, 6, nil])] {
        container.mainContext.insert(SavedChord(chord))
    }
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            ChordPickerSheet(onInsert: { _ in }, onSave: { _ in })
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
}
