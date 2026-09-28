import SwiftUI

/// One section of the song map (ADR 0232 D6): its heading, which opens the marker that starts it, and
/// its rows.
struct SongMapSectionView: View {
    let section: SongMap.Section
    let map: SongMap
    let loops: [UUID: Loop]
    let actions: SongMapActions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            ForEach(section.rows) { row in
                SongMapRowView(row: row, map: map, loops: loops, actions: actions)
            }
        }
    }

    @ViewBuilder private var heading: some View {
        switch section.heading {
        case .none:
            EmptyView()
        case .start:
            headingRow(Text("Start").foregroundStyle(PocketColor.textSecondary))
        case .marker(let uid, let label):
            headingRow(Button { actions.openMarker(uid) } label: {
                Text(label.isEmpty ? "Section" : label).foregroundStyle(PocketColor.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the marker that starts this section"))
        }
    }

    private func headingRow(_ title: some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            title.font(.futura(.headline))
            Spacer(minLength: 8)
            Text(range)
                .font(.pocketMono(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    /// *Bars 5–12*, or *0:23–0:45* when the map is in seconds.
    private var range: String {
        if let bars = section.bars {
            return bars.count == 1 ? "Bar \(bars.lowerBound)" : "Bars \(bars.lowerBound)–\(bars.upperBound)"
        }
        return "\(timecode(section.start))–\(timecode(section.end))"
    }
}

/// One row of the board (ADR 0232 D2): a ruler of bar lines or time marks, with the pins of markers
/// that don't start a section, then the chords lanes over the notes lanes.
struct SongMapRowView: View {
    let row: SongMap.Row
    let map: SongMap
    let loops: [UUID: Loop]
    let actions: SongMapActions

    static let labelWidth: CGFloat = 50
    /// Numbers along the top, pins along the bottom pointing into the lanes, so a pin on a bar line
    /// never covers the bar's number.
    static let rulerHeight: CGFloat = 26
    private static let pinHeight: CGFloat = 10
    static let laneHeight: CGFloat = 46
    static let spacing: CGFloat = 4

    private var height: CGFloat {
        Self.rulerHeight + CGFloat(row.lanes.count) * (Self.laneHeight + Self.spacing)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            labels
            GeometryReader { geo in
                let width = geo.size.width * row.widthFraction
                VStack(alignment: .leading, spacing: Self.spacing) {
                    ruler(width: width)
                    ForEach(row.lanes) { lane in
                        laneView(lane, width: width)
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            Text(map.scale == .bars ? "Bar" : "Time")
                .frame(height: Self.rulerHeight, alignment: .topLeading)
            ForEach(row.lanes) { lane in
                Text(lane.index == 0 ? SongMapStyle.name(lane.layer) : "")
                    .frame(height: Self.laneHeight, alignment: .leading)
            }
        }
        .font(.futura(.caption2))
        .foregroundStyle(PocketColor.textSecondary)
        .frame(width: Self.labelWidth, alignment: .leading)
        .accessibilityHidden(true)
    }

    // MARK: - Ruler

    private func ruler(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(row.ticks, id: \.time) { tick in
                Text(tick.bar.map(String.init) ?? timecode(tick.time))
                    .font(.pocketMono(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize()
                    .offset(x: xPos(tick.time, width) + 2)
            }
            ForEach(row.pins) { pin in
                Button { actions.openMarker(pin.uid) } label: {
                    PinShape()
                        .fill(PocketColor.marker)
                        .frame(width: 11, height: Self.pinHeight)
                        .frame(width: 28, height: Self.rulerHeight, alignment: .bottom)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: xPos(pin.time, width) - 14)
                .accessibilityLabel("Marker, \(pin.label)")
                .accessibilityHint("Opens the marker")
            }
        }
        .frame(width: width, height: Self.rulerHeight, alignment: .topLeading)
    }

    // MARK: - Lanes

    private func laneView(_ lane: SongMap.Lane, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7).fill(PocketColor.surfaceSubtle)
            ForEach(row.ticks.dropFirst(), id: \.time) { tick in
                Rectangle()
                    .fill(PocketColor.surfaceBorder)
                    .frame(width: 1, height: Self.laneHeight - 8)
                    .offset(x: xPos(tick.time, width), y: 4)
            }
            ForEach(lane.placements) { placement in
                if let piece = map.pieces[placement.uid] {
                    let start = xPos(placement.start, width), end = xPos(placement.end, width)
                    SongMapPieceView(piece: piece, placement: placement, loop: loops[placement.uid],
                                     width: max(end - start, 6), height: Self.laneHeight - 6,
                                     onView: { actions.view(placement.uid) },
                                     onOpen: { actions.open(placement.uid, $0) })
                        .offset(x: start, y: 3)
                }
            }
        }
        .frame(width: width, height: Self.laneHeight, alignment: .topLeading)
    }

    private func xPos(_ time: TimeInterval, _ width: CGFloat) -> CGFloat {
        CGFloat(row.position(of: time)) * width
    }
}

/// A marker's pin, pointing down at its place, as on the waveform.
private struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
