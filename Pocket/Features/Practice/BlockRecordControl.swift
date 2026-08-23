import SwiftUI

/// The per-block **record switch** (ADR 0179, widened by ADR 0180) — carried by every block preview
/// that runs a drill: ramped exercises and loop trainers, and the ramp-less ear and improvise modes.
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
/// **A ramp-less block is the same switch making a smaller promise** (ADR 0180 D1). Ear and improvise
/// blocks never auto-start, so their own arm ring has always been reachable mid-session — the switch
/// pre-arms it rather than replacing it, which is why their copy says the ring is still there.
///
/// Owner-agnostic like `BlockLengthControl` beside it: it reads and writes one flag and knows nothing
/// about exercises, loops, or who ends up owning the take.
struct BlockRecordControl: View {
    /// What the block does when it runs, which is all this control needs to know to describe itself.
    /// Not the run mode and not the owner — those would drag the control back into knowing who it is
    /// editing, and two blocks with different owners say exactly the same thing here.
    enum Kind: Equatable {
        /// A ramped exercise or loop trainer: it starts itself, and there is nothing to tap.
        case ramped
        /// Ear training or improvising: the block's own record ring stays, pre-armed. `openEnded`
        /// blocks have no length to end the take, so it runs until Done.
        case rampLess(openEnded: Bool)
    }

    /// The block's flag (`RoutineItem.recordsTake`) — writes straight through to the model, as the
    /// block preview's tempo edits do (ADR 0077: a surface with no Start to defer to).
    @Binding var recordsTake: Bool
    let tint: Color
    var kind: Kind = .ramped

    /// Sampled once per appearance rather than read in `body`: `AVAudioApplication.recordPermission`
    /// is a system call, and this view sits inside a `ScrollView` that re-renders freely.
    @State private var permission = MicPermission.status

    /// Where the take turns up, which is not the same place for both kinds. A ramped block lands on a
    /// completion screen and the take is offered there (ADR 0179 D4); a **ramp-less** block has no
    /// completion screen at all — there is nothing to grade or promote on an ear or improvise block
    /// (ADR 0104/0135/0141), so it advances straight on. Saying "when the block finishes" there would
    /// promise a screen the player will never see. It hands the take back in place instead, through
    /// the **Take saved** line and takes list already on that screen.
    private var subtitle: String {
        switch kind {
        case .ramped:
            "capture a take while it runs — hear it back when the block finishes"
        case .rampLess:
            "capture a take while it runs — hear it back on the block itself"
        }
    }

    /// What turning it on has committed you to. One sentence about the take's edges, one about where
    /// it lands — the second never varies, because the owner rule never does (ADR 0179 D4).
    private var onCopy: String {
        let edges: String
        switch kind {
        case .ramped:
            edges = "The take starts with the block and ends with it."
        case .rampLess(let openEnded):
            edges = openEnded
                ? "The take starts with the backing track and runs until you tap Done. "
                    + "You can still stop it from the block itself."
                : "The take starts with the backing track and ends with the block. "
                    + "You can still stop it from the block itself."
        }
        return edges + " It's saved against this exercise or loop, not the routine."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { recordsTake },
                                 set: { recordsTake = $0; haptic(.light) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Record this block")
                        .font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                    Text(subtitle)
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
                Text(onCopy)
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
