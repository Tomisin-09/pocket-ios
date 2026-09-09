import SwiftUI
import SwiftData

/// The Red Moon Oracle's one screen (ADR 0187 D15, D16).
///
/// It holds **no rules**. Every guard in this feature lives in `OracleCoordinator`, which runs them
/// in one order with no way around it; this view calls that and renders what comes back. A check
/// performed in a view is a check the next screen has to remember to repeat.
///
/// ### What it promises, and where
///
/// - **It never notifies** (D2). There is no badge, no dot and no scheduled anything. A reading
///   that has become available waits silently until somebody opens this screen.
/// - **It always says when the next one opens** (D15) — a date, not a tease. A gate that hides when
///   it lifts is metering, whatever it is called, and this screen is built so the honest version is
///   the easy one: `OracleCadence.nextReading` returns `nil` when a reading is available, so
///   "available now" and a future date cannot both be rendered.
/// - **It says where the words came from.** In S1 that is always the device.
///
/// Every fixed string lives in `OracleCopy`, both because D13's two messages are prose worth
/// reviewing as prose and because concatenated literals in a `ViewBuilder` stalled this file's
/// type-check outright before they moved.
struct OracleView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase = .waiting
    @State private var reading: OracleReadingText?
    @State private var capabilities: OracleCoordinator.Capabilities = .all

    private let log = OracleReadingLog()

    /// What the screen is doing. Deliberately small: this feature's states are *draw one*, *here is
    /// one*, and *here is the one thing a reading must never be*.
    private enum Phase: Equatable {
        case waiting
        case drawing
        case read
        /// D13's distress branch. It carries no text of its own by construction — nothing was
        /// generated, because there is no generated paragraph that is the right answer here.
        case distress
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                content
            }
            .padding(20)
            .readableWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Red Moon Oracle")
        .navigationBarTitleDisplayMode(.inline)
        .task { restoreThisWeeksReading() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .waiting:
            gate
        case .drawing:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        case .read:
            readingBody
        case .distress:
            DistressCard()
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.futura(.largeTitle))
                .foregroundStyle(PocketColor.oracle)
            Text(OracleCopy.subtitle)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(.bottom, 4)
    }

    // MARK: - The gate (D15)

    @ViewBuilder
    private var gate: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(windowLabel)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            if isAvailable {
                drawButton
            } else {
                nextReadingBlock
            }
        }
    }

    private var drawButton: some View {
        Button {
            Task { await draw() }
        } label: {
            Text(OracleCopy.drawButton)
                .font(.futura(.headline))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.oracleCardWash))
                .foregroundStyle(PocketColor.oracle)
        }
        .buttonStyle(.plain)
    }

    /// D15's requirement, rendered: the date, and why there is one.
    @ViewBuilder
    private var nextReadingBlock: some View {
        if let line = nextReadingLine {
            VStack(alignment: .leading, spacing: 6) {
                Text(line)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(OracleCopy.cadenceReason)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    // MARK: - The reading

    @ViewBuilder
    private var readingBody: some View {
        if let reading {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(reading.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    ParagraphView(paragraph: paragraph)
                }
                if !capabilities.mayProposeRoutine { painNote }
                Text(reading.source == .local ? OracleCopy.sourceLocal : OracleCopy.sourceModel)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                if let line = nextReadingLine {
                    Text(line)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }

    /// D13's pain branch, shown beside the reading it left standing. The reflection survives; only
    /// the doors that hand over more work are closed.
    private var painNote: some View {
        Text(OracleCopy.painNote)
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.oracleCardWash))
    }

    // MARK: - Derived

    /// Whether a fresh reading may be drawn. Read at render rather than cached in `@State`: the
    /// screen can be open across a week boundary, and a gate that only re-evaluated on appear would
    /// still be saying "Monday" on Monday.
    private var isAvailable: Bool {
        OracleCadence.isAvailable(now: .now, lastReading: log.lastReading)
    }

    /// `nil` exactly when a reading is available, so no caller can render "available now" and a
    /// future date at the same time.
    private var nextReadingLine: String? {
        guard let next = OracleCadence.nextReading(after: log.lastReading, now: .now) else { return nil }
        let date = next.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return "Your next reading opens on \(date)."
    }

    private var windowLabel: String {
        let window = OracleCadence.window(endingBefore: .now)
        let start = window.start.formatted(.dateTime.day().month(.abbreviated))
        // `DateInterval.end` is exclusive, so naming it directly would print the Monday after the
        // week the reading is about.
        let last = window.end.addingTimeInterval(-1).formatted(.dateTime.day().month(.abbreviated))
        return "The week of \(start) to \(last)"
    }

    // MARK: - Drawing one

    /// The reading already drawn this week, if there is one — the cadence limits drawing a *new*
    /// one, never re-reading the one you have.
    private func restoreThisWeeksReading() {
        guard !isAvailable, let stored = log.lastReadingText else { return }
        reading = stored
        phase = .read
    }

    /// Build the context, run the pipeline, show what comes back.
    ///
    /// The store read is `@MainActor` (a `@Model` is not `Sendable`); everything after it is plain
    /// values, which is exactly the split `ArchiveBuilder` makes and the reason `OracleContext`
    /// exists as its own type.
    private func draw() async {
        phase = .drawing
        let window = OracleCadence.window(endingBefore: .now)
        guard let source = try? OracleContextSource.forReading(in: modelContext) else {
            phase = .waiting
            return
        }
        let built = OracleContextBuilder.build(from: source,
                                               window: window,
                                               promptVersion: Self.promptVersion)

        // S1 has no proxy to call — `OracleEndpoint.isConfigured` is false in every build — so the
        // seam is the local one. From S2 this is where `ProxyOracle` is chosen instead, with the
        // same coordinator and the same fallback beneath it.
        let coordinator = OracleCoordinator(oracle: LocalOracle())
        let outcome = await coordinator.run(context: built.context)

        switch outcome {
        case .distress:
            // Nothing drawn, nothing spent, and no week-long gate for having written what they
            // wrote — `recordReading` is deliberately not called.
            phase = .distress
        case let .reading(text, allowed):
            reading = text
            capabilities = allowed
            log.recordReading(text, at: .now)
            phase = .read
        }
    }

    /// The prompt this build's context is written for (D17). It travels in the DTO so a recorded
    /// fixture can name the prompt it was captured against; in S1 nothing reads it but the tests.
    static let promptVersion = "reading-1"
}

/// One paragraph of a reading.
///
/// A quoted note is set apart — indented, with a rule down its left edge — because the player
/// should be able to see at a glance which words are theirs. That is the distinction
/// `OracleReadingText.Paragraph` carries for the tone guard, made visible.
private struct ParagraphView: View {
    let paragraph: OracleReadingText.Paragraph

    var body: some View {
        if paragraph.isQuotedFromPlayer {
            // The treatment now lives in `QuotedNoteView` (ADR 0207 D8), because the Journal's
            // look-back card quotes the player back at themselves for the same reason this does.
            // The tint stays here: crimson is how you know you are in the Oracle.
            QuotedNoteView(text: paragraph.text, tint: PocketColor.oracle)
        } else {
            Text(paragraph.text)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
        }
    }
}

/// D13's distress branch, as a fixed, human-written card. See `OracleCopy.Distress` for why every
/// word of it is owner-written and none of it is generated.
private struct DistressCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(OracleCopy.Distress.title)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text(OracleCopy.Distress.body)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Text(OracleCopy.Distress.signpost)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Text(OracleCopy.Distress.close)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.oracleCardWash))
    }
}
