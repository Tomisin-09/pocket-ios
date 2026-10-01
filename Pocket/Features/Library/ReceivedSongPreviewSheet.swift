import SwiftUI

/// A song somebody sent, shown **before** it lands (ADR 0236 D4, after ADR 0188 D9): what it is, who sent
/// it, what comes with it, and the name it will take here.
///
/// Reads every count off `ReceivedSong`, so what's shown and what lands come from one place.
struct ReceivedSongPreviewSheet: View {
    let received: ReceivedSong
    /// What it will be called here: its own title, or a copy's when the library has that title (D5).
    let title: String
    /// Land it. The host owns the store, as it does for routines and drills.
    let onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if !received.record.artist.isEmpty {
                        row("Artist", received.record.artist, "music.mic")
                    }
                    row("Loops", "\(received.record.loops.count)", "repeat")
                    row("Markers", "\(received.record.markers.count)", "flag")
                    if let tempo { row("Tempo", tempo, "metronome") }
                } header: {
                    Text(title)
                } footer: {
                    Text(provenance)
                }

                // Only when it lands under another name: say why, so a second "Low Road" in the library
                // is a copy the player expected rather than a mystery.
                if title != received.displayTitle {
                    Section {
                        Text("You have a song called \(received.displayTitle). This one goes beside it, as "
                             + "\(title).")
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                            .listRowBackground(PocketColor.background)
                    }
                }

                Section {
                    Text("Its loops come with their speeds and ramps, ready to practise. The sender’s pieces, "
                         + "mastery and practice history stayed with them.")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                        .listRowBackground(PocketColor.background)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add this song?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .tint(PocketColor.library)
                }
            }
        }
    }

    /// *Sent by Tomisin from Red Moon 1.3 on …*: on this door, the only provenance there is (D7).
    private var provenance: String {
        let who = received.senderName.map { "Sent by \($0) from" } ?? "Sent from"
        return "\(who) Red Moon \(received.appVersion) on "
            + received.exportedAt.formatted(date: .abbreviated, time: .shortened)
            + ". Adding it makes your own copy — nothing in your library is changed or replaced."
    }

    /// *92 BPM · 4/4*, when the song has a tempo.
    private var tempo: String? {
        guard let bpm = received.record.preciseBPM ?? received.record.bpm.map(Double.init) else { return nil }
        return "\(Int(bpm.rounded())) BPM · \(received.record.beatsPerBar)/\(received.record.noteValue)"
    }

    private func row(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer()
            Text(value)
                .font(.futura(.body).monospacedDigit())
                .foregroundStyle(PocketColor.textSecondary)
        }
        .listRowBackground(PocketColor.background)
    }
}
