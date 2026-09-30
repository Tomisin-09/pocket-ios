import SwiftUI

/// **A written tab, to read** (ADR 0235 D2, D5): its title, when it last changed, and the tab drawn by
/// section, with **Edit** to write more. A tab opens here rather than in the writer: once it's written you
/// play from it far more often than you change it.
///
/// Nothing plays and nothing can be copied or shared: there's no recording behind it, and sharing a tab
/// waits on the same legal review as sharing a take (ADR 0150, 0235 D8).
struct WrittenTabView: View {
    let tab: WrittenTab

    @AppStorage(AppSettings.Key.accidentalPreference) private var accidentalRaw = NoteSpelling.default.rawValue

    var body: some View {
        let payload = tab.payload
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tab.displayTitle)
                        .font(.futura(.title2, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(changedLine)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                if payload.labels.isEmpty {
                    Text("No notes yet. Tap Edit to write the first on the neck.")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    PieceDrawing(notes: payload.notes, spelling: NoteSpelling(rawValue: accidentalRaw) ?? .default)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PocketColor.surfaceSubtle))
                }
                Text("Written on the neck. Nothing plays, because there’s no recording behind it.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(20)
            .readableWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") { TabWriterView(tab: tab) }
                    .accessibilityIdentifier("tab.edit")
            }
        }
        .tint(PocketColor.toolkit)
    }

    /// *Changed today*, *Changed yesterday*, or *Changed on 26 Sep 2026*.
    private var changedLine: String {
        let day = WrittenTab.day(tab.changedAt)
        switch day {
        case "Today", "Yesterday": return "Changed \(day.lowercased())"
        default: return "Changed on \(day)"
        }
    }
}
