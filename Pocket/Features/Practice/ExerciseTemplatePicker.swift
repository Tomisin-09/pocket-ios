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
    /// The Guitar/Bass axis for the drill about to be created (ADR 0116 S6) — hoisted here from the
    /// configure form so the form stays uncrowded; seeded from the profile's preferred instrument and
    /// fixed once a template is chosen. Fretboard-family templates open on this neck; the rest ignore it.
    @Binding var instrument: Instrument
    /// Reports the template **and the instrument it was chosen on**. The instrument rides along rather
    /// than being read back out of the binding by the host: the host reads it from a deferred
    /// navigation closure, which never sees a segment change (see `NewExerciseSheet.TemplateChoice`).
    /// Here it is read at tap time, on screen, so it is always the current selection.
    let onSelect: (ExerciseTemplate, Instrument) -> Void

    /// Red Moon Pro entitlement + the shared paywall (ADR 0112); safe preview defaults (free / no-op).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall

    var body: some View {
        List {
            Section {
                Picker("Instrument", selection: $instrument) {
                    ForEach(Instrument.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(PocketColor.background)
            } footer: {
                Text("Guitar or bass — sets the neck for scale, arpeggio and fretboard drills. Other "
                     + "drills ignore it. Fixed after creating.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Section {
                ForEach(ExerciseTemplate.creatable) { template in
                    // Every creatable template is buildable now — the "Coming Soon" (Ear Training /
                    // Theory) rows were removed 2026-07-22 (ear training shipped as a loop mode, ADR 0104).
                    // Authoring a Pro-tier template is gated (ADR 0112): a free tap opens the paywall
                    // instead of the configure step; Pro (or a free-tier template) proceeds.
                    Button { select(template) } label: { row(template) }
                        .listRowBackground(PocketColor.background)
                        // Identified, not label-matched: the Exercises library sits behind this sheet
                        // and has its own "Scales"/"Chords" section rows, so a label query finds the
                        // covered one and taps nothing.
                        .accessibilityIdentifier("template.\(template.rawValue)")
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

    /// Route a tap: free-tier templates (or a Pro subscriber) proceed to configure; a locked Pro
    /// template opens the paywall (ADR 0112).
    private func select(_ template: ExerciseTemplate) {
        if AccessPolicy.canAuthor(template, isPro: isPro) {
            onSelect(template, instrument)
            haptic(.light)
        } else {
            presentPaywall(.newExercise(template))
        }
    }

    private func row(_ template: ExerciseTemplate) -> some View {
        let locked = !AccessPolicy.canAuthor(template, isPro: isPro)
        return HStack(spacing: 14) {
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
                    if locked { proBadge }
                }
                Text(template.blurb)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(locked ? "Red Moon Pro" : (template.hasBespokeEditor ? "Has its own editor" : ""))
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.futura(.caption2, weight: .bold))
            .foregroundStyle(PocketColor.background)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(PocketColor.practice))
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
        ExerciseTemplatePicker(instrument: .constant(.guitar)) { _, _ in }
    }
    .preferredColorScheme(.dark)
}
