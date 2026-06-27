import SwiftData
import SwiftUI

/// The **Loops** library inside Practice (ADR 0046 Phase B): the focused list of song loops you've
/// **measured** (a command tempo set), pushed from the Practice hub. A measured loop is a trainable
/// unit — tapping it opens its `LoopRunView` to train the same warm-up → dwell → reach → back-off
/// staircase as an exercise, against the loop's time-stretched audio.
///
/// No creation or deletion here: a loop belongs to its **song**, made and removed on the waveform
/// screen. This library is a read-through onto the loops worth training. The `commandTempo != nil`
/// gate is an **in-memory** filter, not a SwiftData optional `#Predicate` (which starves the main
/// thread — see `PracticeRunUITests`).
struct LoopLibraryView: View {
    @Query private var allLoops: [Loop]

    private var measuredLoops: [Loop] {
        allLoops.filter { $0.commandTempo != nil }
            .sorted { ($0.song?.title ?? "", $0.name) < ($1.song?.title ?? "", $1.name) }
    }

    var body: some View {
        List {
            if measuredLoops.isEmpty {
                Text("No measured loops yet. Open a song, set a loop's command tempo on the "
                     + "waveform, and it'll show up here to train.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(measuredLoops) { loop in
                    NavigationLink {
                        LoopRunView(loop: loop)
                    } label: {
                        PracticeUnitRow(title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                                        context: loop.song?.title,
                                        progress: "Command \(LoopCommandRamp.percent(loop.command))% → "
                                            + "\(LoopCommandRamp.percent(loop.derivedTargetSpeed))%")
                    }
                    .listRowBackground(PocketColor.background)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Loops")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Loops — empty") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return NavigationStack { LoopLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
