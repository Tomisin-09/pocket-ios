import SwiftUI

// Shared chrome for the practice screen's panels — the collapsible container and
// the standard panel surface used by the Loops / Markers / Song-info sections.

/// Collapsible panel: chevron + a summary line when collapsed, so the user is
/// never left wondering what's hidden (brief §3.4).
///
/// **Multi-select (ADR 0125):** holding the header enters the mode, and the header then
/// **stands down entirely** — its selection bar is pinned above the scrolling list by
/// `PracticeReference`, so the bulk actions stay reachable however far down you scroll.
/// The mode is scoped: browse keeps the chevron exactly where it has always been.
struct CollapsiblePanel<Content: View>: View {
    let title: String
    let summary: String
    @Binding var expanded: Bool
    /// Hold the header to enter multi-select. `nil` on panels that don't offer it.
    var onBeginSelection: (() -> Void)?
    /// True while this panel is selecting — its header is pinned outside the scroll view.
    var isSelecting: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isSelecting { browseHeader }
            if expanded { content }
        }
        .padding(14)
        .background(panelBackground)
    }

    /// **Not a `Button`.** A button fires its action on the release of a *long* press too,
    /// so holding an open panel entered selection mode and collapsed it on the way in
    /// (device pass, 2026-07-29) — the same trap Slice 5 hit with the metronome. A plain
    /// shape with an explicit tap gesture and an explicit long-press gesture keeps the two
    /// apart; it's the loop row's proven idiom.
    private var browseHeader: some View {
        HStack {
            Text(title)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer()
            if !expanded {
                Text(summary)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard let onBeginSelection else { return }
            haptic(.medium)     // confirm the hold landed before the header changes
            withAnimation(.easeInOut(duration: 0.2)) {
                // Selecting a **collapsed** panel would otherwise pin a selection bar over
                // no rows, with the chevron that would expand them gone. Entering the mode
                // expands the panel.
                expanded = true
                onBeginSelection()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title), \(expanded ? "expanded" : "collapsed")")
        .accessibilityHint("Double-tap to \(expanded ? "collapse" : "expand")")
        // VoiceOver can't long-press, so the mode needs a spoken way in — expanding the
        // same way the hold does, or it pins a selection bar over hidden rows.
        .accessibilityAction(named: "Select") {
            guard let onBeginSelection else { return }
            expanded = true
            onBeginSelection()
        }
    }
}

/// Standard panel surface — a hair off the background, in either appearance.
var panelBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(PocketColor.surfaceStandard)
}

/// Shown over the practice surface while a song's audio opens (brief §5 — every
/// state is designed). Dims the screen and absorbs touches so the half-ready
/// controls can't be tapped, and the user sees progress instead of a frozen app.
struct AudioLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(PocketColor.active)
                Text("Loading song…")
                    .font(.futura(.subheadline, weight: .medium))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .padding(28)
            .background(panelBackground)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading song")
    }
}

/// Shown when the song's audio could not be opened (bookmark no longer resolves,
/// file unreadable) — an honest notice instead of a silently dead transport
/// (audit 2026-07-05).
///
/// **Blocking** since the restore-from-backup pass (2026-08-07). It was previously a
/// see-through panel that let loops/markers stay browsable underneath, on the theory
/// that the rest of the screen was still useful. On a device it read as a washed-out
/// label floating over a transport that still invited taps, and the only way out was
/// the small back chevron. Nothing below this notice works without audio, so there is
/// nothing worth keeping browsable: dim, absorb touches, and offer the way out.
struct AudioUnavailableNotice: View {
    /// Points the song at a file again, keeping its loops and markers (ADR 0148 §6). The primary
    /// action: the player came here to practise, and relinking is the thing that lets them.
    let onRelink: () -> Void
    /// Leaves the practice screen, so a broken song is a detour rather than a dead end.
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            // Matches `AudioLoadingOverlay` — the two states are the same screen-level
            // interruption, and should not read as different weights of problem.
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.futura(.title))
                        .foregroundStyle(PocketColor.danger)
                    Text("This song's audio is missing")
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .multilineTextAlignment(.center)
                    // Names the actual cause rather than only the symptom: this is a broken link,
                    // not a corrupt song, so relinking is a real fix rather than a shrug. The copy
                    // is what a current import keeps (ADR 0148 §1), which is why the only songs that
                    // reach this notice are pre-0148 ones still resolving through a bookmark (§2).
                    Text("This song was added before Red Moon kept its own copy, and the link to "
                         + "your file has broken — it was moved, renamed or deleted, or the app "
                         + "was reinstalled. Find the file again and your loops, markers, takes "
                         + "and history all stay with it.")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                // Combined as one label so VoiceOver reads the problem in a breath; the
                // buttons stay separate elements, or neither way out would be reachable.
                .accessibilityElement(children: .combine)

                VStack(spacing: 10) {
                    Button(action: onRelink) {
                        Text("Find the file").pocketRunButton
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Choose this song's audio file again, keeping its loops")

                    Button(action: onLeave) {
                        Text("Not now")
                            .font(.futura(.subheadline, weight: .medium))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Leaves practice and returns to the previous screen")
                }
            }
            .padding(24)
            // Opaque, unlike the standard translucent `panelBackground` — over the dim, a
            // surface tint would leave the waveform legible straight through the words.
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PocketColor.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(PocketColor.surfaceBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
        }
        // Swallow taps meant for the dead transport underneath.
        .contentShape(Rectangle())
        .onTapGesture { }
    }
}

/// "Fit" pill shown in the waveform's top-trailing corner while zoomed in — the
/// explicit reset back to the whole song (1× zoom). Double-tap is reserved for
/// seek, so reset is its own control (ADR 0010 page-mode).
struct ZoomResetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Fit", systemImage: "arrow.left.and.right")
                .font(.futura(.caption2, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(PocketColor.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(PocketColor.background.opacity(0.85))
                        .overlay(Capsule().strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fit whole song")
        .accessibilityHint("Resets zoom to show the entire song")
    }
}

// `UndoToastView` moved to `UI/UndoToastView.swift` — the waveform's loop/marker deletes and
// every list row's delete (`.pocketRowActions`) now render the same pill.
