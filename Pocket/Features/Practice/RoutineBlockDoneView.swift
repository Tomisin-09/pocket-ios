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
/// mastery tap, an *optional* inline journal note, an *optional* post-run promote toggle (exercises,
/// ADR 0079 §7), and a single primary **Continue / Finish** that commits them in one action (the P3
/// lesson — no competing "Add entry" button). In a routine a deliberate Skip bypasses this gate, and
/// auto-advance skips it entirely; it appears only for units that carry a journal (exercise/loop),
/// never a song/rest.
///
/// No evaluation (ADR 0070): mastery is the player's own self-rating, never a score the app measured,
/// and the promote is an opt-in offer, never an automatic bump. The host commits — this view only
/// gathers `(mastery, note, promote)` and hands them back — so it stays SwiftData-free and previewable.
struct RoutineBlockDoneView: View {
    /// The just-finished block's title (the drill name) — the completion line names what you did.
    let title: String
    /// The unit's current self-rated mastery (0–5, `nil` = unrated), pre-filled so a tap *adjusts*
    /// rather than starts from blank.
    let initialMastery: Int?
    /// The promote offer (ADR 0079 §7), or `nil` for no promote row — set only for an exercise unit
    /// whose reach sits above command; `nil` for loops/songs and when there's nothing to promote. When
    /// present, the row's target is **editable** (custom command value), defaulting to the reach.
    let promote: PromoteConfig?
    /// Whether this is the last block — the primary reads **Finish** (→ end-of-routine summary)
    /// instead of **Continue** (→ next block / rest).
    let isLast: Bool
    /// The next **unit** coming up (rests skipped), shown so you know what you're continuing into
    /// (ADR 0071 R4b). `nil` when nothing playable remains.
    let upNext: UpNext?
    /// Commit the optional mastery (unchanged ⇒ pass through), the optional note **and its kind tag**
    /// (🎯/⚡️/🧗/📝/🎬 — defaults to `.note`, ADR 0100), and the command to promote to — `nil` when
    /// the promote toggle is off, else the chosen (possibly custom) value (ADR 0079 §7) — then advance.
    let onContinue: (_ mastery: Int?, _ note: String, _ kind: EntryKind, _ promoteTo: Int?) -> Void

    /// The bounds of the promote row's editable command value: where it defaults (the reach, clamped
    /// to the ceiling), and the range the ±/typed value may take — from just above the current command
    /// up to the ceiling — plus how that value **reads** (ADR 0082). Kept value-only so the view stays
    /// SwiftData-free.
    struct PromoteConfig: Equatable {
        let defaultTarget: Int
        let minValue: Int
        let maxValue: Int
        /// How the value is unit-labelled. Defaults to bare BPM (exercises); loops set `.percent`.
        var unit: TempoUnit = .bpm
    }

    /// A plain descriptor of the upcoming unit — kept value-only so this view stays SwiftData-free
    /// (the host builds it from the next stage).
    struct UpNext: Equatable {
        let title: String
        let detail: String?
        let symbol: String
    }

    @State private var mastery: Int?
    @State private var note = ""
    /// The note's kind tag (ADR 0100) — defaults to a plain `.note`, so an untagged completion note
    /// behaves exactly as before; a tap upgrades it to a goal/breakthrough/struggle/session.
    @State private var kind: EntryKind = .note
    /// Whether to promote command on Continue — opt-in, default off (ADR 0079 §7).
    @State private var promoteOn = false
    /// The command value to promote to — defaults to the reach, editable within the config's bounds.
    @State private var promoteValue: Int

    init(title: String, initialMastery: Int?, promote: PromoteConfig? = nil, isLast: Bool, upNext: UpNext?,
         onContinue: @escaping (_ mastery: Int?, _ note: String, _ kind: EntryKind, _ promoteTo: Int?) -> Void) {
        self.title = title
        self.initialMastery = initialMastery
        self.promote = promote
        self.isLast = isLast
        self.upNext = upNext
        self.onContinue = onContinue
        _mastery = State(initialValue: initialMastery)
        _promoteValue = State(initialValue: promote?.defaultTarget ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                completionBeat
                masteryTap
                tagSelector
                noteField
                if let promote { promoteRow(promote) }
                if let upNext { upNextCard(upNext) }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
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
            Text("Optional — the planner resurfaces well-learned drills on its own.")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    /// The **kind tag** for the note (ADR 0100) — the same 🎯/⚡️/🧗/📝/🎬 vocabulary as the full
    /// journal composer, so the moment right after a run can be captured as a breakthrough or a
    /// struggle, not just a generic note. A horizontal row of selectable chips; `.note` is preselected,
    /// so doing nothing keeps the old behaviour. Neutral — a label, never a verdict (ADR 0070).
    private var tagSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tag this")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EntryKind.pickerOrder) { option in
                        tagChip(option)
                    }
                }
                .padding(.horizontal, 1)   // keeps selected chips' stroke from clipping at the edges
            }
        }
    }

    /// One selectable kind chip. Selected reads in the kind's own tint (shared `KindChip.tint`);
    /// unselected stays quiet so the row doesn't shout.
    private func tagChip(_ option: EntryKind) -> some View {
        let selected = option == kind
        let tint = KindChip.tint(for: option)
        return Button {
            kind = option
            haptic(.light)
        } label: {
            Text("\(option.emoji)  \(option.label)")
                .font(.futura(.subheadline, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? tint : PocketColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? tint.opacity(0.18) : PocketColor.surfaceStandard))
                .overlay(Capsule().stroke(selected ? tint : PocketColor.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
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
        }
    }

    /// The opt-in **promote** row (ADR 0079 §7) — offered only for an exercise that summited a reach
    /// above command. Default off; flipping it on commits the bump atomically with Continue, so the
    /// single primary stays the only action (no competing CTA). The target defaults to the reach but is
    /// **editable** via a ±/typed stepper once on, so the player can set a custom command they feel they
    /// own. Neutral framing — an offer, never a verdict (ADR 0070).
    private func promoteRow(_ config: PromoteConfig) -> some View {
        VStack(spacing: 12) {
            Toggle(isOn: $promoteOn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Move command to \(config.unit.inline(promoteValue))")
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("You summited it this run — bump the drill up.")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .tint(PocketColor.practice)
            if promoteOn { promoteStepper(config) }
        }
        .padding(12)
        .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: promoteOn)
        .onChange(of: promoteOn) { _, _ in haptic(.light) }
    }

    /// The custom-command adjuster shown when promote is on — nudge the target within the config's
    /// range (just above the current command, up to the BPM ceiling). `StepperButton` owns its own
    /// press/hold haptics, so the clamp closures stay pure.
    private func promoteStepper(_ config: PromoteConfig) -> some View {
        HStack(spacing: 16) {
            Text("New command")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            StepperButton(symbol: "minus", label: "Lower new command", tint: PocketColor.practice) {
                promoteValue = max(config.minValue, promoteValue - 1)
            }
            Text(config.unit.inline(promoteValue))
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(minWidth: 52)
                .contentTransition(.numericText())
            StepperButton(symbol: "plus", label: "Raise new command", tint: PocketColor.practice) {
                promoteValue = min(config.maxValue, promoteValue + 1)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
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
            onContinue(mastery, note, kind, promoteOn ? promoteValue : nil)
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

#Preview("Block done") {
    RoutineBlockDoneView(title: "Alternate picking · 8ths",
                         initialMastery: 2,
                         promote: .init(defaultTarget: 106, minValue: 93, maxValue: 300),
                         isLast: false,
                         upNext: .init(title: "A Minor Pentatonic",
                                       detail: "Command 92 → 98 BPM",
                                       symbol: "point.topleft.down.curvedto.point.bottomright.up")) { _, _, _, _ in }
}
