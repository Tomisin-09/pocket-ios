import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The **Audio** section of `SongDetailsSheet`: what file this song is playing, and the way to
/// point it at a different one (ADR 0152).
///
/// ADR 0148 §6 put relink behind the failure itself — "Find the file" on `AudioUnavailableNotice`,
/// offered at the moment the problem is discovered. That is still the right door for a *broken*
/// song, and it stays. But it is only reachable while the audio won't load, and a relink onto a
/// readable-but-wrong file succeeds: the song resolves, the notice never shows again, and the
/// player is left with a song that plays the wrong recording and no way back. Re-importing isn't
/// one — it mints a new `sourceID` and strands the loops, markers, takes and history (§4).
///
/// So the repair needs a second door that does not depend on anything being broken. It lives here,
/// in the per-song inspector, reachable both from the library row menu and by holding the title on
/// the practice screen — one hold from where a wrong track is actually heard.
///
/// Lives in its own file because `SongDetailsSheet` is already near the 400-line cap.
struct SongAudioSection: View {
    let song: Song

    /// Performs the swap. Injected because the two callers have different obligations: the library
    /// owns no audio engine and goes straight through `SongRelinker.replace`, while the practice
    /// screen has the old file **open** and must stop the engine and reload around it — replacing
    /// the bytes under a live `AVAudioFile` otherwise. Same two halves either way.
    let replace: (URL) async throws -> SongRelinker.Outcome

    @State private var confirming = false
    @State private var picking = false
    @State private var busy = false
    @State private var alert: ReplaceAlert?

    /// A one-shot message about a replace — the failure, or the success that needs a caveat.
    /// Mirrors `WaveformPracticeView.RelinkAlert`, whose flow this shares.
    struct ReplaceAlert {
        let title: String
        let message: String
    }

    /// Clears the message on dismiss, so each replace gets its own.
    private var alertBinding: Binding<Bool> {
        Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })
    }

    var body: some View {
        Section {
            LabeledContent {
                Text(fileDescription)
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)
            } label: {
                Text("File").foregroundStyle(PocketColor.textSecondary)
            }

            Button { confirming = true } label: {
                HStack(spacing: 8) {
                    Label("Replace audio file…", systemImage: "waveform.badge.plus")
                        .foregroundStyle(PocketColor.library)
                    if busy {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            // A second pick landing mid-replace would race two decodes onto one `sourceID` and the
            // loser would overwrite the winner's copy — the same guard the practice screen keeps.
            .disabled(busy)
        } header: {
            Text("Audio")
        } footer: {
            Text("Points this song at a different file — for a song whose audio is missing, or one "
                 + "linked to the wrong track. Your loops, markers, takes and practice history all "
                 + "stay with the song.")
        }
        // Single selection: this repairs *this* song, unlike the library's multi-select import.
        .fileImporter(isPresented: $picking, allowedContentTypes: [.audio],
                      allowsMultipleSelection: false, onCompletion: handlePick)
        .confirmationDialog("Replace this song's audio?", isPresented: $confirming,
                            titleVisibility: .visible) {
            Button("Choose a file…") { picking = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The new file replaces this song's audio. Your loops, markers, takes and practice "
                 + "history stay with the song.")
        }
        // Bool-bound rather than `.alert(item:)`, which only has the deprecated `Alert`-returning
        // form — same shape as `WaveformPracticeView`'s relink alert.
        .alert(alert?.title ?? "", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alert?.message ?? "")
        }
    }

    private var fileDescription: String {
        SongAudioLabel.describe(audioFileName: song.audioFileName,
                                hasBookmark: song.bookmark != nil,
                                sizeInBytes: song.audioFileName.flatMap {
                                    SongFileStore.fileSize(fileName: $0)
                                })
    }

    private func handlePick(_ result: Result<[URL], Error>) {
        guard !busy else { return }
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                alert = ReplaceAlert(title: "Couldn’t open that file",
                                     message: error.localizedDescription)
            }
            return
        }
        busy = true
        Task {
            defer { busy = false }
            do {
                let outcome = try await replace(url)
                // Success is otherwise invisible here — unlike the practice screen, where the
                // waveform redrawing *is* the confirmation, this sheet looks identical afterwards.
                // A player correcting a wrong link needs to know it took.
                alert = outcome.durationChangedMaterially
                    ? ReplaceAlert(title: "Audio replaced", message: mismatchMessage)
                    : ReplaceAlert(title: "Audio replaced",
                                   message: "This song now plays the file you picked.")
            } catch {
                alert = ReplaceAlert(title: "Couldn’t use that file",
                                     message: error.localizedDescription)
            }
        }
    }

    /// A different *length* means a different recording, not a re-encode — and the loops were drawn
    /// against the old one. Say so rather than letting the player discover it as loops that play the
    /// wrong bars, but never delete their work on the strength of a guess (ADR 0148 §6).
    ///
    /// Worth noting the mismatch cuts both ways here: correcting a wrong link back to the *right*
    /// track will usually trip this warning too, and in that case the loops line up again.
    private var mismatchMessage: String {
        "That file is a different length from the one this song had, so its loops and markers may "
            + "no longer line up. Nothing was deleted — you can adjust or remove them yourself."
    }
}

/// How a song's audio is described in the details sheet (ADR 0152) — pure, so the three custody
/// states of ADR 0148 can be pinned by a test rather than only seen on a device.
///
/// It deliberately does **not** name the file. The copy Pocket owns is stored under a
/// `sourceID`-keyed leaf (`SongFileStore.fileName`), so the name on disk is ours, not the one the
/// player recognises — printing it would be a confident-looking lie. Format and size are honest and
/// are enough to tell two files apart when checking whether a link went to the wrong one.
enum SongAudioLabel {

    /// - Parameters:
    ///   - audioFileName: the owned copy's leaf name (ADR 0148 §1), `nil` for a song that predates
    ///     it and has not adopted yet.
    ///   - hasBookmark: whether a legacy in-place bookmark exists (§2/§5). With no copy *and* no
    ///     bookmark there is nothing left to play — the state relink exists to repair.
    ///   - sizeInBytes: size of the owned copy, `nil` if it can't be read — which for a song that
    ///     claims a copy means the file is gone from under it.
    static func describe(audioFileName: String?, hasBookmark: Bool, sizeInBytes: Int64?) -> String {
        guard let leaf = audioFileName else {
            return hasBookmark ? "Linked file" : "Missing"
        }
        let format = (leaf as NSString).pathExtension.uppercased()
        guard let bytes = sizeInBytes else {
            return format.isEmpty ? "In your library" : format
        }
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return format.isEmpty ? size : "\(format) · \(size)"
    }
}
