import SwiftData
import SwiftUI

/// **Build today's session** — the V2 planner's front door (ADR 0046 re-homes ADRs 0014–0016;
/// Slice 3). Pick how long you have (`SessionLength`), keep a short list of **goals** that shape what
/// surfaces, then **Generate** — the front-half (`CandidateDeriver`) expands your active goals into a
/// ranked pool and the back-half (`SessionBuilder`) lays out a timed session, materialised into a
/// provisional `Routine` you review before Starting (nothing persists until you Save or Start it).
///
/// With **no active goals** this falls back to a goal-less **Quick session** (Slice 1): due-ranked
/// exercises alone — so the button always produces something to practise.
struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [Goal]
    @Query private var exercises: [Exercise]
    @Query private var loops: [Loop]
    @Query private var songs: [Song]
    @Query private var routines: [Routine]
    /// The local profile (ADR 0113): its minutes-per-day seeds the initial session length (S2) and its
    /// genres + dream drive the goal-session emphasis mix (S3).
    @Query private var profiles: [Profile]
    /// The practice log (ADR 0117), read here for one thing only: **how recently each unit was
    /// practised** (ADR 0137). It is what gives a loop candidate a time axis — loops carry no stored
    /// `lastPracticed`, so without this every one of them ranks as never-practised.
    @Query private var practiceRuns: [PracticeRun]

    @State private var length: SessionLength = .default
    /// Whether this session is being built for practice **away from the instrument** (ADR 0139) —
    /// a constraint on the same planner, not a second one. Not persisted: it is a fact about *this
    /// afternoon*, not a preference, and a player who practised on a train yesterday should not find
    /// the planner still assuming it today.
    @State private var constraint: SessionConstraint = .none
    /// Which tier of goal this session draws on (ADR 0171 D10). Unpersisted for the same reason
    /// `constraint` is — a fact about this afternoon, not a preference.
    @State private var goalSource: SessionGoalSource = .both
    /// Seed the length from the profile only once, so revisiting the planner doesn't overwrite a
    /// duration the player just picked by hand.
    @State private var seededLength = false
    /// The goal being edited, presented as a sheet. Held as a `uid`-keyed `StableRef`, not the raw
    /// `Goal`: a goal added and edited in the same session has a temporary `persistentModelID` that
    /// flips on the first save, which would dismiss the editor mid-edit if the sheet were keyed on it
    /// (ADR 0090 / swiftdata-gotchas).
    @Query private var longTermGoals: [LongTermGoal]

    @State private var editingGoal: StableRef<Goal>?
    @State private var addingGoal = false
    /// Confirming "clear this session's goals" — a bulk delete gets a dialog, like every other
    /// destructive bulk action in the app.
    @State private var clearingGoals = false
    /// A freshly-generated session awaiting review — pushed as a provisional `RoutineDetailView`.
    @State private var draft: QuickSessionDraft?
    /// Shown when generation yields nothing runnable (no exercises, no resolvable target song).
    @State private var showingEmptyNotice = false

    /// The goals that actively shape a session (not marked met), newest first.
    private var activeGoals: [Goal] {
        goals.filter { !$0.isMet }.sorted { $0.dateAdded > $1.dateAdded }
    }

    private var metGoals: [Goal] {
        goals.filter(\.isMet).sorted { $0.dateAdded > $1.dateAdded }
    }

    /// The ranked standing goals that can still contribute.
    private var activeLongTermGoals: [LongTermGoal] {
        LongTermGoalStore.inRankOrder(longTermGoals).filter { !$0.isMet }
    }

    /// The source actually in force. Falls back to `.both` whenever the standing list is empty,
    /// because that is exactly when the `Build from` control is **not on screen** — and a hidden
    /// control must not still be steering anything.
    ///
    /// Without this there is a reachable dead end: pick `Long-term`, then mark the last standing
    /// goal met. The segment disappears (nothing left to choose between), but the stored selection
    /// would keep hiding the short-term section, leaving a planner with no goals on it at all and
    /// no visible way to get them back.
    private var effectiveSource: SessionGoalSource {
        activeLongTermGoals.isEmpty ? .both : goalSource
    }

    /// What Generate will actually draw on, resolved from the source and what has been authored.
    private var goalPlan: SessionGoalPlan {
        effectiveSource.plan(activeShortTermCount: activeGoals.count,
                             activeLongTermCount: activeLongTermGoals.count)
    }

    var body: some View {
        List {
            durationSection
            situationSection
            // Only worth asking once there is a second tier to choose between — with an empty
            // standing list the control would offer two options that behave identically.
            if !activeLongTermGoals.isEmpty { buildFromSection }
            // A tier the source excludes is **hidden, not dimmed**. Dimming was the first cut, on
            // the reasoning that a section which simply vanishes teaches nothing about what was
            // switched off — but that assumed the disappearance was unexplained. It isn't: the
            // labelled `Build from` segment sits directly above and names the state. The control is
            // the explanation, so the greyed-out copy was just noise to scroll past.
            //
            // Keyed on `drawsOn…`, not on `goalPlan.uses…`: the plan reports whether a tier has
            // anything to *contribute*, and an empty-but-selected tier still needs its section on
            // screen — that is where its "add one" affordance and empty state live.
            if effectiveSource.drawsOnShortTerm {
                PlannerGoalsSection(activeGoals: activeGoals, metGoals: metGoals,
                                    usesLongTerm: goalPlan.usesLongTerm,
                                    onAdd: { addingGoal = true; haptic(.light) },
                                    onEdit: { editingGoal = StableRef(value: $0); haptic(.light) },
                                    onClear: { clearingGoals = true; haptic(.medium) },
                                    onDelete: deleteGoal)
            }
            if effectiveSource.drawsOnLongTerm, !activeLongTermGoals.isEmpty {
                PlannerLongTermSection(goals: activeLongTermGoals)
            }
        }
        .scrollContentBackground(.hidden)
        // Five sections now stand between the top of the screen and Generate (ADR 0171 D10 added
        // two), and at the default grouped spacing the setup controls no longer fit on one screen.
        // Tightened rather than merged: each section still answers a different question, so they
        // need to stay separable — they just don't need a finger's width of air between them.
        .listSectionSpacing(14)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Today's session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: seedLengthFromProfile)
        .safeAreaInset(edge: .bottom) { generateBar }
        .confirmationDialog("Clear this session's goals?", isPresented: $clearingGoals,
                            titleVisibility: .visible) {
            Button("Clear \(activeGoals.count) goal\(activeGoals.count == 1 ? "" : "s")",
                   role: .destructive, action: clearGoals)
            Button("Cancel", role: .cancel) {}
        } message: {
            // Says what it spares as well as what it removes. Long-term goals are the ones a player
            // would most fear losing here, and they live on a different screen entirely — so the
            // dialog states that rather than leaving it to be discovered.
            Text("Removes the goals you set for this session. Your long-term goals aren't touched, "
                 + "and neither is anything you've practised.")
        }
        .sheet(isPresented: $addingGoal) {
            GoalEditorView(existing: nil, songs: songs)
        }
        .sheet(item: $editingGoal) { ref in
            GoalEditorView(existing: ref.value, songs: songs)
        }
        .navigationDestination(item: $draft) { draft in
            RoutineDetailView(container: context.container,
                              generatedSession: draft.blocks, defaultName: draft.name,
                              targetMinutes: draft.targetMinutes)
        }
        .alert("Nothing to schedule yet", isPresented: $showingEmptyNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(emptyNoticeMessage)
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        Section {
            Picker("How long?", selection: $length) {
                ForEach(SessionLength.allCases) { option in
                    // "~" because the preset is a count of blocks now, not a minute budget — the
                    // number is an estimate of the whole sitting (ADR 0129). Matches the grammar
                    // `CollectionSessionSheet` already uses for its Length tabs.
                    Text("\(option.displayName) · ~\(option.minutes)m").tag(option)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(PocketColor.background)
        } header: {
            Text("How long do you have?")
        }
    }

    // MARK: - Situation

    /// **Where you are, not what you own** (ADR 0139 O3). A toggle rather than a third segmented
    /// control: it is an occasional exception, and the ordinary case shouldn't have to be re-chosen
    /// every visit.
    ///
    /// The explanation sits behind the row's **ⓘ** rather than under the title. As a permanent
    /// three-line caption it cost more vertical space than any other control on the screen, on a
    /// setting most sittings leave alone — and `FieldInfoLabel` is what the app already uses for a
    /// coined field whose name doesn't carry its own meaning. The words are unchanged; only where
    /// they live is.
    private var situationSection: some View {
        Section {
            Toggle(isOn: Binding(get: { constraint == .offGuitar },
                                 set: { constraint = $0 ? .offGuitar : .none })) {
                FieldInfoLabel(title: SessionConstraint.offGuitar.displayName,
                               info: SessionConstraint.offGuitar.caption)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .tint(PocketColor.practice)
            .listRowBackground(PocketColor.background)
        }
    }

    // MARK: - Build from

    /// **Which goals shaped this?** (ADR 0171 D10). A segmented control rather than a toggle,
    /// because the three states are exclusive and equally ordinary — and because the segment labels
    /// are what name the distinction the two sections below then demonstrate.
    private var buildFromSection: some View {
        Section {
            Picker("Build from", selection: $goalSource) {
                ForEach(SessionGoalSource.allCases) { source in
                    Text(source.label).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(PocketColor.background)
        } header: {
            // The rule is **always** true, so it belongs behind the ⓘ. What stays in the footer is
            // the one thing that is only true *sometimes* — that the current selection has nothing
            // to contribute and Generate will do something else. An ⓘ is for what a control always
            // means; a footer is for what it is about to do.
            FieldInfoLabel(title: "Build from",
                           info: "Goals for this session are dealt first; long-term goals follow "
                                 + "in your ranking.")
        } footer: {
            if goalPlan.isQuickFallback {
                Text("Nothing selected has anything to contribute yet, so Generate will build a "
                     + "quick, due-based session from your exercises.")
                    .font(.futura(.caption))
            }
        }
    }

    /// Clear the goals shaping this sitting. **Only the active ones** — a met goal is already
    /// shaping nothing, and ADR 0015 S6's whole point is that marking something met *keeps* it. A
    /// clear-for-today that quietly binned the history would be the opposite of that.
    private func clearGoals() {
        for goal in activeGoals { context.delete(goal) }
        haptic(.medium)
    }

    private func deleteGoal(_ goal: Goal) {
        context.delete(goal)
        haptic(.medium)
    }

    // MARK: - Generate

    /// The bottom **Generate** button — the primary action. Produces a goal-driven session from the
    /// active goals (or a due-based Quick session when there are none), materialised as a provisional
    /// routine for review. If nothing resolves (empty library, unresolvable goals) it surfaces a
    /// notice rather than pushing an empty routine.
    private var generateBar: some View {
        Button(action: generate) {
            Label("Generate today's session", systemImage: "wand.and.stars")
                .font(.futura(.body, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PocketColor.practice, in: Capsule())
                .foregroundStyle(PocketColor.background)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .accessibilityLabel("Generate today's session")
    }

    /// What to do about an empty result — different advice for a different reason. An off-guitar
    /// session is built **only** from the player's loops (ADR 0139: it is as good as the loop
    /// library, and a brand-new player gets none at all), so telling them to add an exercise would
    /// send them off to make something this session can't use.
    private var emptyNoticeMessage: String {
        switch constraint {
        case .offGuitar:
            return "An away-from-your-instrument session is built from your loops. "
                 + "Set a loop over a section of one of your songs, then try again."
        case .none:
            return "Add an exercise, or give a \"learn a song\" goal a target song, then try again."
        }
    }

    /// Seed the duration picker from the profile's minutes-per-day once per screen (ADR 0113 S2
    /// consumer). Only a starting point — the player can change it freely, and an unset profile
    /// leaves the planner's own short default in place.
    private func seedLengthFromProfile() {
        guard !seededLength else { return }
        seededLength = true
        if let preferred = profiles.first?.minutesPerDay?.preferredSessionLength {
            length = preferred
        }
    }

    private func generate() {
        let active = activeGoals
        // The log's recency map is what gives a **loop** a time axis (ADR 0137). Both paths need it
        // now: an off-guitar Quick session is built entirely from loops, so without it every
        // candidate in it would rank as never-practised and the session would never rotate.
        let recency = PracticeLog.lastPracticedByUnit(practiceRuns.map(\.record))
        // Both tiers feed one derivation (ADR 0171 D3): today's goals lead the round-robin, and
        // the long-term tier follows in the player's rank order. Quick stays the answer only when
        // the player has stated no intent at all, in either tier.
        let plan = goalPlan
        let blocks: [SessionBlock] = plan.isQuickFallback
            ? PracticePlanner.planQuickSession(length: length, exercises: exercises, loops: loops,
                                               constraint: constraint, lastPracticed: recency)
            : PracticePlanner.planGoalSession(length: length,
                                              goals: plan.usesShortTerm ? active : [],
                                              longTermGoals: plan.usesLongTerm ? activeLongTermGoals : [],
                                              exercises: exercises, loops: loops, songs: songs,
                                              profile: profiles.first,
                                              lastPracticed: recency,
                                              constraint: constraint)
        guard blocks.contains(where: { $0.unit != nil }) else {
            showingEmptyNotice = true
            haptic(.medium)
            return
        }
        let name = QuickSessionNaming.defaultName(existing: routines.map(\.name), date: .now,
                                                  constraint: constraint)
        draft = QuickSessionDraft(blocks: blocks, name: name, targetMinutes: length.minutes)
        haptic(.light)
    }
}

#Preview("Planner — with goals") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Goal.self, Exercise.self, Song.self, Loop.self, Routine.self, PracticeRun.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let context = container.mainContext
    context.insert(Exercise(name: "Alternate picking", currentTempo: 70, commandTempo: 96))
    let speed = Goal(title: "Build speed", weight: 2.0,
                     skillIDs: ["pick.alternate", "pick.economy", "fret.legato"])
    context.insert(speed)
    context.insert(Goal(title: "Improvise", skillIDs: ["scale.pentatonic", "scale.blues"]))
    return NavigationStack { PlannerView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
