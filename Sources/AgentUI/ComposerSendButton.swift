import SwiftUI

/// The send button, or what stands in its place: a spinner while a message
/// is on its way, stop (with send-now and queue) while the agent works, a
/// microphone while nothing is written and dictation is at hand (a
/// waveform while it listens). A view of its own, the one that reads the
/// draft (is there anything to send?), so a keystroke redraws it and not
/// its neighbours.
struct ComposerSendButton: View {
    @Binding var draft: String
    let busy: Bool
    let sending: Bool
    let attachmentCount: Int
    /// The composer's sends (given the words as this view has them: what
    /// clears and renews the field is done there), stop, and what the
    /// microphone does — held by the composer across its passes.
    let actions: ComposerActions
    /// Whether sending now (cutting the turn short) is offered.
    let canSteer: Bool
    /// Whether there is dictation here: the microphone starts listening,
    /// or stops it while `listening`.
    let canDictate: Bool
    var listening = false

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
        } else if busy, canSend, canSteer, let steer = actions.steer {
            // Something written while the agent works: say it now, keep it
            // for after, or just stop.
            Menu {
                Button { steer(draft) } label: { Label("Send now", systemImage: "forward.end") }
                Button { actions.send(draft) } label: { Label("Queue for after", systemImage: "clock") }
                Button(role: .destructive, action: actions.stop) { Label("Stop", systemImage: "stop.fill") }
            } label: {
                Image(systemName: "stop.fill")
            }
            .agentCircleButton(tint: AgentComposerMetrics.stopTint)
            .padding(AgentComposerMetrics.controlsRoom)
            .accessibilityLabel("Stop, send now, or queue")
            .accessibilityIdentifier("busy-actions")
        } else if busy {
            // Nothing written: the button only stops.
            Button(action: actions.stop) { Image(systemName: "stop.fill").agentCircleTarget(tint: AgentComposerMetrics.stopTint) }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop")
        } else if listening, canDictate, let dictate = actions.dictate {
            // Listening: the button stops it, and what was heard stays.
            Button(action: dictate) { Image(systemName: "waveform").agentCircleTarget(tint: AgentComposerMetrics.stopTint) }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop dictating")
                .accessibilityIdentifier("dictating")
        } else if !canSend, canDictate, let dictate = actions.dictate {
            // Nothing written: the microphone, where there is dictation.
            Button(action: dictate) { Image(systemName: "mic.fill").agentCircleTarget() }
                .buttonStyle(.plain)
                .accessibilityLabel("Dictate")
                .accessibilityIdentifier("dictate")
        } else {
            Button { actions.send(draft) } label: { Image(systemName: "arrow.up").agentCircleTarget() }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
        }
    }
}
