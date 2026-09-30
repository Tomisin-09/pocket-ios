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

    @State var rows: [Row]
    /// Each loop's command tempo, as a fraction of the record's speed.
    let onDone: ([UUID: Double]) -> Void
    @Environment(\.dismiss) private var dismiss

    /// The loop edit sheet's range and step, so a value set here reads the same there.
    static let range = 25...150

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($rows) { $row in
                        Stepper(value: $row.percent, in: Self.range, step: 5) {
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
                } header: {
                    Text(rows.count == 1 ? "How fast can you play it now?" : "How fast can you play these now?")
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                        .textCase(nil)
                } footer: {
                    Text("The fastest you can play each one cleanly, as a % of the record. Each block starts "
                         + "below it and climbs back up. It's saved on the loop as its command tempo.")
                }
            }
            .navigationTitle("Tempo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onDone(Dictionary(rows.map { ($0.uid, Double($0.percent) / 100) },
                                          uniquingKeysWith: { first, _ in first }))
                    }
                    .font(.futura(.body, weight: .bold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Where the loop edit sheet's **Set** starts: the loop's speed, within the range, to the nearest step.
    static func seed(speed: Double) -> Int {
        let percent = Int((min(max(speed, 0.25), 1.5) * 100 / 5).rounded()) * 5
        return min(max(percent, range.lowerBound), range.upperBound)
    }
}
