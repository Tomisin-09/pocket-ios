import SwiftData
import SwiftUI

/// **Marking a block to record** (ADR 0179, reached from the block list by ADR 0180) — the flag's
/// binding, the swipe that flips it, and the one thing that can stop it.
///
/// Split from `RoutineDetailView+BlockPreview.swift` because the switch is no longer only a preview
/// concern: the preview explains the choice, and the swipe makes it without the three taps and a
/// scroll that reaching the preview costs.
extension RoutineDetailView {

    /// Whether to offer the swipe at all — `RoutineItem.canRecordTake`, the one rule the player and
    /// the block-list badge also read, so a swipe is never offered on a block that would ignore it.
    func canRecord(_ item: RoutineItem) -> Bool { item.canRecordTake }

    /// Flip the flag from the block list.
    ///
    /// **Denial is refused rather than obeyed.** The preview's switch can go `.disabled` and say why
    /// beside itself; a swipe has nowhere to put that, and flipping it anyway would paint a record
    /// badge on a block that cannot record — the app quietly claiming a take that will never exist.
    /// So the swipe raises the alert instead and leaves the flag alone.
    func toggleRecords(_ item: RoutineItem) {
        guard MicPermission.status != .denied else {
            micAccessBlocked = true
            return
        }
        recordsTake(of: item).wrappedValue.toggle()
        haptic(.light)
    }

    /// A binding onto a block's **record this block** flag (ADR 0179), carrying the editor's save
    /// discipline — commit now on a stored routine, ride along with a provisional generated session
    /// until Save or Start.
    ///
    /// **This is where the microphone prompt happens** (D3), from the preview switch and the swipe
    /// alike. Every other surface in the app arms on a setup screen for exactly this reason (ADR 0069
    /// slice 2): a system prompt belongs in a settled, non-playing moment, and building a routine is
    /// the most settled moment there is. At run time the block arms through
    /// `RecordingController.armIfPermitted()`, which never prompts — a routine with auto-start on
    /// cannot wait on a dialog.
    ///
    /// A denial **reverts the flag**, so the block list can't show a record badge on a block that has
    /// no way to record.
    func recordsTake(of item: RoutineItem) -> Binding<Bool> {
        Binding(get: { item.recordsTake },
                set: { newValue in
                    item.recordsTake = newValue
                    if existsInStore { try? editContext.save() }
                    guard newValue else { return }
                    // One event, at the decision — not once per block-run, which would count the same
                    // choice every time the routine is played (ADR 0120).
                    Analytics.send(.toolOpened(tool: .recording))
                    guard MicPermission.status == .undetermined else { return }
                    // Explicitly `@MainActor`: the sandboxed `RoutineItem` written on the far side
                    // of the await is a `@Model`, and CI's older toolchain is stricter about this
                    // than local Xcode is.
                    Task { @MainActor in
                        let granted = await MicPermission.request()
                        Analytics.send(.micPermission(outcome: granted ? .granted : .denied))
                        guard !granted else { return }
                        item.recordsTake = false
                        if existsInStore { try? editContext.save() }
                    }
                })
    }

    /// The **leading** swipe on a block row (ADR 0180 D4).
    ///
    /// Leading on purpose: trailing is swipe-to-delete in edit mode, and the app's swipe grammar
    /// already reads right as the affirmative, non-destructive one — favourite a library row, name a
    /// take. It sits on both modes because the flag is not behind the Edit gate (ADR 0179): it says
    /// what the next run should capture, not what shape the routine is.
    @ViewBuilder
    func recordSwipe(for item: RoutineItem) -> some View {
        if canRecord(item) {
            Button { toggleRecords(item) } label: {
                Label(item.recordsTake ? "Don't record" : "Record",
                      systemImage: item.recordsTake ? "waveform.slash" : "waveform")
            }
            .tint(item.recordsTake ? PocketColor.textSecondary : PocketColor.practice)
        }
    }

}

/// Where the swipe's refusal lands (ADR 0180 D4). The same sentence `BlockRecordControl` shows beside
/// its disabled switch, plus the way out — an alert can offer Settings, which a caption beside a
/// switch cannot.
struct MicAccessAlert: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert("Microphone access is off", isPresented: $isPresented) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Enable it in Settings to record practice takes.")
        }
    }
}
