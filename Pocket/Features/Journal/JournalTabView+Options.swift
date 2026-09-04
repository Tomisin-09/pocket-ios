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
            if visibleDays.count > 1 {
                Section {
                    Button {
                        // Seeded from the newest visible day rather than today, so the picker opens
                        // somewhere the journal actually reaches. A wheel resting on a date the feed
                        // has nothing at is a control that looks broken before it is touched.
                        jumpDay = visibleDays.max() ?? Date()
                        jumping = true
                    } label: {
                        Label("Jump to…", systemImage: "calendar")
                    }
                }
            }
            Picker("Sort", selection: $sortOrder) {
                Label("Newest first", systemImage: "arrow.down").tag(JournalTimeline.SortOrder.newest)
                Label("Oldest first", systemImage: "arrow.up").tag(JournalTimeline.SortOrder.oldest)
            }
            Section {
                // **A row that opens a sheet, not a submenu — because the facet is multi-select**
                // (ADR 0190 D10). Every tap inside a popup `Menu` dismisses it, so ticking three
                // kinds there would mean opening the menu three times; and the union relation needs
                // a sentence saying that ticking more shows *more*, which a menu has nowhere to put.
                // That is the standing reason `OptionListSection` and friends exist at all.
                //
                // The row states the selection where the old submenu could not: `.pickerStyle(.menu)`
                // drew a bare "Show ›" and left the filled glyph and the empty state as the only
                // places the active kinds were legible. Both still carry it — this is the third.
                Button {
                    choosingKinds = true
                } label: {
                    Label(showRowTitle, systemImage: "line.3.horizontal.decrease")
                }
                Toggle(isOn: $pinnedOnly) {
                    Label("Pinned only", systemImage: pinnedOnly ? "pin.fill" : "pin")
                }
            }
        } label: {
            Image(systemName: isFiltered ? "ellipsis.circle.fill" : "ellipsis.circle")
        }
        .accessibilityLabel(optionsLabel)
    }

    /// Whether the feed is showing something other than everything the scope allows. Sort is not a
    /// filter and doesn't count: it reorders the same rows.
    var isFiltered: Bool { pinnedOnly || ownerFilter.isFiltering }

    /// **Show** on its own, or the kinds in force — `"Show: Loop or Session"`, `"Show: 3 kinds"`.
    /// Capped at two by `summary`, because a menu row is one line and four labels are not.
    var showRowTitle: String {
        guard let summary = ownerFilter.summary else { return "Show…" }
        return "Show: \(summary)"
    }

    /// Named for VoiceOver, which cannot see the glyph fill that carries this for everyone else.
    /// Both filters are reported when both are on: "showing pinned only" alone would be a half-truth
    /// about a feed narrowed twice.
    var optionsLabel: String {
        var parts = ["Journal options"]
        if pinnedOnly { parts.append("showing pinned only") }
        // Names the **relation**, not just the count (ADR 0159 §3): "filtered to 2 kinds" states the
        // number and hides the thing a VoiceOver user has no other way to learn — that ticking a
        // second kind widened the feed rather than narrowing it. `phrase` spells the kinds out with
        // "or" between them, and there are at most five.
        if let phrase = ownerFilter.phrase { parts.append("showing \(phrase)") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Which kinds (ADR 0190 D5, D10)

    /// The owner-kind facet as a sheet: **All**, then the five kinds, each independently tickable.
    ///
    /// Ticking two **widens** the feed (ADR 0159's *OR within a facet*), which is the opposite of
    /// what every list a player has priors from does with a second tick — so the section footer says
    /// it outright. That sentence is the reason this is a sheet: a `Menu` has nowhere to put prose,
    /// and this is a control that needs one line of it.
    ///
    /// *All* is a **clear**, not a sixth kind. An empty selection already means "everything", so
    /// there is no `all` value in the model competing to represent the same state — the row is
    /// checked exactly when nothing else is.
    var ownerFilterSheet: some View {
        NavigationStack {
            Form {
                MultiOptionListSection(
                    header: "Show",
                    footer: "Pick more than one to see more — an entry shows if it matches any of "
                        + "them. Pick none to see everything.",
                    clearTitle: "All",
                    options: JournalTimeline.OwnerFilter.allCases.map {
                        PickerItem(value: $0, title: $0.label)
                    },
                    selection: kindsBinding,
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
                DatePicker("Day", selection: $jumpDay, in: jumpRange,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(PocketColor.journal)
                    .padding(.horizontal, 12)
                // `fixedSize` and the layout priority are both required at the `.medium` detent: the
                // graphical `DatePicker` grows to whatever it is offered, and without them this line
                // is the thing that gives — squeezed to one truncated row ending in an ellipsis,
                // which is the half of the sentence that carries the rule.
                Text("Lands on the nearest day at or before the one you pick.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Jump") { jump(to: jumpDay) }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.journal)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The span the picker offers — the visible feed's own first and last day. Falls back to a single
    /// day on an empty feed, which the menu item's `count > 1` gate means is never actually reached;
    /// it is here because `DatePicker` needs a non-optional range and a crash-on-empty would be a
    /// worse way to record that invariant.
    private var jumpRange: ClosedRange<Date> {
        guard let first = visibleDays.min(), let last = visibleDays.max() else {
            let today = Calendar.current.startOfDay(for: Date())
            return today...today
        }
        return first...last
    }

    /// Dismiss, then scroll. Resolving through the pure `JournalTimeline.jumpTarget` keeps the
    /// at-or-before rule (and its fall-forwards edge case) testable without a view.
    private func jump(to day: Date) {
        jumping = false
        scrollTarget = JournalTimeline.jumpTarget(for: day, in: visibleDays)
    }
}
