import SwiftData
import SwiftUI

/// **Count the notes** (ADR 0225), a section of Train your ear: tap once for each note you hear while
/// the loop plays, one row of dots per pass, and **Name the notes** to say what each one was.
///
/// It serves the planner's `ear.transcribe` (ADR 0139) the way a player actually learns a lick: count
/// it, then work out what the notes are. It stays on the ear side of ADR 0070 because the player asks
/// and the player answers. There is no detected count to check against, no suggested name, no score,
/// and nothing charted over days (ADR 0094 T2/T3, 0104 E6). **There's no waveform here, on purpose**
/// (0104 E2): you count what you hear, not the peaks you can see.
struct CountTheNotesSection: View {
    let model: CountTheNotesModel
    let player: ContinuousLoopPlayer
    /// Stops the loop the way the host stops it (a take finalised first), before naming opens.
    let stopLoop: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.Key.countShowsBeats) private var showsBeats = AppSettings.countShowsBeatsDefault

    /// Beats show only when the switch is on **and** the song has a grid to draw.
    private var beatsOn: Bool { showsBeats && model.grid != nil }

    var body: some View {
        Section {
            readout
            TapPad(isLive: player.isPlaying, flashToken: model.flashToken, nudgeToken: model.nudgeToken) {
                model.tap(clock: player.loopClock())
            }
            .listRowSeparator(.hidden)
            PassRowsView(model: model, player: player, showsBeats: beatsOn)
            if beatsOn {
                beatsFooter
            }
            if model.livePassID == nil, let pass = model.targetPass, TapTally.isLongPass(pass.count) {
                longPassTip
            }
            actions
        } header: {
            Text("Count the notes")
        }
        .onChange(of: player.isPlaying) { _, playing in
            if playing { model.loopStarted() } else { model.loopStopped() }
        }
    }

    // MARK: - Readout

    private var readout: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(countText)
                    .font(.futura(size: 44))
                    .monospacedDigit()
                    .foregroundStyle(PocketColor.textPrimary)
                    .accessibilityIdentifier("count.readout")
                Text(countCaption)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if model.grid != nil {
                Toggle("Show beats", isOn: $showsBeats)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize()
                    .tint(PocketColor.practice)
            }
        }
    }

    private var countText: String {
        if model.livePassID != nil { return "\(model.liveCount)" }
        return model.targetPass.map { "\($0.count)" } ?? "–"
    }

    private var countCaption: String {
        if model.livePassID != nil { return "this pass" }
        return model.targetPass.map { "pass \($0.id)" } ?? "no passes yet"
    }

    // MARK: - Beats

    /// The per-beat split of the pass in hand, and the honest caption: the lines are only as good as the
    /// grid, and the grid can be corrected (ADR 0154).
    private var beatsFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pass = model.targetPass, let split = model.grid?.perBeat(pass.taps.map(\.seconds)),
               split.count > 1 {
                Text("Pass \(pass.id) by beat: " + split.map(String.init).joined(separator: " · "))
                    .font(.futura(.footnote))
                    .monospacedDigit()
                    .foregroundStyle(PocketColor.textPrimary)
            }
            Text("Beats come from the song's tempo and its 1. If the lines don't sit on the beat, the grid "
                + "needs correcting.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - A long pass

    /// A long pass is a lot to name, and a lot to hold in the ear (0227, after the device check). Said
    /// once the loop stops, never while the player is still tapping it out.
    private var longPassTip: some View {
        let noun = model.loop.loopType == .chords ? "chords" : "notes"
        return Text("Loops of around \(TapTally.comfortableNotes) \(noun) are easier to transcribe. For a pass "
                    + "this long, try a shorter loop.")
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("count.longPassTip")
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 10) {
            if model.cleared != nil {
                Button("Undo clear") { model.undoClear() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                Button("Clear") { model.clear() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(PocketColor.textSecondary)
                    .disabled(model.passes.passes.isEmpty)
            }
            Spacer(minLength: 0)
            Button("Name the notes") {
                stopLoop()
                model.nameTarget()
            }
            .buttonStyle(.bordered)
            .tint(PocketColor.practice)
            .disabled(model.targetPass == nil)
            Button("Save") {
                model.requestSave(context: modelContext)
            }
            .buttonStyle(.bordered)
            .tint(PocketColor.journal)
            .disabled(model.targetPass == nil)
            .accessibilityHint("Saves this pass on the loop. The Journal lists it under Pieces.")
        }
        .font(.futura(.subheadline))
    }
}

/// The tap pad. Fires on **touch-down**, not on lift: a `Button` or `onTapGesture` fires as the finger
/// leaves the glass, which adds a lag that varies with how long each tap is held. A zero-distance drag
/// latches on the first contact instead, the way `StepperButton` does (and it's not a `Button` at all,
/// memory: a Button with a second gesture fires both).
private struct TapPad: View {
    let isLive: Bool
    let flashToken: Int
    let nudgeToken: Int
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var flashing = false
    @State private var nudging = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(flashing ? PocketColor.practice.opacity(0.35) : PocketColor.surfaceStandard)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(PocketColor.surfaceBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .overlay {
                VStack(spacing: 2) {
                    Text(nudging ? "Press play first" : "Tap each note")
                        .font(.futura(.title3))
                        .foregroundStyle(isLive ? PocketColor.textPrimary : PocketColor.textSecondary)
                    Text(isLive ? "Once for every note you hear" : "Counting starts once the loop plays")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .frame(height: 118)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onTap()
                    }
                    .onEnded { _ in isPressed = false }
            )
            .onChange(of: flashToken) {
                haptic(.light)
                flashing = true
                withAnimation(.easeOut(duration: 0.18)) { flashing = false }
            }
            .task(id: nudgeToken) {
                guard nudgeToken > 0 else { return }
                nudging = true
                try? await Task.sleep(for: .seconds(1.1))
                nudging = false
            }
            .onAppear { prepareHaptics() }
            .accessibilityElement()
            .accessibilityLabel("Tap once for each note you hear")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("count.pad")
            .accessibilityAction { onTap() }
    }
}
