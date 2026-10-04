import SwiftUI

// **The strip** (ADR 0235 D3, D4): the notes as chips, with the tab's one open slot, a **+**, and its bar
// lines and section headings between them, where they fall. The lit chip is where the neck, *Bar line* and
// *Section* act. Split out for file length.
extension TabWriterView {

    /// *Note 31, new · Chorus*, or *Note 9 of 30 · Verse*.
    var stripHeader: some View {
        let position = draft.position
        let whereText = draft.selected.map { "Note \($0 + 1) of \(draft.count)" } ?? "Note \(draft.slot + 1), new"
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(whereText)
                .font(.futura(.subheadline, weight: .semibold))
                .monospacedDigit()
            if let section = draft.content.section(of: position) {
                Text("· \(section.name)")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(0...draft.count), id: \.self) { index in
                        anchor(at: index)
                        if index == draft.slot { slotChip }
                        if index < draft.count { noteChip(index) }
                    }
                    // While the + is in front of a note, a quieter one at the end goes back to writing there.
                    if draft.slot < draft.count {
                        chipShape(lit: false) { Text("+").font(.futura(.headline)) }
                            .opacity(0.6)
                            .onTapGesture { draft.pickEnd() }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Back to the end")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("tab.end")
                    }
                }
                .padding(.vertical, 4)
            }
            .onAppear { proxy.scrollTo(litID, anchor: .center) }
            // On every edit, not only when the lit chip changes: writing keeps the + lit while moving it
            // on a chip, so a strip that waited for a new lit chip stayed where it was and the + walked
            // off its right edge (the manual shoot's fifteen-note tab, 2026-10-03).
            .onChange(of: draft) { withAnimation { proxy.scrollTo(litID, anchor: .center) } }
        }
    }

    /// Typed ids, so a scroll to the + can't land on a note that happens to share its number.
    enum StripID: Hashable {
        case slot
        case note(Int)
    }

    private var litID: StripID { draft.selected.map(StripID.note) ?? .slot }

    /// What stands before note `index`: its section's heading, or a bar line.
    @ViewBuilder private func anchor(at index: Int) -> some View {
        if let section = draft.content.section(startingAt: index) {
            sectionChip(section, at: index)
        } else if draft.content.hasBar(at: index) {
            barChip(at: index)
        }
    }

    private var slotChip: some View {
        let lit = draft.selected == nil
        let label = draft.slot < draft.count ? "Add a note before note \(draft.slot + 1)"
                                             : "Add note \(draft.count + 1)"
        return chipShape(lit: lit) {
            Text("+").font(.futura(.headline))
        }
        .onTapGesture { draft.slot == draft.count ? draft.pickEnd() : draft.lightSlot() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(lit ? [.isButton, .isSelected] : .isButton)
        .id(StripID.slot)
        .accessibilityIdentifier("tab.slot")
    }

    private func noteChip(_ index: Int) -> some View {
        let lit = draft.selected == index
        let notes = draft.content.labels[index]?.frettedNotes ?? []
        let text = notes.isEmpty ? nil : NeckNoteEditor<EmptyView>.fretText(notes, openMidi: tuning.openMidi)
        return chipShape(lit: lit, marked: draft.marked == index && !lit) {
            VStack(spacing: 0) {
                Text("\(index + 1)")
                    .font(.futura(.caption2))
                    .monospacedDigit()
                Text(text ?? "?")
                    .font(.futura(.subheadline, weight: text == nil ? nil : .bold))
                    .lineLimit(1)
            }
        }
        .onTapGesture { pick(index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Note \(index + 1), \(text ?? "not placed")")
        .accessibilityAddTraits(lit ? [.isButton, .isSelected] : .isButton)
        .id(StripID.note(index))
        .accessibilityIdentifier("tab.chip.\(index)")
    }

    private func sectionChip(_ section: TabSection, at index: Int) -> some View {
        let lit = draft.position == index
        return VStack(alignment: .leading, spacing: 0) {
            Text("SECTION")
                .font(.futura(size: 9, weight: .semibold))
                .tracking(0.8)
            Text(section.name)
                .font(.futura(.footnote, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(PocketColor.toolkit)
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(PocketColor.toolkit.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(lit ? PocketColor.toolkit : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { goTo(index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Section \(section.name), "
                            + (index < draft.count ? "starts at note \(index + 1)" : "starts with the next note"))
        .accessibilityAddTraits(.isButton)
    }

    private func barChip(at index: Int) -> some View {
        let lit = draft.position == index
        return RoundedRectangle(cornerRadius: 1)
            .fill(lit ? PocketColor.toolkit : PocketColor.textSecondary)
            .frame(width: lit ? 3 : 2, height: 34)
            .frame(width: 14, height: 44)
            .contentShape(Rectangle())
            .onTapGesture { goTo(index) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(index < draft.count ? "Bar line before note \(index + 1)"
                                                    : "Bar line before the next note you write")
            .accessibilityAddTraits(.isButton)
    }

    private func chipShape<Content: View>(lit: Bool, marked: Bool = false,
                                          @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundStyle(lit ? PocketColor.background : PocketColor.textPrimary)
            .padding(.horizontal, 8)
            .frame(minWidth: 46, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(lit ? PocketColor.toolkit : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(lit ? .clear : PocketColor.surfaceBorder))
            // The note the marks are still on, after the + moved past it: outlined in dashes, as on Name the notes.
            .overlay {
                if marked {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(PocketColor.toolkit, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .contentShape(Rectangle())
    }

    /// Pick a note, and bring it into view on the neck.
    func pick(_ index: Int) {
        naming = false
        draft.pick(index)
        neckTarget = NameTheNotesSheet.fret(of: draft.content.labels[index]) ?? neckTarget
    }

    /// A heading or bar line tapped: the note after it, or the + at the end.
    private func goTo(_ index: Int) {
        if index < draft.count { pick(index) } else { draft.pickEnd() }
    }

    // MARK: - The line under the strip

    @ViewBuilder var stripLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            if let note = draft.selected {
                NamingControls.link("Insert before \(note + 1)", tint: PocketColor.toolkit) {
                    naming = false
                    draft.insertBefore(note)
                }
                .accessibilityIdentifier("tab.insertBefore")
                NamingControls.link("Take note \(note + 1) out", tint: PocketColor.toolkit) {
                    naming = false
                    change { $0.takeOut(note) }
                }
                .accessibilityIdentifier("tab.takeOut")
            } else if draft.slot < draft.count {
                NamingControls.hint("Each tap adds a note before \(draft.slot + 1).")
                NamingControls.link("Back to the end", tint: PocketColor.toolkit) { draft.pickEnd() }
            } else {
                NamingControls.hint(draft.isEmpty ? "Tap the neck for the first note."
                                                     : "Tap the neck for note \(draft.count + 1).")
            }
        }
    }

    // MARK: - ↶ ↷, Bar line, Section

    var controls: some View {
        let position = draft.position
        let sectionHere = draft.content.section(startingAt: position)
        return HStack(spacing: 10) {
            historyButton("arrow.uturn.backward", label: "Undo", enabled: history.canUndo, action: undoLast)
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityIdentifier("tab.undo")
            historyButton("arrow.uturn.forward", label: "Redo", enabled: history.canRedo, action: redoLast)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityIdentifier("tab.redo")
            Spacer(minLength: 0)
            toggle("| Bar line", isOn: draft.content.hasBar(at: position),
                   enabled: position > 0 && sectionHere == nil) {
                naming = false
                change { $0.toggleBar() }
            }
            .accessibilityLabel("Bar line")
            .accessibilityIdentifier("tab.barLine")
            toggle("§ Section", isOn: sectionHere != nil || naming, enabled: true) { naming.toggle() }
                .accessibilityLabel("Section")
                .accessibilityIdentifier("tab.section")
        }
        .font(.futura(.subheadline))
        // ⌘Y as well as ⇧⌘Z. Zero-sized, so it takes no room.
        .background {
            Button("Redo", action: redoLast)
                .keyboardShortcut("y", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func undoLast() {
        guard let step = history.undo(from: step) else { return }
        restore(step)
    }

    private func redoLast() {
        guard let step = history.redo(from: step) else { return }
        restore(step)
    }

    private func historyButton(_ symbol: String, label: String, enabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(minWidth: 24, minHeight: 24)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func toggle(_ title: String, isOn: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.futura(.subheadline, weight: isOn ? .semibold : nil))
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
                .foregroundStyle(isOn ? PocketColor.toolkit : PocketColor.textPrimary)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isOn ? PocketColor.toolkit.opacity(0.16) : .clear))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isOn ? .clear : PocketColor.surfaceBorder))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
