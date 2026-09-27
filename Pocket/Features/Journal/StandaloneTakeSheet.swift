import SwiftData
import SwiftUI

/// **Record a take against nothing** (ADR 0224) — the Journal's ＋ ▸ *Record a take*.
///
/// The audio counterpart of the standalone note (ADR 0155): something played that belongs to no loop
/// or exercise — a riff you want to keep, how the new strings sound, a first go at a song you haven't
/// imported. The same test admits it (0155 §3a): the Journal has no unit whose snapshot would be
/// honest, so the take is filed against nothing rather than against whatever happened to be on
/// screen.
///
/// **One control, tap to start and tap again to stop** — `RecordingController.toggleTake`, the
/// start-less grammar freeform blocks already use (ADR 0069 amendment, 2026-08-05). There is no run to
/// arm against, and nothing is playing, so there is no category flip mid-stream to protect: the take
/// asserts the record session as it begins and restores playback as it ends.
///
/// **While a take is rolling, neither a swipe nor Done closes the sheet.** The only way out of a take
/// is the control that saves it, so a take is never ended by a gesture that meant something else. The
/// disappear hook still finishes one — teardown the player didn't ask for is the case it covers, not
/// a path the player is offered.
struct StandaloneTakeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = RecordingController()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                recordButton
                status
                    .frame(minHeight: 56, alignment: .top)
                Spacer(minLength: 0)
                // The same sentence the standalone note's composer ends on (`JournalOwner`), so the
                // two doors on one ＋ say where things land in one voice.
                Text(JournalOwner.standalone.destinationLine)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Record a take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(recorder.isRecording)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(recorder.isRecording)
        .onDisappear {
            recorder.finishIfRecording(owner: .standalone, context: modelContext)
            // Nothing is held here, but this also invalidates a `toggleTake` suspended on the
            // permission prompt — without it, dismissing mid-prompt starts a mic on a dead sheet.
            recorder.releaseRecordSession()
        }
    }

    /// The one control. A `Button` is safe here — there is no hold on it (memory: *a Button + a hold
    /// fires both*).
    private var recordButton: some View {
        Button {
            haptic(recorder.isRecording ? .medium : .light)
            Task { await recorder.toggleTake(owner: .standalone, context: modelContext) }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.red.opacity(0.5), lineWidth: 3)
                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(Color.red)
                        .padding(10)
                }
            }
            .frame(width: 88, height: 88)
            .background(Circle().fill(Color.red.opacity(recorder.isRecording ? 0.28 : 0.12)))
            .recordPulse(recorder.isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? "Stop and save this take" : "Start recording")
    }

    /// Under the control: the live timer and route cue while rolling, the saved line once kept, the
    /// Settings pointer after a denial, and otherwise the one sentence the control needs.
    @ViewBuilder private var status: some View {
        if recorder.isRecording {
            RecordingStatusView(recorder: recorder)
        } else if recorder.micDenied {
            Text("Microphone access is off. Enable it in Settings to record practice takes.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        } else if recorder.lastSaved != nil {
            // `takeCount: 0` keeps it to the confirmation: "N takes on this block" has no owner to
            // count against here, and the feed behind the sheet is where the take now shows.
            TakeSavedNote(recorder: recorder, takeCount: 0)
        } else {
            Text("Tap to start. Tap again to stop and save.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Record a take") {
    Color.black
        .sheet(isPresented: .constant(true)) { StandaloneTakeSheet() }
        .modelContainer(for: Recording.self, inMemory: true)
        .preferredColorScheme(.dark)
}
