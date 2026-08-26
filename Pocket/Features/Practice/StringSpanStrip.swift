import SwiftUI

/// The picking editor's **Across** control (ADR 0184): the strings drawn as they sit on the neck, with
/// the travelled span filled, a dot at the start and a chevron at the finish.
///
/// It replaces two `.menu` Pickers and a decorative `→`. That row was the only one in an editor built
/// entirely from steppers that used pickers at all; it gave neither end a visible tap target, drew both
/// in the same accent so start and finish were told apart only by reading "low E" against "high e", and
/// — the part no arrangement of two menus could fix — could not show how much of the neck the run
/// actually crosses. The strip answers that by being the neck: the span's size and direction are the
/// picture, and the caption underneath is confirmation rather than the only reading.
///
/// Tap behaviour is `StringSpanEdit.apply` — pure, and unit-tested there rather than here.
struct StringSpanStrip: View {
    @Binding var from: Int
    @Binding var to: Int
    var instrument: Instrument = .guitar
    var tint: Color = PocketColor.practice

    /// The strings low → high, which is left → right as the strip draws them and bottom → top as the
    /// board above it does.
    private var order: [Int] { Array((0..<instrument.stringCount).reversed()) }
    private var span: ClosedRange<Int> { min(from, to)...max(from, to) }
    /// A lower engine index is a higher string, so travelling *down* the indices travels right.
    private var travelsRight: Bool { from > to }

    private var caption: String {
        let count = span.count
        return "\(NeckStringName.full(from, instrument: instrument)) → "
            + "\(NeckStringName.full(to, instrument: instrument)) · "
            + "\(count) \(count == 1 ? "string" : "strings")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                EditorFieldLabel("Across")
                Spacer()
                Button { reverse() } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reverse direction")
            }
            HStack(spacing: 4) {
                ForEach(order, id: \.self) { index in cell(index) }
            }
            HStack(spacing: 4) {
                ForEach(order, id: \.self) { index in lane(index) }
            }
            Text(caption)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                // The lane is decorative to VoiceOver, so this line carries the whole answer.
                .accessibilityLabel("Across: \(caption)")
        }
    }

    private func cell(_ index: Int) -> some View {
        Button {
            let edit = StringSpanEdit.apply(tapped: index, from: from, to: to)
            from = edit.from
            to = edit.to
            haptic(.light)
        } label: {
            Text(NeckStringName.short(index, instrument: instrument))
                .font(.futura(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 9)
                    .fill(span.contains(index) ? tint.opacity(0.22) : PocketColor.surfaceSubtle))
                .foregroundStyle(span.contains(index) ? tint : PocketColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NeckStringName.full(index, instrument: instrument))
        .accessibilityValue(accessibilityValue(index))
        .accessibilityHint("Moves the nearer end of the span here")
    }

    private func accessibilityValue(_ index: Int) -> String {
        if index == from && index == to { return "The only string" }
        if index == from { return "Start" }
        if index == to { return "Finish" }
        return span.contains(index) ? "In the span" : "Not in the span"
    }

    /// The travel lane beneath the cells: a hairline through the span, a dot at the start, a chevron
    /// pointing the way the run goes at the finish. Decorative — the caption states all of it.
    private func lane(_ index: Int) -> some View {
        ZStack {
            if span.contains(index) {
                Capsule().fill(tint.opacity(0.45)).frame(height: 2)
            }
            if index == to {
                Image(systemName: travelsRight ? "chevron.right" : "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
            } else if index == from {
                Circle().fill(tint).frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 12)
        .accessibilityHidden(true)
    }

    private func reverse() {
        swap(&from, &to)
        haptic(.light)
    }
}

#Preview("String span strip") {
    struct Harness: View {
        @State private var from = 5
        @State private var to = 0
        @State private var bassFrom = 3
        @State private var bassTo = 1

        var body: some View {
            VStack(alignment: .leading, spacing: 30) {
                StringSpanStrip(from: $from, to: $to)
                StringSpanStrip(from: $bassFrom, to: $bassTo, instrument: .bass)
            }
            .padding()
            .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
