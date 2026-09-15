import SwiftUI

// MARK: - Progressions tab

extension ProgressionPickerSheet {
    @ViewBuilder
    var progressionsContent: some View {
        Section {
            keyChips
        } header: {
            Text("Key")
        }
        yourProgressionsSection
        Section {
            ForEach(ProgressionTemplate.catalog) { templateRow($0) }
        } header: {
            Text("Progression")
        } footer: {
            Text("The numerals show where each chord sits in the key. Tap a chord to swap it before adding.")
        }
    }

    /// Twelve keys don't fit across a phone, so the row scrolls — and keeps the chosen key in view, or a
    /// sheet opening in G would show C to F♯ with nothing selected.
    private var keyChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<12, id: \.self) { pitch in
                        keyChip(pitch).id(pitch)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(tonic, anchor: .center) }
            .onChange(of: tonic) { withAnimation { proxy.scrollTo(tonic, anchor: .center) } }
        }
    }

    private func keyChip(_ pitch: Int) -> some View {
        let label = ProgressionKey(tonic: pitch, isMinor: readsAsMinor).label(preference: spelling)
        let isSelected = pitch == tonic
        return Button {
            tonic = pitch
            haptic(.light)
        } label: {
            Text(label)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? PocketColor.practice : PocketColor.surfaceStandard))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Key of \(label)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("progression.key.\(pitch)")
    }

    private func templateRow(_ template: ProgressionTemplate) -> some View {
        progressionRow(template, isSelected: source == .template(template.id),
                       identifier: "progression.template.\(template.id)") {
            source = .template(template.id)
        }
    }

    /// One progression — built-in, or the player's dressed as one. Selected, it opens into the preview.
    func progressionRow(_ row: ProgressionTemplate, isSelected: Bool, identifier: String,
                        select: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: select) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.displayTitle)
                            .font(.futura(.subheadline, weight: .semibold))
                            .foregroundStyle(isSelected ? PocketColor.practice : PocketColor.textPrimary)
                        Text(isSelected ? row.detail : "\(row.detail) · \(chordNames(row.steps))")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    Spacer(minLength: 8)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PocketColor.practice)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityIdentifier(identifier)

            if isSelected { previewStrip }
        }
    }

    /// The chords a row plays in the current key, each named once — "G · D · Em · C".
    private func chordNames(_ steps: [ProgressionStep]) -> String {
        let key = ProgressionKey(tonic: tonic, isMinor: steps.readsAsMinor)
        var seen = Set<String>()
        return steps.map { key.chordName(of: $0, preference: spelling) }
            .filter { seen.insert($0).inserted }
            .joined(separator: " · ")
    }

    /// The selection's chords, as they'll be inserted. Each opens the chord picker on its own slot.
    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(preview) { chord in
                    Button {
                        pickerSlot = .swap(chord.id)
                    } label: {
                        ProgressionChordChip(chord: chord)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(chord.numeral.map { "\(chord.voicing.name), \($0). Swap before adding" }
                                        ?? "\(chord.voicing.name). Swap before adding")
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Two chords tab

extension ProgressionPickerSheet {
    @ViewBuilder
    var pairsContent: some View {
        Section {
            HStack(spacing: 10) {
                ownSlot(0)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .accessibilityHidden(true)
                ownSlot(1)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Pick your own two")
        } footer: {
            Text("Any two chords, including the ones you've saved.")
        }
        if instrument == .guitar {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                          spacing: 10) {
                    ForEach(ChordPair.curated) { pairCard($0) }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Common changes")
            } footer: {
                Text("These stay as the shapes shown — the change is in the grip, so they don't move to a key.")
            }
        }
    }

    private func ownSlot(_ index: Int) -> some View {
        let chosen = ownPair[index]
        return Button {
            pickerSlot = .own(index)
        } label: {
            VStack(spacing: 4) {
                if let chosen {
                    ChordDiagramView(voicing: chosen, tint: PocketColor.practice, showsName: false)
                        .frame(width: 46, height: 56)
                    Text(chosen.name)
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PocketColor.practice)
                    Text("Choose")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.practice)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(source == .ownPair ? PocketColor.practiceCardWash : PocketColor.surfaceSubtle))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(chosen == nil ? PocketColor.surfaceBorder : PocketColor.practice.opacity(0.5),
                              style: StrokeStyle(lineWidth: 1, dash: chosen == nil ? [4] : [])))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(chosen.map { "Change \($0.name)" }
                            ?? (index == 0 ? "Choose the first chord" : "Choose the second chord"))
        .accessibilityIdentifier("progression.own.\(index)")
    }

    private func pairCard(_ pair: ChordPair) -> some View {
        let isSelected = source == .pair(pair.id)
        return Button {
            source = .pair(pair.id)
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ChordDiagramView(voicing: pair.first, tint: PocketColor.practice, showsName: false)
                        .frame(width: 38, height: 46)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                        .foregroundStyle(PocketColor.textSecondary)
                    ChordDiagramView(voicing: pair.second, tint: PocketColor.practice, showsName: false)
                        .frame(width: 38, height: 46)
                }
                Text(pair.title)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(isSelected ? PocketColor.practice : PocketColor.textPrimary)
                Text(pair.detail)
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? PocketColor.practiceCardWash : PocketColor.surfaceSubtle))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? PocketColor.practice : PocketColor.surfaceBorder,
                              lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(pair.first.name) to \(pair.second.name), \(pair.detail)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("progression.pair.\(pair.id)")
    }
}

/// One chord of the preview — its numeral (or *yours* / *swapped*), its diagram, its name and its length.
struct ProgressionChordChip: View {
    let chord: ProgressionInsert.Chord

    private var isMarked: Bool { chord.isYours || chord.isSwapped }

    private var tag: String {
        if chord.isYours { return "yours" }
        if chord.isSwapped { return "swapped" }
        return chord.numeral ?? " "
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(tag)
                .font(.futura(.caption2, weight: .semibold))
                .foregroundStyle(isMarked ? PocketColor.practice : PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ChordDiagramView(voicing: chord.voicing, tint: PocketColor.practice, showsName: false)
                .frame(width: 56, height: 68)
            Text(chord.voicing.name)
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(chord.beats == 1 ? "1 beat" : "\(chord.beats) beats")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .frame(width: 76)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.surfaceSubtle))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isMarked ? PocketColor.practice.opacity(0.6) : PocketColor.surfaceBorder, lineWidth: 1))
    }
}
