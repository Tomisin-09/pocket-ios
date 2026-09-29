import SwiftUI

/// **Copy to…** (ADR 0232 D16): where a piece the player has counted is copied to. The song's sections, or
/// the board's rows when it has none, and, when the map has bars, any run of bars. Each place ticked gets a
/// loop of its own with the piece written across it, and the map offers Undo once they're made (D17).
struct SongMapCopySheet: View {
    let piece: SongMap.Piece
    let map: SongMap
    /// Make the copies. This sheet closes itself.
    let onCopy: ([SongMapCopy.Target]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ticked: Set<TimeInterval> = []
    @State private var byBars = false
    @State private var firstBar: Int
    @State private var lastBar: Int

    init(piece: SongMap.Piece, map: SongMap, onCopy: @escaping ([SongMapCopy.Target]) -> Void) {
        self.piece = piece
        self.map = map
        self.onCopy = onCopy
        // The run of bars starts just after the piece, and is as long as it is.
        let count = max(map.grid?.downbeats.count ?? 1, 1)
        let own = map.bars(of: piece) ?? 1...1
        let first = min(own.upperBound + 1, count)
        _firstBar = State(initialValue: first)
        _lastBar = State(initialValue: min(first + own.count - 1, count))
    }

    private var targets: [SongMapCopy.Target] { SongMapCopy.targets(for: piece, in: map) }
    private var barsTarget: SongMapCopy.Target? {
        SongMapCopy.bars(firstBar...max(firstBar, lastBar), layer: piece.layer, in: map)
    }
    private var picked: [SongMapCopy.Target] {
        targets.filter { ticked.contains($0.id) } + (byBars ? [barsTarget].compactMap { $0 } : [])
    }

    var body: some View {
        NavigationStack {
            List {
                if !targets.isEmpty {
                    Section {
                        ForEach(targets) { target in
                            row(target, isTicked: ticked.contains(target.id)) {
                                if ticked.remove(target.id) == nil { ticked.insert(target.id) }
                            }
                        }
                    } header: {
                        Text(map.hasSections ? "Sections" : "Rows")
                    } footer: {
                        if map.grid == nil { footer }
                    }
                }
                if let grid = map.grid { bars(count: grid.downbeats.count) }
            }
            .navigationTitle("Copy \(piece.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") {
                        onCopy(picked)
                        dismiss()
                    }
                    .disabled(picked.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Any run of bars, for a copy that isn't a whole section: a turnaround, or four bars of a verse.
    private func bars(count: Int) -> some View {
        Section {
            if let target = barsTarget {
                // Named for what it does, with the bars on the right where a section's are: the steppers
                // that change them show once it's ticked.
                row(target, title: "Choose bars", place: target.title, isTicked: byBars) { byBars.toggle() }
            }
            if byBars {
                Stepper("From bar \(firstBar)", value: $firstBar, in: 1...count)
                Stepper("Through bar \(lastBar)", value: $lastBar, in: firstBar...count)
            }
        } header: {
            Text("Bars")
        } footer: {
            footer
        }
        .onChange(of: firstBar) { _, first in lastBar = max(lastBar, first) }
    }

    private var footer: Text {
        Text("Each place ticked gets a loop of its own, with \(piece.name) written across it "
             + "\(SongMapCopy.every(from: piece.start, to: piece.end, grid: map.grid)). Change one later and "
             + "the others stay as they are.")
    }

    private func row(_ target: SongMapCopy.Target, title: String? = nil, place: String? = nil, isTicked: Bool,
                     toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isTicked ? PocketColor.active : PocketColor.textSecondary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? target.title)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    if !target.alongside.isEmpty {
                        Text("Already has \(target.alongside.joined(separator: ", "))")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let place = place ?? target.place {
                    Text(place)
                        .font(.pocketMono(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isTicked ? "Ticked" : "Not ticked")
        .accessibilityAddTraits(isTicked ? .isSelected : [])
    }
}
