import SwiftUI

/// *Use your markers as sections?* (ADR 0232 D7), offered once on a song that has markers and no
/// sections. Sections are what give the map its shape, and the player's own markers usually already say
/// where they are. Nothing changes from the card: it opens the list, where the player confirms.
struct SongMapSectionOffer: View {
    let onChoose: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Use your markers as sections?")
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text("Sections split the map into the song's parts, each on its own rows with its name above. "
                 + "Your markers can start them.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 20) {
                Button("Choose sections", action: onChoose)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.active)
                Button("Not now", action: onNotNow)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// The list behind *Choose sections* (D7): every marker on the song, earliest first, with those whose
/// labels read as a section (Intro, Verse, Chorus…) ticked. **Nothing changes until Use.** It's only ever
/// the player's own words: a section is never suggested from the audio.
struct SongMapSectionsSheet: View {
    let markers: [Marker]
    let duration: TimeInterval
    /// The markers were used: the offer has been answered.
    let onUse: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ticked: Set<UUID>

    init(markers: [Marker], duration: TimeInterval, onUse: @escaping () -> Void) {
        let inside = markers.filter { $0.seconds >= 0 && $0.seconds < duration }
            .sorted { $0.seconds < $1.seconds }
        self.markers = inside
        self.duration = duration
        self.onUse = onUse
        _ticked = State(initialValue: Set(inside.filter { SectionWords.readsAsSection($0.label) }.map(\.uid)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(markers, id: \.uid) { marker in row(marker) }
                } footer: {
                    Text("A ticked marker starts a section. Markers named like a song's parts are ticked to "
                         + "begin with. You can change any of them later on the marker.")
                }
            }
            .navigationTitle("Choose sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { use() }
                        .disabled(ticked.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ marker: Marker) -> some View {
        let isTicked = ticked.contains(marker.uid)
        return Button {
            if isTicked { ticked.remove(marker.uid) } else { ticked.insert(marker.uid) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isTicked ? PocketColor.active : PocketColor.textSecondary)
                    .imageScale(.large)
                Text(marker.label.isEmpty ? "Marker" : marker.label)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Text(timecode(marker.seconds))
                    .font(.pocketMono(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isTicked ? "Starts a section" : "Stays a pin")
        .accessibilityAddTraits(isTicked ? .isSelected : [])
    }

    private func use() {
        for marker in markers where ticked.contains(marker.uid) { marker.startsSection = true }
        onUse()
        dismiss()
    }
}
