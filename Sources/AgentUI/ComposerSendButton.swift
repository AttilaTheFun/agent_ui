import SwiftUI

/// The send button, or what stands in its place: a spinner while a message
/// is on its way, stop (with send-now and queue) while the agent works. A
/// view of its own, the one that reads the draft (is there anything to
/// send?), so a keystroke redraws it and not its neighbours.
struct ComposerSendButton: View {
    @Binding var draft: String
    let busy: Bool
    let sending: Bool
    let attachmentCount: Int
    /// The composer's sends: what clears and renews the field is done there.
    let send: () -> Void
    let steer: (() -> Void)?
    let stop: () -> Void

    private var canSend: Bool { !AgentText.isBlank(draft) || attachmentCount > 0 }

    var body: some View {
        if sending {
            // The send button, spinning until the message is on the record.
            Button {} label: { ProgressView().controlSize(.small).tint(.white) }
                .agentCircleButton()
                .padding(AgentComposerMetrics.controlsRoom)
                .allowsHitTesting(false)
                .accessibilityLabel("Sending")
                .accessibilityIdentifier("sending")
        } else if busy, canSend, let steer {
            // Something written while the agent works: say it now, keep it
            // for after, or just stop.
            Menu {
                Button(action: steer) { Label("Send now", systemImage: "forward.end") }
                Button(action: send) { Label("Queue for after", systemImage: "clock") }
                Button(role: .destructive, action: stop) { Label("Stop", systemImage: "stop.fill") }
            } label: {
                Image(systemName: "stop.fill")
            }
            .agentCircleButton(tint: AgentComposerMetrics.stopTint)
            .padding(AgentComposerMetrics.controlsRoom)
            .accessibilityLabel("Stop, send now, or queue")
            .accessibilityIdentifier("busy-actions")
        } else if busy {
            // Nothing written: the button only stops.
            Button(action: stop) { Image(systemName: "stop.fill").agentCircleTarget(tint: AgentComposerMetrics.stopTint) }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop")
        } else {
            Button(action: send) { Image(systemName: "arrow.up").agentCircleTarget() }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
        }
    }
}
