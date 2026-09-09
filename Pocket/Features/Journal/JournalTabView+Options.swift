import SwiftUI

/// **The Journal feed's list options** — the single `ellipsis.circle` toolbar item holding sort and
/// the two filters that don't fit in content (ADR 0190 D7).
///
/// Split out of `JournalTabView` for the 400-line cap, the same reason `JournalTabView+EmptyState`
/// and `JournalTabView+Deletion` were.
///
/// The shape is `LibraryOptionsMenu`'s, applied to the one list screen that doesn't use that control:
/// **one fixed-width trailing item holding sort and the boolean/kind filters**, filled whenever
/// anything but the defaults is in force. Fixed width matters on a nav bar — with
/// `.navigationBarTitleDisplayMode(.inline)` iOS centres the title in what is left after the bar
/// groups, so an item whose width tracks its state moves the title (ADR 0126). Filled matters because
/// these filters **persist** (D8): a filter that survives the trip away from the screen is only safe
/// while the screen admits, unopened, that it is on.
///
/// The segmented **All / Notes / Takes** control stays in content and out of here. It is the medium
/// axis, it is always visible, and three axes do not fit in one segmented control — the answer to
/// which is not four segments at compact width.
///
/// Two of the menu's rows open **sheets** rather than resolving in place (**Jump to…** and **Show**).
/// Both are here for the same reason: a popup `Menu` has nowhere to put prose, and each of these
/// needs a sentence — one to state the at-or-before rule, the other to state that ticking more kinds
/// shows more. `Menu` also dismisses on every tap, which a multi-select cannot survive (ADR 0190
/// D10).
///
/// Nothing here is `private`: `private` is file-scoped in Swift, and `JournalTabView.body` reads
/// `optionsMenu`.
extension JournalTabView {

    // MARK: - Toolbar

    /// Sort, then the filters. The practice log used to share this menu and no longer does (ADR
    /// 0176) — it is a *destination*, and a destination reached only from a menu is one most players
    /// never find.
    var optionsMenu: some View {
        Menu {
            // Actions above list options — `LibraryOptionsMenu`'s own grammar. Jumping is not a
            // filter: it changes where you are looking, not what is in the list.
            if canJump {
                Section {
                    Button { beginJump() } label: {
                        Label("Jump to…", systemImage: "calendar")
                    }
                }
            }
            Picker("Sort", selection: $sortOrder) {
                Label("Newest first", systemImage: "arrow.down").tag(JournalTimeline.SortOrder.newest)
                Label("Oldest first", systemImage: "arrow.up").tag(JournalTimeline.SortOrder.oldest)
            }
            Section {
                // **Show has left this menu** (ADR 0207 D6, amending ADR 0190 D7). It is now a fixed
                // chip on the month rail, which states the active kinds in words on a control that
                // is always on screen — a strictly better answer to D8's requirement than a filled
                // glyph, and the reason `showRowTitle` now has its reader elsewhere.
                Toggle(isOn: $pinnedOnly) {
                    Label("Pinned only", systemImage: pinnedOnly ? "pin.fill" : "pin")
                }
            }
            // Settings where you use them (ADR 0163) — this changes what the top of *this* feed
            // shows, so it belongs on this screen and not in the Settings hub. A `Picker` is safe
            // here where the owner facet was not: it is single-select, so the menu closing on the
            // first tap is the whole interaction rather than a third of it (ADR 0190 D10).
            Picker("Look back", selection: $lookbackPeriod) {
                ForEach(JournalLookback.Period.allCases) { period in
                    Text(period.label).tag(period.rawValue)
                }
            }
        } label: {
            Image(systemName: isFiltered ? "ellipsis.circle.fill" : "ellipsis.circle")
        }
        .accessibilityLabel(optionsLabel)
    }

    /// Whether **this menu** is holding a filter in force. Sort is not a filter and doesn't count:
    /// it reorders the same rows.
    ///
    /// The owner facet dropped out of this when it moved to the rail (ADR 0207 D6). The rule is
    /// unchanged and its application follows the control: a glyph fills to announce a filter the
    /// player would otherwise have to open it to see, and the owner filter is now announced by a
    /// chip that says it in words. Leaving it in here would fill the glyph for a filter this menu
    /// no longer contains — pointing at the wrong control.
    var isFiltered: Bool { pinnedOnly }

    /// **Show** on its own, or what is in force — `"Show: Loop or Session"`, `"Show: Idea"`,
    /// `"Show: Loop · Idea"`, `"Show: 3 kinds · 4 tags"`.
    ///
    /// Each facet is capped at two labels by its own `summary`, and the two are joined with **·**
    /// rather than "and": they are separate axes composed with AND (ADR 0159), and a chip that read
    /// *"Loop and Idea"* would say the same word the union inside each facet is deliberately not.
    /// The counts each name their own facet — *3 kinds*, *4 tags* — because on this chip they can
    /// appear side by side, and a bare number would not say which control to open.
    ///
    /// This is the whole of ADR 0190 D8's guarantee for both facets: whatever is narrowing the feed
    /// is legible without opening anything.
    var showRowTitle: String {
        let parts = [ownerFilter.summary, tagFilter.summary].compactMap { $0 }
        guard !parts.isEmpty else { return "Show…" }
        return "Show: \(parts.joined(separator: " · "))"
    }

    /// Whether the *Show* chip is holding anything — either facet. Fills the chip, and is the reason
    /// both facets can live behind one control: one chip, one filled state, one sentence.
    var showIsFiltering: Bool { ownerFilter.isFiltering || tagFilter.isFiltering }

    /// Named for VoiceOver, which cannot see the glyph fill that carries this for everyone else.
    ///
    /// **Reports only what this menu now holds**, which since ADR 0207 D6 is the pin alone. Both
    /// *Show* facets travel with their control to the rail, where the chip's own accessibility label
    /// carries them — announcing them here too would tell a VoiceOver user that a filter lives behind
    /// a menu that no longer offers it.
    var optionsLabel: String {
        pinnedOnly ? "Journal options, showing pinned only" : "Journal options"
    }

    // MARK: - Show: what it's about, and what it's tagged (ADR 0190 D5, D10; ADR 0207 D11)

    /// The **two facets behind one chip**: what an entry is *about* (its owner kind), and what it is
    /// *tagged* (its `EntryKind`).
    ///
    /// **Both live here rather than on two chips**, and that is the placement decision. D6's month
    /// rail spends its horizontal space on one fixed chip plus scrolling months; a second fixed chip
    /// would take that space from the months, and — worse — the two chips would have to truncate
    /// against each other exactly when both are in force, which is when D8 most needs them readable.
    /// One chip states both (`showRowTitle`), and this sheet is where they are set.
    ///
    /// Ticking two **within** a section widens the feed (ADR 0159's *OR within a facet*), which is the
    /// opposite of what every list a player has priors from does with a second tick — so each footer
    /// says it outright. Ticking across the two sections narrows: *Loop* + *Idea* is the ideas you had
    /// on a loop. That is ADR 0159's rule entire, and this is the first screen to show both halves of
    /// it at once.
    ///
    /// The clear rows are **clears**, not extra values. An empty selection already means "everything"
    /// in both models, so nothing competes to represent that state — each row is checked exactly when
    /// nothing else in its section is. They are named differently (*All*, *Any tag*) because two rows
    /// reading *All* in one form would look like one control drawn twice.
    var showSheet: some View {
        NavigationStack {
            Form {
                MultiOptionListSection(
                    header: "What it's about",
                    // **"Tap All", not "pick none".** An empty selection is how the *model* says
                    // "everything"; it is not a gesture, and a player cannot perform it. Naming a
                    // row they can actually tap is the same correction D8's empty-state copy already
                    // took — an instruction has to name a control that is on the screen.
                    footer: "Pick more than one to see more — an entry shows if it matches any of "
                        + "them. Tap All to see everything.",
                    clearTitle: "All",
                    options: JournalTimeline.OwnerFilter.allCases.map {
                        PickerItem(value: $0, title: $0.label)
                    },
                    selection: kindsBinding,
                    tint: PocketColor.journal)
                MultiOptionListSection(
                    header: "Tagged",
                    // Two sentences, and the second one is the load-bearing half. A tag filter
                    // **necessarily** removes every take — a take carries no tag at all — so a player
                    // who ticks 💡 Idea while the feed is on **Takes** is looking at a screen that can
                    // never fill. Saying it here is cheaper than letting them find out; the empty
                    // state says it again if they get there anyway.
                    footer: "Pick more than one to see more. Takes carry no tag, so any pick here "
                        + "leaves them out — tap Any tag to bring them back.",
                    clearTitle: "Any tag",
                    options: JournalTimeline.TagSelection.offered.map {
                        PickerItem(value: $0,
                                   title: "\($0.emoji)  \(JournalTimeline.TagSelection.label(for: $0))")
                    },
                    selection: tagsBinding,
                    tint: PocketColor.journal)
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Show")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { choosingKinds = false }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.journal)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The stored `OwnerSelection` as the `Set` the section edits. The selection is a
    /// `RawRepresentable` wrapper so it can cross `@AppStorage`, and the set is what a multi-select
    /// control speaks — one adaptor here beats either type bending to suit the other.
    private var kindsBinding: Binding<Set<JournalTimeline.OwnerFilter>> {
        Binding(get: { ownerFilter.kinds },
                set: { ownerFilter = JournalTimeline.OwnerSelection($0) })
    }

    /// The same adaptor for the tag facet.
    private var tagsBinding: Binding<Set<EntryKind>> {
        Binding(get: { tagFilter.tags },
                set: { tagFilter = JournalTimeline.TagSelection($0) })
    }

    // MARK: - Jump to a date (ADR 0190 D9)

    /// The date picker behind **Jump to…**. Choosing a day scrolls the feed to that day's section —
    /// the nearest one at or before it (`JournalTimeline.jumpTarget`), since most days have no entry.
    ///
    /// **Not a heatmap**, and the rejection is the interesting half (D9). `MonthHeatmap` was the
    /// obvious candidate, and it would have meant something different one screen away: the practice
    /// log's grid is shaded by *minutes practised*, a journal grid would be shaded by *entries
    /// written*, and two identical-looking grids counting different things one tap apart is worse
    /// than one grid. It is also the closer of the two to ADR 0070's line — shading a month by how
    /// often you wrote grades your compliance with a habit the app asked you for.
    ///
    /// The picker is bounded to `visibleDays`, so every date it offers is a date the list can
    /// actually reach.
    var jumpSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                JournalMonthGrid(daysWithEntries: Set(visibleDays),
                                 month: $jumpMonth,
                                 onPick: { day in jump(to: day) })
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Jump to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { jumping = false }
                        .tint(PocketColor.journal)
                }
                // **No Jump button.** There is nothing left to confirm: only a day that holds
                // something is tappable, so the tap *is* the choice. The graphical `DatePicker` had
                // to be confirmed because it would happily rest on a day the feed could not reach.
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Open the jump sheet on a month the journal actually reaches.
    ///
    /// Seeded from the newest visible day rather than today: a grid opening on a month with nothing
    /// in it is a control that looks broken before it is touched — the same reasoning the old picker's
    /// seed carried, applied to a month instead of a day.
    func beginJump() {
        jumpMonth = JournalMonthLayout.month(containing: visibleDays.max() ?? Date())
        jumping = true
    }

    /// Dismiss, then scroll.
    ///
    /// **The at-or-before rule no longer has anywhere to fire**, because the grid only offers days
    /// the feed holds — which is why the sheet lost the footnote that used to explain it.
    /// `JournalTimeline.jumpTarget` is still the resolver: it is pure and tested, it costs nothing,
    /// and the look-back card (ADR 0207 D8) hands it dates that genuinely need the rule.
    private func jump(to day: Date) {
        jumping = false
        scrollTarget = JournalTimeline.jumpTarget(for: day, in: visibleDays)
    }
}
