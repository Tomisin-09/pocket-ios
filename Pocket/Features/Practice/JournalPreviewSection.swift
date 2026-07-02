import SwiftUI

/// The inline **journal preview** on the Practice run screens (ADR 0058): a glanceable header with
/// a **New entry** CTA plus the latest few entries, sitting in the run-setup screen's body rather
/// than behind a nav-bar button (which crowded the exercise time-signature control). It's a
/// preview + entry point only — every action opens the full `JournalSheet`, which stays the single
/// place entries are composed, edited, and deleted. Shown while stopped; the live readout owns the
/// screen during a run.
struct JournalPreviewSection: View {
    let owner: JournalOwner
    /// Open the full journal (new entry, see-all, or tapping a preview row all route here).
    let onOpen: () -> Void

    /// How many entries the preview surfaces before deferring to "See all".
    private static let previewCount = 3

    private var recent: [JournalEntry] {
        Array(owner.entriesByRecent.prefix(Self.previewCount))
    }
    private var total: Int { owner.entriesByRecent.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if recent.isEmpty {
                Text("No entries yet — jot a note after a run, and it remembers where you were.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                entryCard
                if total > recent.count { seeAll }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Journal")
                .font(.headline)
                .foregroundStyle(PocketColor.textPrimary)
            Spacer()
            Button(action: onOpen) {
                Label("New entry", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New journal entry")
        }
    }

    private var entryCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(recent.enumerated()), id: \.element.uid) { index, entry in
                Button(action: onOpen) {
                    JournalPreviewRow(entry: entry)
                }
                .buttonStyle(.plain)
                if index < recent.count - 1 {
                    Divider().overlay(PocketColor.textSecondary.opacity(0.15))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.textSecondary.opacity(0.08)))
    }

    private var seeAll: some View {
        Button(action: onOpen) {
            HStack(spacing: 4) {
                Text("See all \(total) entries")
                Image(systemName: "chevron.right").font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(PocketColor.practice)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("See all \(total) journal entries")
    }
}

/// A compact one-line-ish preview of an entry for the inline section — kind, a truncated note, and
/// the time. Owner-agnostic (no snapshot readout here; the full sheet shows that), so it stays
/// short enough for three to fit the run-setup empty space.
private struct JournalPreviewRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.kind.emoji)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text)
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.pocketMono(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview("Journal preview — with entries") {
    let exercise = Exercise(name: "Alternating picking", currentTempo: 76, commandTempo: 90)
    let now = Date()
    for (offset, text) in [(0, "Held 90 clean for two minutes."),
                           (-90_000, "Left hand lagging on string crossing."),
                           (-200_000, "Get to 100 BPM by Friday.")] {
        let entry = JournalEntry.forExercise(text: text, kind: .note, commandBpmAtEntry: 90,
                                             createdAt: now.addingTimeInterval(Double(offset)))
        entry.exercise = exercise
    }
    return JournalPreviewSection(owner: .exercise(exercise), onOpen: {})
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Journal preview — empty") {
    JournalPreviewSection(owner: .loop(Loop(name: "Verse", start: 0, end: 0.2, speed: 0.8, repeats: 2)),
                          onOpen: {})
        .padding()
        .preferredColorScheme(.dark)
}
