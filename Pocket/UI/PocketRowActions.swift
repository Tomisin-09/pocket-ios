import SwiftUI

/// One entry in a row's long-press menu — Details, Edit, Duplicate, Play, …
struct PocketRowMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}

/// A row's favourite pin (ADR 0119) — the leading swipe **and** a menu entry, so the affordance is
/// discoverable without knowing to swipe.
struct PocketRowFavorite {
    let isFavorite: Bool
    let toggle: () -> Void
}

/// **The** row-affordance modifier (Slice 3). One call packages the three things a list row in this
/// app is expected to offer, so a new list gets the whole set by adopting one modifier instead of
/// re-deriving it:
///
/// - a **long-press menu** (`.contextMenu`) — the item's own actions, then Favourite, then Delete,
/// - **swipe actions** — favourite leading, delete trailing, matching the platform convention,
/// - an **undo toast** on delete, via the deferred-delete seam in the environment.
///
/// Before this, only the song library had the full pattern; the practice libraries had a leading
/// favourite swipe and (for two of them) a bare `.onDelete` with no undo and no menu. Adoption is
/// what makes them uniform — the parameters are all optional so a list only declares what it
/// actually offers (the loop library, for instance, deliberately has no delete: a loop belongs to
/// its song and is removed on the waveform).
///
/// Deletion is **deferred**, not snapshot-and-restored — see `RowDeletionCoordinator`. The list
/// must filter out rows the seam reports as pending, or the row stays visible behind the toast.
extension View {
    /// - Parameters:
    ///   - name: the item's display name, used in the "Deleted X" toast.
    ///   - tint: the space's accent — Practice tint in Practice, `active` in the song library.
    ///   - menu: the item's own actions, shown above Favourite/Delete in the long-press menu.
    ///   - favorite: the favourite pin, when the model has one.
    ///   - delete: the delete, when this list owns the item's lifetime.
    func pocketRowActions(_ name: String,
                          tint: Color,
                          menu: [PocketRowMenuItem] = [],
                          favorite: PocketRowFavorite? = nil,
                          delete: PocketRowDelete? = nil) -> some View {
        modifier(PocketRowActionsModifier(name: name, tint: tint, menu: menu,
                                          favorite: favorite, delete: delete))
    }
}

private struct PocketRowActionsModifier: ViewModifier {
    @Environment(\.rowDeletion) private var rowDeletion

    let name: String
    let tint: Color
    let menu: [PocketRowMenuItem]
    let favorite: PocketRowFavorite?
    let delete: PocketRowDelete?

    func body(content: Content) -> some View {
        content
            .contextMenu { menuContent }
            .swipeActions(edge: .leading) {
                if let favorite { favoriteButton(favorite) }
            }
            .swipeActions(edge: .trailing) {
                if let delete { deleteButton(delete) }
            }
    }

    /// Item actions first, then the favourite toggle, then Delete last and destructive — the order
    /// every row in the app now reads in.
    @ViewBuilder
    private var menuContent: some View {
        ForEach(menu) { item in
            Button { item.action() } label: { Label(item.title, systemImage: item.systemImage) }
        }
        if let favorite {
            Button { toggle(favorite) } label: {
                Label(favorite.isFavorite ? "Unfavourite" : "Favourite",
                      systemImage: favorite.isFavorite ? "star.slash" : "star")
            }
        }
        if let delete {
            Button(role: .destructive) { requestDelete(delete) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func favoriteButton(_ favorite: PocketRowFavorite) -> some View {
        Button { toggle(favorite) } label: {
            Label(favorite.isFavorite ? "Unfavourite" : "Favourite",
                  systemImage: favorite.isFavorite ? "star.slash" : "star")
        }
        .tint(tint)
        .accessibilityLabel(favorite.isFavorite ? "Unfavourite \(name)" : "Favourite \(name)")
    }

    /// The trailing swipe's Delete. Deliberately **not** `role: .destructive`: a destructive swipe
    /// button plays SwiftUI's own row-removal animation the moment it's tapped, whether or not the
    /// data changed — which under a *deferred* delete means the row vanishes on a lie and doesn't
    /// come back on Undo (it stays gone until the list is rebuilt). A plain red-tinted button leaves
    /// the row's disappearance entirely to the pending-row filter, so Undo restores it. The menu's
    /// Delete keeps the role, where it only colours the label.
    private func deleteButton(_ delete: PocketRowDelete) -> some View {
        Button { requestDelete(delete) } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(PocketColor.danger)
        .accessibilityLabel("Delete \(name)")
    }

    private func toggle(_ favorite: PocketRowFavorite) {
        favorite.toggle()
        haptic(.light)
    }

    private func requestDelete(_ delete: PocketRowDelete) {
        rowDeletion.request(delete)
        haptic(.medium)
    }
}
