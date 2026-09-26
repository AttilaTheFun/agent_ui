import AgentUI
import SwiftUI

// AgentView on a fake agent: a reply streams in word by word after an
// activity line, with a tool row between. The shape Visor gives a remote
// Claude Code or Codex session, and the Playground its on-device agent.
@main
struct AgentExampleApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                AgentExampleScreen()
                    .navigationTitle("Agent")
            }
        }
    }
}

struct AgentExampleScreen: View {
    @State private var messages: [TranscriptMessage] = []
    @State private var streaming = ""
    @State private var activity: String?
    @State private var draft = ""
    @State private var busy = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        AgentView(messages: messages, activity: activity,
                  emptyBody: "Ask for anything; this agent echoes it back, slowly, after pretending to build.",
                  emptyFootnote: "Model: example", draft: $draft, busy: busy, send: send, stop: stop) {
            Button { } label: { AgentPillLabel("example") }.agentPillButton()
        } attachments: {
            EmptyView()
        }
    }

    private func send() {
        let text = AgentText.trimmed(draft)
        draft = ""
        messages.append(TranscriptMessage(id: "u\(messages.count)", role: .user, text: text))
        busy = true
        task = Task {
            activity = "Thinking…"
            try? await Task.sleep(for: .milliseconds(600))
            activity = "Building"
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            messages.append(TranscriptMessage(id: "t\(messages.count)", role: .tool, text: "ok", toolName: "build"))
            activity = nil
            for word in ("You said: " + text).split(separator: " ") {
                guard !Task.isCancelled else { return }
                streaming += (streaming.isEmpty ? "" : " ") + word
                try? await Task.sleep(for: .milliseconds(120))
            }
            messages.append(TranscriptMessage(id: "a\(messages.count)", role: .assistant, text: streaming,
                                              activities: ["Building"]))
            streaming = ""
            busy = false
        }
    }

    private func stop() {
        task?.cancel()
        activity = nil
        if !streaming.isEmpty {
            messages.append(TranscriptMessage(id: "a\(messages.count)", role: .assistant, text: streaming))
            streaming = ""
        }
        busy = false
    }
}
