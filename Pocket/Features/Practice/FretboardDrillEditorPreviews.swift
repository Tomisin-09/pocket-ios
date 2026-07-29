import SwiftUI

/// `FretboardDrillEditor`'s preview, split out so the editor stays under the 400-line ceiling (it is
/// already split across `+Board` and `+Guide` for the same reason).
#Preview("Fretboard editor") {
    struct Harness: View {
        @State private var drill = FretboardDrill.spiderWalk
        var body: some View {
            FretboardDrillEditor(beatsPerBar: 4, drill: $drill)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
