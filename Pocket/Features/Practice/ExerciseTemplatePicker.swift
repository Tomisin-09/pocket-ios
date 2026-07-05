import SwiftUI

/// The **template chooser** — step one of creating an exercise (ADR 0068, revised). A drill's
/// template is a deliberate, first-class choice (not a buried setting), because it decides the
/// authoring UI, the runtime surface, and the library section, and it can't be changed later. Each
/// row is a curated `ExerciseTemplate`: icon, name, a one-line blurb, and a small badge on the ones
/// with a bespoke editor today (only Strumming) so the menu is honest about what differs.
///
/// **T10** — colours resolve through semantic `PocketColor` roles; the practice tint carries the
/// icons and the bespoke badge.
struct ExerciseTemplatePicker: View {
    let onSelect: (ExerciseTemplate) -> Void

    var body: some View {
        List {
            Section {
                ForEach(ExerciseTemplate.creatable) { template in
                    Button { onSelect(template); haptic(.light) } label: { row(template) }
                        .listRowBackground(PocketColor.background)
                }
            } footer: {
                Text("Pick the kind of drill. This sets how you build and run it — and can't be "
                     + "changed after, so choose the one that fits.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("New exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ template: ExerciseTemplate) -> some View {
        HStack(spacing: 14) {
            Image(systemName: template.iconName)
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.displayName)
                        .font(.futura(.body, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    if template.hasBespokeEditor { bespokeBadge }
                }
                Text(template.blurb)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(template.hasBespokeEditor ? "Has its own editor" : "")
    }

    private var bespokeBadge: some View {
        Text("Editor")
            .font(.futura(.caption2, weight: .bold))
            .foregroundStyle(PocketColor.practice)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(PocketColor.practice.opacity(0.16)))
    }
}

#Preview("Template picker") {
    NavigationStack {
        ExerciseTemplatePicker { _ in }
    }
    .preferredColorScheme(.dark)
}
