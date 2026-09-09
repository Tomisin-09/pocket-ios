import SwiftUI

/// The **breadcrumb** above a practice library that is standing inside a folder (ADR 0210 D6).
///
/// Shown only when the walk has actually left the root, which is the same progressive disclosure the
/// instrument filter uses: at the root a library is exactly what it was before folders existed
/// (D6b), so a bar there would restate the navigation title and cost a strip of screen for nothing.
///
/// Every crumb is tappable, including the first — that is the way back out, and it is one tap from
/// any depth rather than one tap per level.
struct FolderBrowseBar: View {
    /// The trail, root first.
    let crumbs: [FolderCrumb]
    /// Jump to a crumb's path.
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.futura(.caption2, weight: .semibold))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    crumbButton(crumb, isLast: index == crumbs.count - 1)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // **No `.defaultScrollAnchor(.trailing)`.** The first draft had one, reasoning that a deep
        // trail should arrive scrolled to where you are — and it also pins a *short* trail against
        // the right margin, so `Exercises › chords` rendered on the far side of an empty bar. A
        // screenshot caught it; a green build could not. A trail is read from the left.
        .background(PocketColor.background)
    }

    private func crumbButton(_ crumb: FolderCrumb, isLast: Bool) -> some View {
        Button {
            guard !isLast else { return }
            onSelect(crumb.path)
            haptic(.light)
        } label: {
            Text(crumb.name)
                .font(.futura(.subheadline, weight: isLast ? .semibold : .regular))
                .foregroundStyle(isLast ? PocketColor.textPrimary : PocketColor.practice)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        .accessibilityLabel(isLast ? "\(crumb.name), current folder" : "Back to \(crumb.name)")
    }
}

/// One folder row in a library list — the thing you tap to walk into (ADR 0210 D6).
///
/// Sits **above** the template sections rather than replacing them: folders group by *intent* and
/// templates (ADR 0068) group by *kind*, which are orthogonal axes, and collapsing one does not want
/// to be the other.
struct FolderRow: View {
    /// The folder's leaf name — the path is where it is, this is what it is called.
    let name: String
    /// How many items sit at or below it. **These do not sum to the library total** (D6b): an item
    /// filed in two folders is counted in both, which is the price of multi-membership and is
    /// deliberate rather than an arithmetic bug.
    ///
    /// Named `itemCount`, not `count`: SwiftLint's `empty_count` reads any comparison against a
    /// property called `count` as an emptiness check written the long way.
    let itemCount: Int
    /// "6 exercises" / "2 routines" — spelled by the library, because the same row serves both.
    let countLabel: String
    let open: () -> Void

    var body: some View {
        Button {
            open()
            haptic(.light)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: itemCount > 0 ? "folder.fill" : "folder")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 22)
                Text(name)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Text("\(itemCount)")
                    .font(.pocketMono(.caption))
                    .monospacedDigit()
                    .foregroundStyle(PocketColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.futura(.caption2, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) folder, \(countLabel)")
        .accessibilityHint("Opens this folder")
    }
}

#Preview("Folder browsing") {
    List {
        Section {
            FolderRow(name: "Beginner", itemCount: 6, countLabel: "6 exercises") {}
                .listRowBackground(PocketColor.background)
            FolderRow(name: "Grade 2", itemCount: 0, countLabel: "no exercises") {}
                .listRowBackground(PocketColor.background)
        } header: {
            Text("Folders").font(.futura(.caption))
        }
    }
    .scrollContentBackground(.hidden)
    .background(PocketColor.background.ignoresSafeArea())
    .safeAreaInset(edge: .top) {
        FolderBrowseBar(crumbs: [FolderCrumb(name: "Exercises", path: ""),
                                 FolderCrumb(name: "Beginner", path: "Beginner")]) { _ in }
    }
    .preferredColorScheme(.dark)
}
