import SwiftUI

/// The Journal feed's **list, its rows and its two date controls** (ADR 0207 D5–D7), split out of
/// `JournalTabView` for the 400-line cap — the same reason `+EmptyState`, `+Options` and `+Deletion`
/// exist. That file was at 391 lines before the month rail arrived.
///
/// Nothing here is `private`: `private` is file-scoped in Swift, and `JournalTabView.body` reads
/// `list` and `monthRail`.
extension JournalTabView {

    // MARK: - The feed, built once

    /// One render's feed, built **once** in `body` and handed to everything that reads it. These used to be
    /// computed properties, and every read rebuilt the feed from the queries: each day header read three of
    /// them, so a journal of 40 days rebuilt it 277 times on opening, decoding every piece each time.
    struct Feed {
        /// Everything, minus anything awaiting deletion, before any filter: what the counts are made from,
        /// and a thread's first-to-latest line.
        let merged: [JournalTimeline.Item]
        /// The feed's scope and filters applied, or a thread's unit under its own scope. Filtering here
        /// rather than at the row is what makes `sections` and the empty state follow automatically.
        let items: [JournalTimeline.Item]
        /// Day-sectioned for display; `oldest` reverses both the day order and the within-day order.
        let sections: [JournalGrouping.DaySection<JournalTimeline.Item>]
        /// The days the feed is showing: what a jump can land on, and what the month rail and the month
        /// grid are both built from. Read from `sections` rather than from every entry, since you can only
        /// jump to a day that is on screen. None under **Pieces**, which is grouped by song (ADR 0232 D20),
        /// so its rail offers no months and **Jump to…** goes.
        let visibleDays: [Date]
        /// Whether there is anywhere to jump *to*: more than one day on the feed. Shared by the day header
        /// (ADR 0207 D7) and the ⋯ item, so the two doors to one sheet cannot disagree.
        var canJump: Bool { visibleDays.count > 1 }
    }

    /// This render's feed. Call it once, from `body`.
    func makeFeed() -> Feed {
        let merged = JournalTimeline.merge(entries: entries, takes: takes, pieces: JournalPiece.all(in: loops))
            .filter { !rowDeletion.isPending($0.id) }
        let items: [JournalTimeline.Item]
        if let thread {
            // A thread is the whole unit under its own scope: search, pins and Show don't narrow it (ADR 0286).
            items = JournalTimeline.filter(JournalTimeline.filter(merged, unit: thread), scope: threadScope)
        } else {
            let scoped = JournalTimeline.filter(merged, scope: scope)
            let owned = JournalTimeline.filter(scoped, owner: ownerFilter)
            let tagged = JournalTimeline.filter(owned, tags: tagFilter)
            let pinned = JournalTimeline.filter(tagged, pinnedOnly: pinnedOnly)
            items = JournalTimeline.filter(pinned, query: query)
        }
        let grouped = JournalGrouping.byDay(items) { $0.date }
        let sections = switch sortOrder {
        case .newest: grouped
        case .oldest: grouped.reversed().map {
            JournalGrouping.DaySection(day: $0.day, entries: Array($0.entries.reversed()))
        }
        }
        return Feed(merged: merged, items: items, sections: sections,
                    visibleDays: groupsBySong ? [] : sections.map(\.day))
    }

    // MARK: - The month rail (ADR 0207 D6)

    /// Shown whenever the journal holds **anything at all**, filters aside.
    ///
    /// Not gated on the *filtered* feed, because the Show chip is the thing ADR 0190 D8 requires to
    /// be visible — and since ADR 0207 D11 it carries **both** facets, so hiding the rail when a
    /// filter empties the screen would hide two filters exactly when they most need stating. Gated on
    /// a genuinely empty journal, because a fresh install should
    /// not meet a filter control before it has met a single entry — the same rule `HomeStatsStrip`
    /// applies to a week with no runs.
    ///
    /// Its months come from `visibleDays`, the *sections*, not every stored entry, so the rail inherits
    /// every active filter for free. A rail offering a month the filters have emptied would be a door to
    /// an empty room.
    @ViewBuilder func monthRail(_ feed: Feed) -> some View {
        if hasAnyHistory {
            JournalMonthRail(months: JournalMonthLayout.months(in: feed.visibleDays),
                             showTitle: showRowTitle,
                             isFiltering: showIsFiltering,
                             onChooseKinds: { choosingKinds = true },
                             onPickMonth: { month in
                                 scrollTarget = JournalMonthLayout.firstDay(inMonth: month,
                                                                           of: feed.visibleDays)
                             })
        }
    }

    // MARK: - The look-back card (ADR 0207 D8)

    /// What the journal hands back unprompted, or nothing.
    ///
    /// Reads **`entries`, unfiltered**: this is not a feed row, so it is not subject to the feed's
    /// filters — narrowing to *Pinned only* should not silently change which year-old note the app
    /// offers you. Takes are excluded because the card quotes words and a take has none.
    var lookback: JournalLookback.Hit<JournalEntry>? {
        JournalLookback.find(in: entries.map { (element: $0, date: $0.createdAt) },
                             period: JournalLookback.Period(raw: lookbackPeriod))
    }

    /// Inside the `List` and above the first day section, so it **scrolls away** — which is the
    /// difference between this and the permanent strip ADR 0176 refused.
    ///
    /// Hidden while searching (a search is a question, and this is not part of the answer — the same
    /// reasoning the practice-log row carries) and under the **Takes** and **Pieces** scopes, where the
    /// player has asked for something else and this card only ever quotes writing.
    @ViewBuilder func lookbackRow(_ feed: Feed) -> some View {
        if !searching, scope == .all || scope == .notes, let hit = lookback {
            JournalLookbackCard(
                heading: hit.reach.heading(for: JournalLookback.Period(raw: lookbackPeriod)),
                text: hit.element.text,
                ownerLabel: JournalTimeline.ownerLabel(for: .note(hit.element)),
                day: hit.day,
                onOpen: { scrollTarget = JournalTimeline.jumpTarget(for: hit.day, in: feed.visibleDays) })
                .listRowBackground(PocketColor.background)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
        }
    }

    // MARK: - List

    /// Wrapped in a `ScrollViewReader` for **Jump to…** and the month rail (ADR 0190 D9, ADR 0207
    /// D6). Each `Section` carries `.id(section.day)`, so a day is the scroll target for both.
    ///
    /// The id is set explicitly rather than inherited from `ForEach(_:id:)` — the loop now runs over
    /// indices so a header can see the section *before* it and decide whether a month has turned
    /// over, and without the explicit id that change would silently break every jump.
    func list(_ feed: Feed) -> some View {
        // Counted **once** per render and looked up per row (ADR 0286), over the feed's scope and nothing
        // else, so a count is the rows its thread opens on. A thread's own rows carry no count.
        let counts = thread == nil
            ? JournalTimeline.unitCounts(JournalTimeline.filter(feed.merged, scope: scope)) : [:]
        return ScrollViewReader { proxy in
            List {
                if let thread { threadHeaderRow(thread, feed: feed) } else { lookbackRow(feed) }
                if groupsBySong {
                    songSections(feed.items)
                } else {
                    ForEach(Array(feed.sections.enumerated()), id: \.element.day) { index, section in
                        Section {
                            ForEach(section.entries) { item in
                                row(item, counts: counts).listRowBackground(PocketColor.background)
                            }
                        } header: {
                            sectionHeader(section.day, startsMonth: startsNewMonth(at: index, in: feed.sections),
                                          feed: feed)
                        }
                        .id(section.day)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // Cleared as it is consumed, so asking for the same day twice scrolls twice — with the
            // value left set, the second request would be no change at all and simply not fire.
            .onChange(of: scrollTarget) { _, day in
                guard let day else { return }
                withAnimation { proxy.scrollTo(day, anchor: .top) }
                scrollTarget = nil
            }
        }
    }

    /// Whether this section opens a month the one above it was not in. `true` for the first section,
    /// which is what puts a month label at the top of the feed rather than leaving the first month
    /// the only unnamed one.
    func startsNewMonth(at index: Int, in sections: [JournalGrouping.DaySection<JournalTimeline.Item>]) -> Bool {
        guard index > 0 else { return true }
        let current = JournalMonthLayout.month(containing: sections[index].day)
        let previous = JournalMonthLayout.month(containing: sections[index - 1].day)
        return current != previous
    }

    // MARK: - Section header

    /// A day header, optionally under a month divider.
    ///
    /// **The day header is the jump control** (ADR 0207 D7). `.listStyle(.plain)` already pins it to
    /// the top while you scroll, which makes it the one thing on screen that is both always visible
    /// and already about *when* — so it is where a player wondering what day they are looking at will
    /// look, and therefore where the door belongs. ADR 0176 moved the practice log out of the ⋯ menu
    /// on the finding that *a destination reached only from a menu is one most players never find*;
    /// **Jump to…** had exactly that problem and this is the same fix.
    ///
    /// The ⋯ item stays. This one is discoverable, that one is labelled, and VoiceOver reaches the
    /// menu without having to find a header that happens to be a button.
    @ViewBuilder func sectionHeader(_ day: Date, startsMonth: Bool, feed: Feed) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if startsMonth { monthDivider(day) }
            if feed.canJump {
                Button { beginJump(days: feed.visibleDays) } label: {
                    HStack(spacing: 5) {
                        Text(dayHeader(day))
                        Image(systemName: "calendar")
                            .font(.futura(.caption2, weight: .semibold))
                            .foregroundStyle(PocketColor.journal)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dayHeader(day)). Jump to a date")
            } else {
                // One day in the whole feed: there is nowhere to jump to, and a control that opens a
                // picker offering the day you are already on is a promise the tap can't keep.
                Text(dayHeader(day))
            }
        }
    }

    /// The month a run of days belongs to — drawn once, where the month turns over.
    ///
    /// A day header says *Today* or *26 Aug*; neither says which year, and after a year of entries a
    /// long scroll has nothing to grip. This is the cheapest possible structure: one label, no
    /// control, no state.
    @ViewBuilder func monthDivider(_ day: Date) -> some View {
        HStack(spacing: 10) {
            Text(day.formatted(.dateTime.month(.wide).year()).uppercased())
                .font(.futura(.caption2, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PocketColor.journal)
            Rectangle()
                .fill(PocketColor.surfaceStandard)
                .frame(height: 1)
        }
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }

    /// "Today" / "Yesterday" / a medium date for a section's day (mirrors `JournalSheet`).
    func dayHeader(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Rows

    /// One feed row. In a thread (ADR 0286) the caption goes: every row is the same unit, and the header
    /// names it once, as the Pieces list's song heading does for its rows.
    @ViewBuilder func row(_ item: JournalTimeline.Item,
                          counts: [JournalTimeline.UnitRef: Int] = [:]) -> some View {
        let link = threadLink(for: item, counts: counts)
        let caption = thread == nil ? JournalTimeline.ownerLabel(for: item) : nil
        switch item {
        case .note(let entry):
            JournalEntryRow(entry: entry, ownerLabel: caption,
                            onOpenOwner: openAction(for: item),
                            openUnit: openAction(for:), thread: link)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) { deleteSwipe(for: item) }
                .contextMenu { holdMenu(for: item, thread: link) }
        case .take(let take):
            JournalTakeRow(take: take,
                           ownerLabel: caption,
                           onOpenOwner: openAction(for: item),
                           isPlaying: player.isPlaying(take.fileName),
                           onToggle: { player.toggle(take.fileName) },
                           onOpen: { openedTake = StableRef(value: take) },
                           thread: link)
            // Naming is a take-only verb: every other row already says what it is in its own words.
            .swipeActions(edge: .leading) {
                Button { renaming = StableRef(value: take) } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(PocketColor.journal)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) { deleteSwipe(for: item) }
            .contextMenu { holdMenu(for: item, thread: link) }
        case .piece(let piece):
            // No hold menu: a piece isn't pinned or deleted from the feed (ADR 0229).
            JournalPieceRow(piece: piece, ownerLabel: caption,
                            onOpen: openAction(for: item), onWatch: watchAction(for: piece), thread: link)
        }
    }
}
