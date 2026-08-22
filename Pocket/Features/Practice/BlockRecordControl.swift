import SwiftUI

/// The per-block **record switch** (ADR 0179) — carried by the ramped exercise and loop block
/// previews, and by nothing else.
///
/// A ramped drill already logs a tempo, which is what ADR 0069 slice 4 meant when it kept recording
/// out of routines: the block has its evidence. But a logged tempo says you reached 96 BPM, not
/// whether 96 *sounded* like anything, and that second question is the only one a take answers. So
/// recording is not something a ramped block does by default — it is something a block can be
/// **marked for**, here, while the routine is being built.
///
/// **Deliberately not on the running block.** Routine blocks auto-start by default, so a run-time
/// control would flash past unusable — and ADR 0077's "a routine block is not the full editor" is
/// about exactly this kind of accretion. Marked here, the block arms itself and the running screen
/// gains a status readout with nothing to tap.
///
/// Owner-agnostic like `BlockLengthControl` beside it: it reads and writes one flag and knows nothing
/// about exercises, loops, or who ends up owning the take.
struct BlockRecordControl: View {
    /// The block's flag (`RoutineItem.recordsTake`) — writes straight through to the model, as the
    /// block preview's tempo edits do (ADR 0077: a surface with no Start to defer to).
    @Binding var recordsTake: Bool
    let tint: Color

    /// Sampled once per appearance rather than read in `body`: `AVAudioApplication.recordPermission`
    /// is a system call, and this view sits inside a `ScrollView` that re-renders freely.
    @State private var permission = MicPermission.status

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { recordsTake },
                                 set: { recordsTake = $0; haptic(.light) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Record this block")
                        .font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                    Text("capture a take while it runs — hear it back when the block finishes")
                        .font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
                }
            }
            .tint(tint)
            .disabled(permission == .denied)
            .accessibilityHint("Records your playing for this block only")

            // Say why rather than leaving a dead toggle — the difference between disabled and broken,
            // the same line `RecordSetupHint` draws on the run screens.
            if permission == .denied {
                Text("Microphone access is off. Enable it in Settings to record practice takes.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if recordsTake {
                Text("The take starts with the block and ends with it. It's saved against this "
                     + "exercise or loop, not the routine.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.textSecondary.opacity(0.08)))
        // Re-sampled on return from Settings, so a player who grants access mid-edit isn't left
        // looking at a control that is still refusing them — and again after a flip, because the
        // first flip is what raises the system prompt (the host's binding awaits it, ADR 0179 D3)
        // and a denial there must land on this copy rather than a toggle that silently snapped back.
        .onAppear { permission = MicPermission.status }
        .onChange(of: recordsTake) { _, _ in permission = MicPermission.status }
    }
}
