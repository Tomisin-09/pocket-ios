import SwiftUI

/// The in-app contact form (ADR 0161) — the message, the address we reply to, and a plain statement of
/// what travels with it.
///
/// **This replaces a `mailto:` that silently did nothing** on a device with no Mail account configured
/// (the failure documented at `AboutSection` and `FAQEntry.supportAddress`). A form that posts over
/// HTTPS works on every device, whether or not Mail is set up.
///
/// It does **not** replace the plain-text address in the "How do I get help?" answer. That address is
/// still the fallback, and it matters more now than it did: a `mailto:` failed silently, whereas this
/// fails *out loud* and then has to tell the player where else to go (ADR 0161 D5).
struct ContactSupportSheet: View {
    /// Injected so previews and tests drive a `RecordingSupportSender` instead of the network.
    let sender: SupportSending

    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var replyAddress = ""
    @State private var state: SendState = .editing
    @FocusState private var focus: Field?

    /// The diagnostics are captured **once, when the sheet opens**, and shown from that snapshot — the
    /// player is looking at the exact values that will be sent, not a fresh read taken later.
    private let diagnostics = SupportDiagnostics.current

    private enum Field: Hashable { case message, address }

    private enum SendState: Equatable {
        case editing
        case sending
        case failed(SupportSendError)

        var isSending: Bool { self == .sending }
    }

    private var request: SupportRequest {
        SupportRequest(message: message, replyAddress: replyAddress, diagnostics: diagnostics)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your email", text: $replyAddress)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .address)
                } header: {
                    Text("Your email")
                } footer: {
                    Text("We reply to this address. It's used to answer you and nothing else.")
                }

                Section {
                    TextField("What's happening?", text: $message, axis: .vertical)
                        .lineLimit(5...12)
                        .focused($focus, equals: .message)
                } header: {
                    Text("Message")
                }

                Section {
                    // Shown, not hidden behind a disclosure — the whole point is that nothing is
                    // attached the player hasn't read (ADR 0161 D3). `summary` is the same property
                    // the payload is built from, so this cannot drift from what is actually sent.
                    Text(diagnostics.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sent with your message")
                } footer: {
                    Text("Nothing else goes with it — not your songs, your recordings, your notes or "
                        + "your artist name.")
                }

                if case let .failed(error) = state {
                    Section {
                        Text(error.playerFacingMessage)
                            .font(.footnote)
                            .foregroundStyle(PocketColor.danger)
                    }
                }
            }
            .navigationTitle("Contact support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(state.isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if state.isSending {
                        ProgressView()
                    } else {
                        Button("Send") { send() }
                            .disabled(!request.isSendable)
                    }
                }
            }
            .onAppear { focus = .message }
        }
        .interactiveDismissDisabled(state.isSending)
    }

    /// Sends, and on failure **keeps the sheet open with every character intact**. Losing a written
    /// message to a dropped connection would be a second failure on top of the first, and the player
    /// would have no idea the first had happened.
    private func send() {
        focus = nil
        state = .sending
        let request = request
        Task {
            do {
                try await sender.send(request)
                dismiss()
            } catch let error as SupportSendError {
                state = .failed(error)
            } catch {
                state = .failed(.network)
            }
        }
    }
}

#Preview("Empty") {
    ContactSupportSheet(sender: RecordingSupportSender())
}

#Preview("Send fails") {
    ContactSupportSheet(sender: RecordingSupportSender(failing: .network))
}
