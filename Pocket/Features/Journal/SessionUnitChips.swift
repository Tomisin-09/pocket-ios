import SwiftUI

/// The **"you practised…" header** on a session journal entry (ADR 0143) — the units the sitting was
/// made of, as a wrapping cloud of small pills.
///
/// A session entry belongs to no unit, so unlike every other row on the feed it cannot lean on
/// `JournalTimeline.ownerLabel` to say what it is about. This is what makes it readable: the routine
/// name is the caption, and these are the blocks under it.
///
/// **A pill is a link only when it can keep the promise** (ADR 0142 J5a). The refs are loose id
/// copies, so a unit deleted since the session no longer resolves — that pill renders dimmed and
/// untappable rather than as a tap that leads nowhere. The same honesty rule the owner caption
/// follows, for the same reason.
struct SessionUnitChips: View {
    let units: [SessionUnitRef]
    /// The tap action for a ref, or `nil` when it has nowhere to go — a unit deleted since the
    /// session, a loop that qualifies for no run mode, or a kind this version doesn't know.
    /// Mirrors `JournalTabView.openAction(for:)`, paywall gate included.
    var openAction: (SessionUnitRef) -> (() -> Void)?

    var body: some View {
        if !units.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(units) { unit in
                    pill(unit)
                }
            }
        }
    }

    @ViewBuilder private func pill(_ unit: SessionUnitRef) -> some View {
        if let open = openAction(unit) {
            Button {
                open()
                haptic(.light)
            } label: {
                pillLabel(unit, dimmed: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(unit.title)")
            .accessibilityAddTraits(.isLink)
        } else {
            pillLabel(unit, dimmed: true)
                // The unit is gone; the entry that remembers it is not. Say so to VoiceOver rather
                // than reading a bare name that sounds tappable.
                .accessibilityLabel("\(unit.title), no longer available")
        }
    }

    private func pillLabel(_ unit: SessionUnitRef, dimmed: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol(for: unit))
                .font(.futura(.caption2))
            Text(unit.title)
                .lineLimit(1)
        }
        .font(.futura(.caption))
        .foregroundStyle(dimmed ? PocketColor.textSecondary : PocketColor.journal)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(PocketColor.surfaceStandard))
        .overlay(Capsule().stroke(PocketColor.surfaceBorder, lineWidth: dimmed ? 1 : 0))
    }

    /// The unit's type glyph. A loop reads `repeat`, exactly as it does in
    /// `RoutinePlayerView.symbol(for:)`. An exercise reads the **generic** drill glyph rather than
    /// its template's own: the snapshot is a loose id copy and deliberately doesn't carry a template,
    /// so resolving one would mean looking the exercise up — and then a deleted unit's pill would
    /// lose its icon as well as its link.
    private func symbol(for unit: SessionUnitRef) -> String {
        switch unit.kind {
        case .exercise: return "metronome"
        case .loop: return "repeat"
        case nil: return "questionmark"
        }
    }
}

#Preview("Session unit chips") {
    let live = SessionUnitRef(uid: UUID(), title: "Alternating picking", kind: .exercise)
    let loop = SessionUnitRef(uid: UUID(), title: "Little Wing · Verse riff", kind: .loop)
    let gone = SessionUnitRef(uid: UUID(), title: "Deleted drill", kind: .exercise)
    return SessionUnitChips(units: [live, loop, gone]) { unit in
        unit.uid == gone.uid ? nil : {}
    }
    .padding(20)
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
