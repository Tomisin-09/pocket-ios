import SwiftUI

/// The bar along the bottom of the map while pieces are being picked to put together (ADR 0232 D11): how
/// many are picked, what they make or why they can't be put together, and **Put it together**.
struct SongMapTogetherBar: View {
    let count: Int
    /// What the picked pieces make, or why they make nothing: `SongMapTogether.line(for:in:)`.
    let line: String
    let canPut: Bool
    let onPut: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(count) picked")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Button("Cancel", action: onCancel)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .buttonStyle(.plain)
            }
            Text(line)
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onPut) {
                Text("Put it together")
                    .font(.futura(.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PocketColor.practice)
            .disabled(!canPut)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PocketColor.background)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
        )
    }
}

/// *How fast can you play these now?* (ADR 0232 D11). A Practice block's speed ramp is built around the
/// loop's command tempo (ADR 0138), so Put it together asks once for any piece that has none. Each row
/// starts where the loop edit sheet's **Set** would, and the answer is saved on the loop as if set there.
/// A backing with none is asked for too, starting with the line, so it doesn't open faster than the line
/// was practised.
struct SongMapCommandSheet: View {
    struct Row: Identifiable, Equatable {
        let uid: UUID
        let name: String
        /// *Notes · Bars 9–10*.
        let place: String
        /// % of the record, in 5% steps.
        var percent: Int
        var id: UUID { uid }
    }

    /// What the sheet asks: a row for each piece that runs as a Practice block, and one for the backing.
    struct Answers: Equatable {
        var rows: [Row]
        var backing: Row?
        /// The row the backing moves with until it's set on its own: the line's, when the line is asked
        /// for too.
        var follows: UUID?

        func percent(_ uid: UUID) -> Int {
            (backing?.uid == uid ? backing : rows.first { $0.uid == uid })?.percent ?? 100
        }

        mutating func set(_ percent: Int, for uid: UUID) {
            if backing?.uid == uid {
                backing?.percent = percent
                follows = nil
            } else if let index = rows.firstIndex(where: { $0.uid == uid }) {
                rows[index].percent = percent
                if follows == uid { backing?.percent = percent }
            }
        }

        /// Each loop's command tempo, as a fraction of the record's speed.
        var commands: [UUID: Double] {
            Dictionary((rows + [backing].compactMap { $0 }).map { ($0.uid, Double($0.percent) / 100) },
                       uniquingKeysWith: { first, _ in first })
        }
    }

    @State var answers: Answers
    let onDone: ([UUID: Double]) -> Void
    @Environment(\.dismiss) private var dismiss

    /// The loop edit sheet's range and step, so a value set here reads the same there.
    static let range = 25...150

    var body: some View {
        NavigationStack {
            List {
                if !answers.rows.isEmpty {
                    Section {
                        ForEach(answers.rows) { stepper($0) }
                    } header: {
                        heading(answers.rows.count == 1 ? "How fast can you play it now?"
                                    : "How fast can you play these now?")
                    } footer: {
                        Text("The fastest you can play each one cleanly, as a % of the record. Each block starts "
                             + "below it and climbs back up. It's saved on the loop as its command tempo.")
                    }
                }
                if let backing = answers.backing {
                    Section {
                        stepper(backing)
                    } header: {
                        heading("How fast should the backing play?")
                    } footer: {
                        Text("It starts at the line's speed, so it's no faster than you've practised the line. You "
                             + "can change it while it plays. It's saved on the loop as its command tempo.")
                    }
                }
            }
            .navigationTitle("Tempo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") { onDone(answers.commands) }
                        .font(.futura(.body, weight: .bold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stepper(_ row: Row) -> some View {
        Stepper(value: Binding(get: { answers.percent(row.uid) }, set: { answers.set($0, for: row.uid) }),
                in: Self.range, step: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name).font(.futura(.body))
                    Text(row.place)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Text("\(row.percent)%").font(.pocketMono(.body))
            }
        }
        .accessibilityValue("\(row.percent) percent")
    }

    private func heading(_ words: String) -> some View {
        Text(words)
            .font(.futura(.subheadline, weight: .semibold))
            .foregroundStyle(PocketColor.textPrimary)
            .textCase(nil)
    }

    /// Where the loop edit sheet's **Set** starts: the loop's speed, within the range, to the nearest step.
    static func seed(speed: Double) -> Int {
        let percent = Int((min(max(speed, 0.25), 1.5) * 100 / 5).rounded()) * 5
        return min(max(percent, range.lowerBound), range.upperBound)
    }
}

extension SongMapCommandSheet.Answers {
    /// What Put it together asks before it begins, or `nil` when nothing's missing: a command tempo for each
    /// piece that runs as a Practice block without one (ADR 0138), and one for a backing without one, which
    /// starts with the line: at the line's command tempo, or moving with the line's row while that's asked.
    @MainActor
    init?(asking plan: SongMapTogether.Plan, loops: [Loop], place: (UUID) -> String) {
        let byUID = Dictionary(loops.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        func row(_ loop: Loop, _ percent: Int) -> SongMapCommandSheet.Row {
            SongMapCommandSheet.Row(uid: loop.uid, name: loop.name.isEmpty ? "Loop" : loop.name,
                                    place: place(loop.uid), percent: percent)
        }
        let rows = plan.practised.compactMap { byUID[$0] }.filter { $0.commandTempo == nil }
            .map { row($0, SongMapCommandSheet.seed(speed: $0.speed)) }
        var backing: SongMapCommandSheet.Row?
        var follows: UUID?
        if let loop = plan.backing.flatMap({ byUID[$0] }), loop.commandTempo == nil,
           let line = plan.practised.first.flatMap({ byUID[$0] }) {
            backing = row(loop, SongMapCommandSheet.seed(speed: line.commandTempo ?? line.speed))
            follows = line.commandTempo == nil ? line.uid : nil
        }
        guard !rows.isEmpty || backing != nil else { return nil }
        self.init(rows: rows, backing: backing, follows: follows)
    }
}
