import SwiftData
import SwiftUI

/// Naming a **take** — the one journal row with nothing but a timestamp to tell it apart (ADR 0069
/// amendment, 2026-08-05). A note carries its own words and a session note carries its routine's
/// name; a take carried only "Take · 0:42 · 22:47", so a list of them was unreadable. Every *other*
/// entry kind is already self-describing, which is why this is offered here and nowhere else.
///
/// One alert, shared by both surfaces a take appears on (`TakesSheet` and the Journal tab), so the
/// two can't drift. Held as a `StableRef` keyed on the take's business `uid` — presenting a `@Model`
/// by `persistentModelID` self-dismisses the moment the id flips temp→permanent on first save
/// (ADR 0090), which would tear the field down mid-edit.
struct RenameTakeAlert: ViewModifier {
    @Binding var take: StableRef<Recording>?
    let context: ModelContext

    @State private var draft = ""
    @State private var saveFailed = false

    func body(content: Content) -> some View {
        content
            .alert("Name this take", isPresented: isPresented, presenting: take) { ref in
                // Empty on a numbered take, with its number as the placeholder, so typing names it and
                // saving it empty leaves it as it was (ADR 0307 D4).
                TextField(ref.value.numberedName ?? "Take name", text: $draft)
                    .textInputAutocapitalization(.sentences)
                Button("Cancel", role: .cancel) { take = nil }
                Button("Save") {
                    // An empty field clears the name and brings the number back (ADR 0307 D4).
                    ref.value.rename(to: draft)
                    take = nil
                    commit()
                }
            } message: { _ in
                Text("Something you'll recognise later — what you were working on, or how it went.")
            }
            // An alert closes on any button, so a failed save can't keep this one open: it says so in
            // its own alert, and *Try again* saves the name already given (ADR 0318).
            .saveFailedAlert(isPresented: $saveFailed, retry: commit)
            // Seed the field from the take being named, not from the last one named.
            .onChange(of: take?.id) { _, _ in draft = take?.value.title ?? "" }
    }

    private func commit() {
        guard context.saveOrLog() else { saveFailed = true; return }
        haptic(.light)
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { take != nil }, set: { if !$0 { take = nil } })
    }
}

extension View {
    /// Attach the shared take-rename alert, driven by a `StableRef` the row actions set.
    func renameTakeAlert(_ take: Binding<StableRef<Recording>?>, context: ModelContext) -> some View {
        modifier(RenameTakeAlert(take: take, context: context))
    }
}
