import SwiftUI

/// The unit a training tempo reads in (ADR 0082). An exercise's tempo is an absolute **BPM**; a loop's
/// is a **percent of original**, so every loop tempo reference carries a `%` and never a "BPM" suffix.
/// Value-only so the views using it stay SwiftData-free; top-level (not nested) to satisfy the nesting
/// limit. Shared by the completion nudge (`RoutineBlockDoneView`) and the staircase (`RoutineStairs`).
enum TempoUnit: Equatable {
    case bpm
    case percent

    /// The value with its unit for an **inline** reference — "85%" for a loop; bare "106" for BPM (a
    /// phrase like "Move command to 106" already reads as BPM from context, so no suffix is added).
    func inline(_ value: Int) -> String {
        self == .percent ? "\(value)%" : "\(value)"
    }

    /// The value as a **standalone** label (e.g. the staircase signpost) — "85%" for a loop, "106 BPM"
    /// for an exercise, where the unit must be explicit because there's no surrounding phrase.
    func signpost(_ value: Int) -> String {
        self == .percent ? "\(value)%" : "\(value) BPM"
    }
}

/// The **post-block Done screen** shown when a routine unit finishes on its own with manual advance
/// on (the default — ADR 0071 R4) — **and reused for a standalone exercise finish** (`upNext: nil`,
/// ADR 0079 §2), so a solo run and a routine block share one completion surface. It **collapses** the
/// earlier separate two-option reflection sheet into one surface: a completion beat, an *optional*
/// mastery tap, an *optional* inline journal note, an *optional* post-run command-revision toggle
/// (exercises, ADR 0079 §7 / ADR 0134), and a single primary **Continue / Finish** that commits them in one action (the P3
/// lesson — no competing "Add entry" button). In a routine a deliberate Skip bypasses this gate, and
/// auto-advance skips it entirely; it appears only for units that carry a journal (exercise/loop),
/// never a song/rest.
///
/// No evaluation (ADR 0070): mastery is the player's own self-rating, never a score the app measured,
/// and the revision is an opt-in offer, never an automatic bump — the app opens a range, the player
/// picks the number. The host commits; this view only gathers `(mastery, note, revision)` and hands
/// them back, so it stays SwiftData-free and previewable.
struct RoutineBlockDoneView: View {
    /// The just-finished block's title (the drill name) — the completion line names what you did.
    let title: String
    /// The unit's current self-rated mastery (0–5, `nil` = unrated), pre-filled so a tap *adjusts*
    /// rather than starts from blank.
    let initialMastery: Int?
    /// The tempo anchors the revision offer is sized from (ADR 0134), or `nil` for a unit that
    /// carries no offer at all (a routine's loop blocks, songs, rests).
    ///
    /// One value rather than a per-direction config, because none of it depends on the rating while
    /// *how the offer leans* does: the player chooses the lean by tapping the mastery dots on this
    /// screen, after it was built. `CommandOffer.bounds(for:anchors:)` turns a lean into a range.
    let anchors: CommandOffer.Anchors?
    /// How the revision value reads — bare BPM for an exercise, `%` for a loop (ADR 0082).
    let unit: TempoUnit
    /// Whether this is the last block — the primary reads **Finish** (→ end-of-routine summary)
    /// instead of **Continue** (→ next block / rest).
    let isLast: Bool
    /// The next **unit** coming up (rests skipped), shown so you know what you're continuing into
    /// (ADR 0071 R4b). `nil` when nothing playable remains.
    let upNext: UpNext?
    /// Commit the optional mastery (unchanged ⇒ pass through), the optional note **and its kind tag**
    /// (🎯/⚡️/🧗/📝/🎬 — defaults to `.note`, ADR 0100), and the accepted command revision — `nil`
    /// when the toggle is off, else a `.raise`/`.settle` carrying the chosen (possibly custom) value
    /// (ADR 0079 §7, ADR 0134) — then advance.
    let onContinue: (_ mastery: Int?, _ note: String, _ kind: EntryKind,
                     _ revision: CommandOffer.Revision?) -> Void

    /// A plain descriptor of the upcoming unit — kept value-only so this view stays SwiftData-free
    /// (the host builds it from the next stage).
    struct UpNext: Equatable {
        let title: String
        let detail: String?
        let symbol: String
    }

    @State var mastery: Int?
    @State private var note = ""
    /// The note's kind tag (ADR 0100) — defaults to a plain `.note`, so an untagged completion note
    /// behaves exactly as before; a tap upgrades it to a goal/breakthrough/struggle/session.
    @State private var kind: EntryKind = .note
    @FocusState private var noteFocused: Bool
    /// Whether to commit the revision on Continue — opt-in, default off (ADR 0079 §7, ADR 0134 §5).
    @State var revisionOn = false
    /// The command value to revise to — the active config's default, editable within its bounds.
    @State var revisionValue: Int

    init(title: String, initialMastery: Int?,
         anchors: CommandOffer.Anchors? = nil, unit: TempoUnit = .bpm,
         isLast: Bool, upNext: UpNext?,
         onContinue: @escaping (_ mastery: Int?, _ note: String, _ kind: EntryKind,
                                _ revision: CommandOffer.Revision?) -> Void) {
        self.title = title
        self.initialMastery = initialMastery
        self.anchors = anchors
        self.unit = unit
        self.isLast = isLast
        self.upNext = upNext
        self.onContinue = onContinue
        _mastery = State(initialValue: initialMastery)
        // Seeded from whatever the *pre-filled* rating leans toward, so the stepper opens on a
        // sensible number before any tap; `.onChange(of: activeBounds)` re-seeds it after one.
        let initial = anchors.flatMap { anchors in
            CommandOffer.stance(mastery: initialMastery, anchors: anchors)
                .flatMap { CommandOffer.bounds(for: $0, anchors: anchors) }
        }
        _revisionValue = State(initialValue: initial?.defaultTarget ?? 0)
    }

    var body: some View {
        KeyboardFollowingScroll {
            ScrollView {
                VStack(spacing: 28) {
                    completionBeat
                    masteryTap
                    tagSelector
                    noteField
                    if let activeStance, let activeBounds { revisionRow(activeStance, activeBounds) }
                    if let upNext { upNextCard(upNext) }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }
        }
        // A rating tap can re-lean the row (ADR 0134 §2), so the editable value has to be re-seeded —
        // otherwise a player who taps 5 and then 2 carries a raise target into a settle row. Flipping
        // the toggle off with it means a re-lean is never committed unseen.
        .onChange(of: activeBounds) { _, updated in
            revisionValue = updated?.defaultTarget ?? 0
            revisionOn = false
        }
        .animation(.easeInOut(duration: 0.2), value: activeStance)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { continueBar }
        .background(PocketColor.background.ignoresSafeArea())
    }

    // MARK: - Pieces

    private var completionBeat: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(PocketColor.practice)
                .accessibilityHidden(true)
            Text("Nice work")
                .font(.futura(.title2, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(title)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var masteryTap: some View {
        VStack(spacing: 10) {
            Text("How clean did that feel?")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { value in
                    Circle()
                        .fill(value <= (mastery ?? 0) ? PocketColor.mastery : PocketColor.barDefault)
                        .frame(width: 22, height: 22)
                        .onTapGesture {
                            // Tap sets the value; tapping the lowest filled dot walks it down, below
                            // 1 clears to unrated — mirrors the detail-sheet control exactly.
                            mastery = (mastery == value) ? (value == 1 ? nil : value - 1) : value
                            haptic(.light)
                        }
                        .accessibilityLabel("Set mastery to \(value)")
                }
            }
            // The invitation lives here because this is the only place the player learns that rating
            // honestly does anything for them beyond scheduling (ADR 0134 §5). Stated once, quietly.
            Text("Optional — an honest low rating brings the drill back sooner, and can settle it "
                 + "to a tempo you own.")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    /// The **kind tag** for the note (ADR 0100) — the same 🎯/⚡️/🧗/📝/🎬 vocabulary as the full
    /// journal composer, so the moment right after a run can be captured as a breakthrough or a
    /// struggle, not just a generic note. `.note` is preselected, so doing nothing keeps the old
    /// behaviour. The row itself is `EntryKindChipRow`, shared with the mid-run capture sheet
    /// (ADR 0142) so both surfaces tag from one vocabulary.
    private var tagSelector: some View {
        EntryKindChipRow(selection: $kind)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            TextField("Jot how it went…", text: $note, axis: .vertical)
                .font(.futura(.body))
                .lineLimit(2...5)
                .padding(12)
                .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
                // The note grows vertically, so Return inserts a newline — give the keyboard its own
                // checkmark to dismiss it (there's otherwise no way off the keyboard).
                .keyboardDoneButton()
                .scrollsIntoViewWhenFocused("note", focused: $noteFocused)
        }
    }

    private func upNextCard(_ next: UpNext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up next")
                .font(.futura(.caption, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(PocketColor.textSecondary)
            HStack(spacing: 12) {
                Image(systemName: next.symbol)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(PocketColor.practiceCircleWash))
                VStack(alignment: .leading, spacing: 3) {
                    Text(next.title)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    if let detail = next.detail {
                        Text(detail)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.practice)
                    }
                }
                Spacer(minLength: 4)
            }
            .padding(12)
            .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Up next: \(next.title). \(next.detail ?? "")")
    }

    private var continueBar: some View {
        Button {
            onContinue(mastery, note, kind, acceptedRevision)
        } label: {
            Label(isLast ? "Finish" : "Continue",
                  systemImage: isLast ? "flag.checkered" : "arrow.right")
                .pocketRunButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(PocketColor.background)
    }
}

/// Both offers, on a drill rated 4 — the row opens on the **raise**. Tapping down to 2 flips it to
/// the settle in place, which is the interaction worth watching in the canvas (ADR 0134 §2).
/// An exercise at command 100 with plenty of room either way. Rated 4, so the row opens leaning
/// **raise** — tapping down to 2 re-leans it to settle, and to 3 removes it. That live re-lean is the
/// interaction worth watching in the canvas (ADR 0134 §2).
#Preview("Block done · rated 4, leans raise") {
    RoutineBlockDoneView(title: "Alternate picking · 8ths",
                         initialMastery: 4,
                         anchors: .init(command: 100, floor: 30, ceiling: 300,
                                        raiseTarget: 106, settleTarget: 94),
                         isLast: false,
                         upNext: .init(title: "A Minor Pentatonic",
                                       detail: "Command 92 → 98 BPM",
                                       symbol: "point.topleft.down.curvedto.point.bottomright.up")) { _, _, _, _ in }
}

/// The same drill rated 2 — opens leaning **settle**, so that copy can be read at rest.
#Preview("Block done · rated 2, leans settle") {
    RoutineBlockDoneView(title: "Alternate picking · 8ths",
                         initialMastery: 2,
                         anchors: .init(command: 100, floor: 30, ceiling: 300,
                                        raiseTarget: 106, settleTarget: 94),
                         isLast: true,
                         upNext: nil) { _, _, _, _ in }
}

/// **Unrated** — the neutral prompt, spanning the whole instrument and opening on the command it
/// already sits at, so committing without moving the stepper changes nothing.
#Preview("Block done · unrated, neutral") {
    RoutineBlockDoneView(title: "Alternate picking · 8ths",
                         initialMastery: nil,
                         anchors: .init(command: 100, floor: 30, ceiling: 300,
                                        raiseTarget: 106, settleTarget: 94),
                         isLast: true,
                         upNext: nil) { _, _, _, _ in }
}

/// A loop finish — percent units throughout (ADR 0082), rated low so the settle reads in `%`.
#Preview("Block done · loop settle") {
    RoutineBlockDoneView(title: "Chorus · bars 33–40",
                         initialMastery: 1,
                         anchors: .init(command: 85, floor: 25, ceiling: 150,
                                        raiseTarget: 90, settleTarget: 80),
                         unit: .percent,
                         isLast: true,
                         upNext: nil) { _, _, _, _ in }
}
