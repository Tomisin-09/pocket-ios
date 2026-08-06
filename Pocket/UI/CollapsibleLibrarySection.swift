import SwiftUI

/// A grouped-list section whose header **collapses it** (v2 close-out Slice 5, note N8). One
/// component for every browsable library — songs, exercises, loops — so a bucket behaves the same
/// way wherever the player meets one, and the collapse state each list persists is the only thing
/// that differs.
///
/// Built as a `Section` with a tappable header rather than a `DisclosureGroup` inside the list: a
/// disclosure indents its children and re-styles them as its content, which would take the library
/// rows out of the row grammar every other list uses (`.pocketRowActions` swipes, full-width tap
/// targets, `listRowBackground`). The header keeps its list style's own typography — this adds a
/// chevron and a count to it, nothing else.
///
/// The **count is always shown**, not only when collapsed: the design brief's rule is that a
/// collapsed panel never leaves you wondering what's hidden (`docs/design-brief.md`), and a header
/// that grows a number the moment it shuts moves the row you just tapped.
struct CollapsibleLibrarySection<Content: View>: View {
    let title: String
    /// How many rows the section holds — the summary line, in the collapsed sense of the brief.
    let count: Int
    /// The caller owns the state — each library persists its own collapse (`LibrarySectionExpansion`).
    @Binding var isExpanded: Bool
    /// An optional SF Symbol between the chevron and the title, so a bucket is recognisable before it
    /// is read. **Optional on purpose:** only the Exercises library groups by something that owns a
    /// glyph (a template); grouping by initial letter or song title has none, and inventing one would
    /// be decoration. Decorative here too — it stays out of the accessibility label below.
    var icon: String?
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            if isExpanded { content }
        } header: {
            Button {
                haptic(.light)
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.futura(.caption2, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    if let icon {
                        Image(systemName: icon)
                            .font(.futura(.caption, weight: .semibold))
                            .frame(width: 18)   // fixed, so titles line up whatever the glyph's width
                    }
                    Text(title)
                    Spacer(minLength: 8)
                    Text("\(count)")
                        .font(.pocketMono(.caption))
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Matches the bucket rows in `AddRoutineUnitSheet`: name, then how many are in it.
            .accessibilityLabel("\(title), \(count)")
            .accessibilityHint(isExpanded ? "Collapses this section" : "Expands this section")
        }
    }
}

#Preview("Collapsible sections") {
    struct Harness: View {
        @State private var collapsed = LibrarySectionExpansion.setting("Scales", expanded: false,
                                                                       in: "")

        var body: some View {
            List {
                ForEach(["Picking", "Scales"], id: \.self) { title in
                    CollapsibleLibrarySection(title: title, count: 3,
                                              isExpanded: binding(title)) {
                        ForEach(1...3, id: \.self) { index in
                            Text("\(title) drill \(index)")
                                .font(.futura(.body))
                                .listRowBackground(PocketColor.background)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
        }

        /// The same get/set a real library builds over its persisted payload.
        private func binding(_ title: String) -> Binding<Bool> {
            Binding(get: { LibrarySectionExpansion.isExpanded(title, in: collapsed) },
                    set: { collapsed = LibrarySectionExpansion.setting(title, expanded: $0,
                                                                       in: collapsed) })
        }
    }
    return Harness().preferredColorScheme(.dark)
}
