import SwiftUI

/// **Add to folder…** — the one picker both libraries use (ADR 0210 D9).
///
/// One sheet for exercises and routines because they share a namespace (D3): offering a teacher a
/// different folder list depending on which library they came from is exactly the drift that design
/// exists to prevent.
///
/// The folders already in use are offered as **tappable suggestions**, which is ADR 0033's
/// convergence mechanism and the reason a label set stops fragmenting into `Blues` / `blues`: the
/// cheapest way to file something is to reuse a folder, not to retype one.
///
/// The verb is **add**, never *move* (D1). A drill sitting in *Grade 2* **and** *Picking* is the
/// feature, not a state to be resolved — so this sheet has no notion of "the" folder something is
/// in, and leaving it does not take it out of anywhere else.
struct FolderPickerSheet: View {
    /// What is being filed, for the title — "Alternating picking".
    let itemName: String
    /// The folders it is in now.
    let current: [String]
    /// Every folder in the library: markers and derived paths, both models (D4).
    let namespace: [String]
    /// File it into a path. The host owns the write, because the model differs.
    let onAdd: (String) -> Void
    /// Take it out of a path — and out of that path only.
    let onRemove: (String) -> Void
    /// Make a folder at the top level and file into it. Returns nothing: the host writes, and the
    /// namespace it passes back in is what redraws this list.
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var creating = false
    @State private var draftName = ""

    /// The folders on offer: everything the library knows about that this item is not already in,
    /// narrowed by the query. Matched on the **whole path**, so typing "warm" finds
    /// `Beginner/Warm-ups` without having to remember where it lives.
    private var offered: [String] {
        let taken = Set(current.map { $0.lowercased() })
        return namespace
            .filter { !taken.contains($0.lowercased()) }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
    }

    /// The folders it is in now, alphabetical for the same reason `offered` is: the stored order is
    /// the order things happened to be filed in, which carries nothing a reader can use. Sorting by
    /// the **whole path** keeps a parent immediately above its children.
    private var filed: [String] {
        current.sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filed.isEmpty {
                    Section("In these folders") {
                        ForEach(filed, id: \.self) { path in
                            filedRow(path)
                        }
                    }
                }
                Section(current.isEmpty ? "Add to a folder" : "Add to another") {
                    Button {
                        draftName = ""
                        creating = true
                    } label: {
                        Label("New folder…", systemImage: "folder.badge.plus")
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.practice)
                    }
                    .listRowBackground(PocketColor.background)
                    if offered.isEmpty {
                        Text(namespace.isEmpty
                             ? "No folders yet. Make one to group drills by whatever you like — "
                               + "a grade, a technique, a student."
                             : "Nothing else to add it to.")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                            .listRowBackground(PocketColor.background)
                    } else {
                        ForEach(offered, id: \.self) { path in
                            offerRow(path)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add to folder")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Folders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(PocketColor.practice)
                }
            }
            // The picker makes **top-level** folders only. Nesting is done by standing inside a
            // folder in the library and creating there (D5) — which is what keeps a typed `/` from
            // quietly meaning something, and the breadcrumb honest about where you are.
            .alert("New folder", isPresented: $creating) {
                TextField("Name", text: $draftName)
                Button("Cancel", role: .cancel) { draftName = "" }
                Button("Create") {
                    onCreate(draftName)
                    draftName = ""
                }
            } message: {
                Text("Made at the top level, with “\(itemName)” inside it.")
            }
        }
    }

    private func filedRow(_ path: String) -> some View {
        HStack(spacing: 10) {
            pathLabel(path)
            Spacer(minLength: 8)
            Button {
                onRemove(path)
                haptic(.light)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove from \(FolderPath.leaf(path))")
        }
        .listRowBackground(PocketColor.background)
    }

    private func offerRow(_ path: String) -> some View {
        Button {
            onAdd(path)
            haptic(.light)
        } label: {
            HStack(spacing: 10) {
                pathLabel(path)
                Spacer(minLength: 8)
                Image(systemName: "plus.circle")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(PocketColor.background)
        .accessibilityLabel("Add to \(path)")
    }

    /// A path drawn as a path: the parent quiet, the folder itself the thing you read. Two folders
    /// called *Warm-ups* under different grades are different folders, so the trail has to be
    /// visible — but it is context, not the name.
    private func pathLabel(_ path: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            if let parent = FolderPath.parent(path), !parent.isEmpty {
                Text(parent + FolderPath.separator)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Text(FolderPath.leaf(path))
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(1)
        }
    }
}

#Preview("Folder picker") {
    FolderPickerSheet(itemName: "Alternating picking",
                      current: ["Technique/Alternate picking"],
                      namespace: ["Beginner", "Beginner/Warm-ups", "Grade 2",
                                  "Technique", "Technique/Alternate picking"],
                      onAdd: { _ in }, onRemove: { _ in }, onCreate: { _ in })
        .preferredColorScheme(.dark)
}
