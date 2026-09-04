import SwiftUI

/// A **bounded** set of options as a titled `Form` section — every choice visible at once, the
/// current one checked, and room under it for a footer that says what the choice does.
///
/// This exists because a popup `Menu` is the wrong container for more than a handful of options and
/// the app had grown past that: the metronome's meter menu reached fifteen items across three groups,
/// which scrolls, clips its first row, wraps its longer labels onto two lines, and gives no way to
/// tell where you are in it. A `Form` section has none of those problems and, unlike a menu, has
/// somewhere to put prose.
///
/// **The footer is load-bearing, not decoration.** Click withdrawal is the case that proves it: a row
/// reading "Deep" with nothing under it describes a metronome that stops clicking, which is
/// indistinguishable from one that has broken. Options a player can't be expected to already
/// understand need their explanation in the same place as the control.
struct OptionListSection<Value: Hashable>: View {
    let header: String
    /// Prose under the section. `nil` for choices that explain themselves (a time signature does).
    var footer: String?
    let options: [PickerItem<Value>]
    @Binding var selection: Value
    var tint: Color = PocketColor.practice

    var body: some View {
        Section {
            ForEach(options) { option in
                Button {
                    guard option.value != selection else { return }
                    selection = option.value
                    haptic(.light)
                } label: {
                    OptionRow(title: option.title, context: option.context,
                              isSelected: option.value == selection, tint: tint)
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text(header)
        } footer: {
            if let footer {
                Text(footer)
                    .font(.futura(.caption))
            }
        }
    }
}

/// The **multi-select** sibling — same section, same rows, a `Set` instead of one value, and an
/// optional leading row that clears it.
///
/// Ticking a second option **widens** the result (ADR 0159: *OR within a facet, AND across facets*),
/// which is why the footer is not optional here the way it is above: within one axis, adding a tick
/// normally narrows in a player's experience of every other list they use, and a control that does
/// the opposite has to say so. A menu could not hold that sentence, which is the whole reason this
/// family of components exists.
///
/// **An empty set means "everything", and `clearTitle` is how you get back to it.** That row is
/// checked exactly when nothing else is, so the section always has precisely one thing to read as
/// its current state rather than a blank list that could equally be "nothing selected yet".
struct MultiOptionListSection<Value: Hashable>: View {
    let header: String
    /// Prose under the section — see above: it says that ticking more shows more.
    let footer: String
    /// The unfiltered row's title ("All", "Any kind", …), or `nil` for a section where the empty set
    /// is not a state worth offering directly.
    var clearTitle: String?
    let options: [PickerItem<Value>]
    @Binding var selection: Set<Value>
    var tint: Color = PocketColor.practice

    var body: some View {
        Section {
            if let clearTitle {
                Button {
                    guard !selection.isEmpty else { return }
                    selection.removeAll()
                    haptic(.light)
                } label: {
                    OptionRow(title: clearTitle, isSelected: selection.isEmpty, tint: tint)
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
            }
            ForEach(options) { option in
                Button {
                    toggle(option.value)
                    haptic(.light)
                } label: {
                    OptionRow(title: option.title, context: option.context,
                              isSelected: selection.contains(option.value), tint: tint)
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text(header)
        } footer: {
            Text(footer)
                .font(.futura(.caption))
        }
    }

    private func toggle(_ value: Value) {
        if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
    }
}

/// One row of a picker — title over an optional context line, with a trailing checkmark when it is
/// the current choice.
///
/// The checkmark trails rather than leads (the placement a `Form` picker uses) so the labels align
/// on a single left edge and the list stays scannable by name; a leading marker would indent every
/// title past a column that is empty on all but one row. Shared with `SearchablePickerList` so a
/// bounded and an unbounded picker read identically.
struct OptionRow: View {
    let title: String
    var context: String?
    let isSelected: Bool
    var tint: Color = PocketColor.practice

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let context, !context.isEmpty {
                    Text(context)
                        .font(.futura(.caption2))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.futura(.body, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var signature = TimeSignature.standard
    Form {
        OptionListSection(header: "Time signature",
                          options: TimeSignature.presets.map {
                              PickerItem(value: $0, title: $0.name, context: $0.context)
                          },
                          selection: $signature)
    }
}
