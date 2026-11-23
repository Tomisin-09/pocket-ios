import SwiftUI

/// **The chords in order** (ADR 0313 D8): a strip of chips under the Triads editor's board, one per chord
/// the run plays. Each says the chord's name and numeral as written, its inversion and its frets, and
/// *plays Dm* or *no shape* where those apply, so the whole run can be read before it's watched. The chip
/// of the chord being played fills with its colour (ADR 0308 D7), the board's colour for it, and the strip
/// keeps it in view. A later pass up the neck starts after a dashed rule, as the mockup draws it.
///
/// A thin skin over `TriadRun.chips`, which decides every word. **T10** — every colour is a `PocketColor` role.
struct TriadChipStrip: View {
    let chips: [TriadChip]
    /// The chord being played (`FretboardDrill.chordIndex(at:)`), or `nil` while nothing plays.
    let playing: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A string id per chip: an `Int` passed to `scrollTo` can land on a `ForEach` row's own id instead.
    private static func chipID(_ index: Int) -> String { "triads.chip.\(index)" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(chips.indices, id: \.self) { index in
                        HStack(alignment: .center, spacing: 6) {
                            if chips[index].startsPass { passRule }
                            chip(chips[index], isPlaying: index == playing)
                        }
                        .id(Self.chipID(index))
                    }
                }
                .padding(.vertical, 1)
            }
            .onChange(of: playing) { _, now in
                guard let now else { return }
                if reduceMotion {
                    proxy.scrollTo(Self.chipID(now), anchor: .center)
                } else {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(Self.chipID(now), anchor: .center) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chords in order")
        .accessibilityIdentifier("triads.chips")
    }

    /// The dashed rule a later pass starts after.
    private var passRule: some View {
        Rectangle()
            .stroke(PocketColor.textSecondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(width: 1, height: 36)
            .padding(.horizontal, 3)
            .accessibilityHidden(true)
    }

    private func chip(_ chip: TriadChip, isPlaying: Bool) -> some View {
        let colour = PocketColor.chord(degree: chip.degree)
        let ink = isPlaying ? PocketColor.chordInk : PocketColor.textPrimary
        let quiet = isPlaying ? PocketColor.chordInk : PocketColor.textSecondary
        return VStack(spacing: 1) {
            Text(chip.name)
                .font(.futura(size: 16, weight: .bold))
                .foregroundStyle(ink)
            if !chip.shapeLine.isEmpty {
                Text(chip.shapeLine)
                    .font(.futura(size: 11))
                    .foregroundStyle(quiet)
            }
            Text(chip.fretLine)
                .font(.futura(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(chip.rest == nil ? ink : quiet)
            if let playsAs = chip.playsAs {
                Text("plays \(playsAs)")
                    .font(.futura(size: 11))
                    .italic()
                    .foregroundStyle(quiet)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 62)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isPlaying ? colour : PocketColor.surfaceStandard))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(isPlaying ? colour : PocketColor.surfaceBorder,
                          style: StrokeStyle(lineWidth: 1, dash: chip.rest == nil ? [] : [3, 3])))
        .opacity(chip.rest == nil || isPlaying ? 1 : 0.75)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isPlaying)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chip.spoken)
        .accessibilityAddTraits(isPlaying ? .isSelected : [])
    }
}

#Preview("Triad chips") {
    let run = TriadRun(tonic: 0, source: .progression, progression: TriadRun.defaultProgression,
                       placement: .upTheNeck)
    return VStack(alignment: .leading, spacing: 16) {
        TriadChipStrip(chips: run.chips(), playing: nil)
        TriadChipStrip(chips: TriadRun.starter.chips(), playing: 3)
    }
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
