import SwiftUI

/// **The Journal thread** (ADR 0286): one exercise's or loop's rows on a screen of their own, pushed from
/// the count at the end of a feed row's caption line or from *Show all* in its hold menu.
///
/// It is `JournalTabView` again, in a second mode, rather than a screen of its own, so a thread's rows keep
/// every verb the feed's have: play, pin, rename, the swipe and hold menu's Delete with its Undo, and a
/// take's own screen. What differs is above the rows. The feed has the month rail, search, ⋯ and ＋; a
/// thread has a header naming the unit, its own scope picker, and **Open**, which goes where the caption
/// does (ADR 0142 J5).
///
/// Nothing here is saved. The thread's scope starts on the feed's and is `@State`, so ADR 0190 D8's
/// persisted filters are untouched, and leaving is the Back button, which puts the feed back where it was.
extension JournalTabView {

    /// Every item of one unit, before the thread's scope.
    func threadItems(_ unit: JournalTimeline.UnitRef) -> [JournalTimeline.Item] {
        JournalTimeline.filter(merged, unit: unit)
    }

    /// The count a feed row carries, or `nil`: in a thread, for a row with no unit, and for a unit with only
    /// this row. Looked up in counts made once per render, never counted here.
    func threadLink(for item: JournalTimeline.Item,
                    counts: [JournalTimeline.UnitRef: Int]) -> JournalThreadLink? {
        guard let unit = JournalTimeline.unit(for: item), let count = counts[unit], count > 1,
              let name = JournalTimeline.unitName(for: item) else { return nil }
        return JournalThreadLink(count: count, name: name) { openingThread = unit }
    }

    // MARK: - The unit

    private func threadLoop(_ unit: JournalTimeline.UnitRef) -> Loop? {
        unit.kind == .loop ? loops.first { $0.uid == unit.uid } : nil
    }

    private func threadExercise(_ unit: JournalTimeline.UnitRef) -> Exercise? {
        unit.kind == .exercise ? exercises.first { $0.uid == unit.uid } : nil
    }

    /// The title's short name. "Journal" only if the unit went while the thread was open.
    private func threadName(_ unit: JournalTimeline.UnitRef) -> String {
        JournalTimeline.unitName(loop: threadLoop(unit), exercise: threadExercise(unit)) ?? "Journal"
    }

    /// Where **Open** goes: the route a session pill takes to the same unit, so a loop opens in the mode it
    /// qualifies for (ADR 0142 J5a). `nil`, and no button, when it qualifies for none.
    private func threadRoute(_ unit: JournalTimeline.UnitRef) -> JournalOwnerRoute? {
        let ref = SessionUnitRef(uid: unit.uid, title: threadName(unit),
                                 kind: unit.kind == .loop ? .loop : .exercise)
        return JournalOwnerRoute.route(for: ref, exercises: exercises, loops: loops)
    }

    // MARK: - The screen

    func threadScreen(_ unit: JournalTimeline.UnitRef) -> some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $threadScope) {
                Text("All").tag(JournalTimeline.Scope.all)
                Text("Notes").tag(JournalTimeline.Scope.notes)
                Text("Takes").tag(JournalTimeline.Scope.takes)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            if sections.isEmpty { threadEmpty(unit) } else { list }
        }
        .navigationTitle(threadName(unit))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let route = threadRoute(unit) {
                    Button("Open") { open(route) }
                        .accessibilityLabel("Open \(threadName(unit))")
                        .accessibilityIdentifier("journal.thread.open")
                }
            }
        }
    }

    /// The first row of a thread's list, so it scrolls away like the feed's look-back card: what kind of
    /// unit, how many rows under this scope, its full name, and the first-to-latest line.
    @ViewBuilder func threadHeaderRow(_ unit: JournalTimeline.UnitRef) -> some View {
        // A loop by its song as well, as the feed's caption names it; an exercise by its name.
        let fullName: String? = if let loop = threadLoop(unit) {
            JournalTimeline.ownerLabel(loop: loop, exercise: nil, song: nil)
        } else {
            threadExercise(unit)?.name
        }
        let count = items.count
        VStack(alignment: .leading, spacing: 6) {
            Text("\(unit.kind == .loop ? "Loop" : "Exercise") · \(count) \(count == 1 ? "entry" : "entries")")
                .font(.futura(.caption2, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(PocketColor.journal)
            // Only when it says more than the title: a loop's adds its song, an exercise's would repeat it.
            if let fullName, fullName != threadName(unit) {
                Text(fullName)
                    .font(.futura(.title3, weight: .medium))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            if let span = JournalTimeline.readingSpan(threadItems(unit)) {
                JournalReadingSpanLine(span: span)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("journal.thread.header")
        .listRowBackground(PocketColor.background)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 10, trailing: 20))
    }

    /// Said plainly, in the scope's own word, when the scope or a delete has emptied the thread.
    private func threadEmpty(_ unit: JournalTimeline.UnitRef) -> some View {
        let what = switch threadScope {
        case .notes: "No notes for"
        case .takes: "No takes for"
        case .all, .pieces: "Nothing left for"
        }
        return Text("\(what) \(threadName(unit)).")
            .font(.futura(.callout))
            .foregroundStyle(PocketColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// **The first-to-latest line** under a thread's header (ADR 0286): *80 → 96 BPM · 8ths since 12 Oct* for an
/// exercise, mastery dots and percent at each end for a loop. Two snapshots the notes already kept, set
/// side by side and never judged (ADR 0070): where it started in this journal, and where the last note had it.
struct JournalReadingSpanLine: View {
    let span: JournalTimeline.ReadingSpan

    var body: some View {
        HStack(spacing: 6) {
            if let text = span.bpmText {
                Text(text)
            } else {
                reading(span.first)
                Text("→").foregroundStyle(PocketColor.journal)
                reading(span.latest)
            }
            Text("since \(since)").foregroundStyle(PocketColor.textSecondary)
        }
        .font(.pocketMono(.caption))
        .foregroundStyle(PocketColor.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder private func reading(_ reading: JournalTimeline.Reading) -> some View {
        if case .loop(let mastery, let percent) = reading {
            MasteryReadout(mastery: mastery)
            Text(percent.map { "\($0)%" } ?? "—")
        }
    }

    /// "12 Oct", with the year once it isn't this one.
    private var since: String {
        let thisYear = Calendar.current.isDate(span.since, equalTo: .now, toGranularity: .year)
        return thisYear ? span.since.formatted(.dateTime.day().month(.abbreviated))
            : span.since.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
