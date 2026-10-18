import SwiftUI

/// **References**, one tap down from a detail sheet (ADR 0258): *Where you learned it* (ADR 0167) on a
/// screen of its own, pushed inside the sheet's `NavigationStack`. Song details, Edit loop and the
/// exercise ⓘ sheet all open this one.
///
/// It owns the link being edited and the picture or picker being shown, and presents both from its own
/// `Form` (ADR 0258 D3): a sheet raised from a row inside a form in a sheet fights the presentation
/// that owns the screen and dismisses it instead (see `ReferencesSection.editing`).
///
/// Links write straight through, as they always have — on Edit loop too, where everything else waits
/// for Done. A link is a discrete add, like a journal entry, not part of the draft Cancel discards.
struct ReferencesScreen<Owner: ReferenceLinkOwner & AnyObject>: View {
    let owner: Owner
    let accent: Color

    @State private var editing: ReferenceLinkDraft?
    @State private var presenting: ReferenceAttachmentPresentation?

    var body: some View {
        Form {
            ReferencesSection(owner: owner, accent: accent, editing: $editing, presenting: $presenting)
        }
        .navigationTitle("References")
        .navigationBarTitleDisplayMode(.inline)
        .referenceLinkEditing($editing, owner: owner, accent: accent)
        .referenceAttachments($presenting, naming: $editing, owner: owner, accent: accent)
    }
}

extension ReferenceLinkOwner {
    /// The value a **References** row shows: links and files counted apart (`DetailSheetText`).
    var referencesRowValue: String {
        DetailSheetText.references(links: references.count - attachmentReferenceCount,
                                   files: attachmentReferenceCount)
    }
}
