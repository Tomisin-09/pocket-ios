import SwiftUI

/// The rows of dots under the tap pad (ADR 0225): the pass playing **now** on top, then the last few
/// finished passes, newest first. Each dot is a tap, placed where it fell across the region. Tap a
/// finished row to pick it for naming or saving.
///
/// When passes agree, you have the count. Nothing here compares them for you.
struct PassRowsView: View {
    let model: CountTheNotesModel
    let player: ContinuousLoopPlayer
    let showsBeats: Bool

    var body: some View {
        VStack(spacing: 6) {
            if player.isPlaying {
                LivePassRow(model: model, player: player, marks: marks)
            }
            ForEach(model.finishedRows) { pass in
                Button {
                    model.selectedPassID = pass.id
                } label: {
                    PassRow(title: "Pass \(pass.id)", fractions: pass.taps.map { model.fraction(of: $0.seconds) },
                            count: pass.count, marks: marks, isSelected: pass.id == model.targetPass?.id)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pass \(pass.id), \(pass.count) \(pass.count == 1 ? "note" : "notes")")
                .accessibilityAddTraits(pass.id == model.targetPass?.id ? .isSelected : [])
            }
            if !player.isPlaying && model.finishedRows.isEmpty {
                Text("Your passes appear here, one row each.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var marks: [CountGrid.Mark] { showsBeats ? model.grid?.marks ?? [] : [] }
}

/// The pass playing now, with a moving playhead. **The one view in Count the notes that reads the clock
/// every frame** (ADR 0153): it redraws on its own and tells the model only when the pass changes.
private struct LivePassRow: View {
    let model: CountTheNotesModel
    let player: ContinuousLoopPlayer
    let marks: [CountGrid.Mark]

    var body: some View {
        TimelineView(.animation) { _ in
            let position = player.loopClock().flatMap(TapTally.heardPosition)
            let passID = position.map { model.passes.id(forRunPass: $0.pass) }
            let taps = passID.flatMap { model.passes.pass(id: $0)?.taps } ?? []
            PassRow(title: "Now", fractions: taps.map { model.fraction(of: $0.seconds) },
                    count: taps.count, marks: marks, isSelected: false, isLive: true,
                    playhead: position.map { playheadFraction(within: $0.within) })
                .onChange(of: position?.pass) { _, pass in model.noteLive(runPass: pass) }
                .onAppear { model.noteLive(runPass: position?.pass) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This pass, \(model.liveCount) \(model.liveCount == 1 ? "note" : "notes")")
    }

    private func playheadFraction(within: TimeInterval) -> Double {
        guard model.regionLength > 0 else { return 0 }
        return (within / model.regionLength).clamped(to: 0...1)
    }
}

/// One pass: its label, a track with a dot per tap, and the count.
private struct PassRow: View {
    let title: String
    let fractions: [Double]
    let count: Int
    let marks: [CountGrid.Mark]
    let isSelected: Bool
    var isLive = false
    var playhead: Double?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.futura(.caption, weight: isLive ? .bold : nil))
                .foregroundStyle(isLive ? PocketColor.practice : PocketColor.textSecondary)
                .frame(width: 52, alignment: .leading)
            track
            Text("\(count)")
                .font(.futura(.subheadline, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? PocketColor.surfaceSubtle : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? PocketColor.surfaceBorder : .clear)
        }
        .contentShape(Rectangle())
    }

    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(PocketColor.gridLine)
                    .frame(height: 1)
                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    Rectangle()
                        .fill(PocketColor.gridLine)
                        .frame(width: mark.isDownbeat ? 1.5 : 1, height: mark.isDownbeat ? 18 : 12)
                        .offset(x: mark.fraction * width)
                }
                ForEach(Array(fractions.enumerated()), id: \.offset) { _, fraction in
                    Circle()
                        .fill(PocketColor.practice)
                        .frame(width: 10, height: 10)
                        .offset(x: fraction * width - 5)
                }
                if let playhead {
                    Capsule()
                        .fill(PocketColor.textPrimary)
                        .frame(width: 2, height: 22)
                        .offset(x: playhead * width - 1)
                }
            }
            .frame(width: width, height: proxy.size.height)
        }
        .frame(height: 22)
    }
}
