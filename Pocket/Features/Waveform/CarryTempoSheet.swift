import SwiftData
import SwiftUI

/// **Take this tempo somewhere** — the song player's tempo-carry gateway (ADR 0170), opened by
/// holding the BPM callout on the speed bar.
///
/// The song player knows a number the rest of the app would like: the tempo you are actually
/// practising at. Until this existed the number was a read-only label — you could see 92 BPM and
/// then had to go and dial 92 into the metronome by hand, or type it into a new drill. Two
/// destinations, both seeded with the tempo as the callout displayed it (`song.bpm × speed`, so a
/// slowed reading carries slowed — see `WaveformPracticeModel.carryTempo`).
///
/// **A sheet, not a `Menu`.** The house rule, stated at `MeterPickerSheet`, in `ExerciseRunView`
/// and in ADR 0163's rejected alternatives: a menu picks between like-for-like *values*, and these
/// are heterogeneous *destinations* with different consequences — one starts a click, the other
/// creates a model. Each row needs a line of explanation, which is the half a menu drops first.
///
/// **One presentation, not three.** The destination replaces this sheet's content in place rather
/// than being presented from it: both destination views bring their own `NavigationStack`, so
/// pushing them would nest one, and presenting them would put the waveform screen's presentation
/// count up by three at once (ADR 0163's constraint is on what `WaveformPracticeView.body` reads,
/// but each presentation is still a body to re-evaluate). Their own dismiss control closes the whole
/// sheet, which is the right ending: you chose a destination, you are not coming back to a chooser.
struct CarryTempoSheet: View {
    /// The tempo as the callout was displaying it at the moment of the hold.
    let bpm: Int
    /// The song it was read off — carried into the new drill's song links (ADR 0111), because it is
    /// the one fact this route knows that the create form cannot infer.
    let song: Song
    /// The song's meter, so a drill made from a 3/4 song opens on 3/4.
    let signature: TimeSignature
    /// Handed a chance to stop the song before a destination brings its own audio — the metronome
    /// runs its own engine, and two streams over each other is the alternative. The same seam
    /// `LoopEditSheet` uses for ear training and improvising.
    var onOpenNestedAudio: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    /// The local profile (ADR 0113 S2) — a drill created from here should open on the instrument you
    /// actually play, for the reason the automator's save seam reads it (ADR 0116).
    @Query private var profiles: [Profile]

    /// Where the tempo is going. `nil` is the chooser itself.
    private enum Destination: Hashable { case metronome, exercise }
    @State private var destination: Destination?
    /// Driven, not merely offered: the chooser is two rows tall and the destinations are whole
    /// screens, so the detent has to *move* when the content swaps. A bare set of detents would
    /// leave a full metronome squeezed into the medium one.
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        Group {
            switch destination {
            case .none:
                chooser
            case .metronome:
                // Opens already on this tempo (ADR 0170) rather than the free-play default — the
                // whole point of the route. Its own back chevron dismisses this sheet.
                MetronomeView(initialBPM: bpm)
            case .exercise:
                // The template picker runs: a song's tempo can seed any kind of drill, unlike the
                // automator's seam, where a breakdown point is always a plain tempo drill. Funnels
                // through `plan.finalise(in:)` — the shared insert (`ExerciseCreation`), never a
                // third path of its own.
                NewExerciseSheet(initialCommand: bpm, initialSignature: signature,
                                 defaultInstrument: profiles.first?.preferredInstrument ?? .guitar,
                                 initialSongs: [song]) { plan in
                    plan.finalise(in: modelContext)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
    }

    // MARK: - The chooser

    private var chooser: some View {
        NavigationStack {
            Form {
                Section {
                    metronomeRow
                    exerciseRow
                } header: {
                    Text("Take \(bpm) BPM to")
                } footer: {
                    Text("The tempo you're hearing — the song's tempo at the speed you've set.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Carry this tempo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var metronomeRow: some View {
        Button {
            onOpenNestedAudio()
            go(to: .metronome)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To the metronome")
                    Text("Opens the metronome at \(bpm) BPM.")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            } icon: {
                Image(systemName: "metronome")
            }
            .foregroundStyle(PocketColor.metronome)
        }
        .accessibilityLabel("Take \(bpm) beats per minute to the metronome")
    }

    private var exerciseRow: some View {
        Button {
            go(to: .exercise)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Into a new exercise")
                    Text("Starts a drill at \(bpm) BPM, linked to this song.")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            } icon: {
                Image(systemName: "figure.strengthtraining.functional")
            }
            .foregroundStyle(PocketColor.practice)
        }
        .accessibilityLabel("Start a new exercise at \(bpm) beats per minute")
    }

    /// Swap the content and grow the sheet together, in one animation — separately, the destination
    /// appears at the chooser's height and then jumps.
    private func go(to target: Destination) {
        haptic(.light)
        withAnimation {
            destination = target
            detent = .large
        }
    }
}

extension View {
    /// Presents the tempo-carry chooser for this screen's model (ADR 0170).
    ///
    /// A modifier rather than four lines in `WaveformPracticeView.body` because that body is at its
    /// size budget and, more to the point, because everything the sheet needs is derived from the
    /// model — the tempo snapshot, the song, its meter, and the pause seam. Assembling them at the
    /// call site would put four chances to pass the wrong one into the screen's hottest body.
    func carryTempoSheet(_ model: WaveformPracticeModel) -> some View {
        @Bindable var model = model
        return sheet(item: $model.carryingTempo) { carried in
            CarryTempoSheet(bpm: carried.bpm, song: model.song, signature: model.songSignature,
                            onOpenNestedAudio: model.pauseForNestedAudio)
        }
    }
}

#Preview("Carry tempo") {
    CarryTempoSheet(bpm: 92, song: Song.sample(), signature: .standard)
        .preferredColorScheme(.dark)
        .modelContainer(for: [Song.self, Exercise.self, Loop.self, Profile.self], inMemory: true)
}
