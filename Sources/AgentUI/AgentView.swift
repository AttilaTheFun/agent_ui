import SwiftUI

/// The agent's chat page: the transcript over the composer, the shape the
/// Playground developed and Visor reuses for a remote agent. The messages,
/// the streaming reply and the activity line are the app's values, kept
/// current from whatever drives the agent (an in-process tool loop, a
/// Claude Code or Codex process on another machine); the composer's
/// controls and attachments are the app's views.
public struct AgentView<Controls: View, Attachments: View>: View {
    let messages: [TranscriptMessage]
    let status: [ActivityItem]
    let activity: String?
    let error: String?
    let emptyTitle: String
    let emptyBody: String
    let emptyFootnote: String?
    /// Asks for what the thread holds before what is shown; nil when it is all here.
    let loadEarlier: (() -> Void)?
    @Binding var draft: String
    let placeholder: String
    let busy: Bool
    let sending: Bool
    let attachmentCount: Int
    let send: () -> Void
    let stop: () -> Void
    /// Interrupt the turn and say what is written now; nil leaves a busy
    /// composer with only Stop.
    let steer: (() -> Void)?
    let controls: () -> Controls
    let attachments: () -> Attachments
    let suggestions: (String) -> [AgentSuggestion]
    let pick: (AgentSuggestion) -> Void
    let dictation: (any Dictation)?
    let subSessions: [SubSession]
    let openSubSession: (SubSession) -> Void
    let endSubSession: ((SubSession) -> Void)?

    /// - Parameters:
    ///   - messages: the record; the only thing that adds rows.
    ///   - status/activity: what the turn is doing, in the status row under the thread.
    ///   - error: the last failure, in the status row while idle.
    ///   - busy: the agent is working; the status row spins and the composer offers Stop.
    ///   - sending: a message sent is not on the record yet; the send button says so.
    ///   - subSessions: the conversations open from this one, a row each above the composer.
    public init(messages: [TranscriptMessage], status: [ActivityItem] = [], activity: String? = nil,
                error: String? = nil, emptyTitle: String = "What should we build?", emptyBody: String,
                emptyFootnote: String? = nil, draft: Binding<String>, placeholder: String = "Message the agent…",
                busy: Bool, sending: Bool = false, attachmentCount: Int = 0, send: @escaping () -> Void,
                stop: @escaping () -> Void, steer: (() -> Void)? = nil, loadEarlier: (() -> Void)? = nil,
                suggestions: @escaping (String) -> [AgentSuggestion] = { _ in [] }, pick: @escaping (AgentSuggestion) -> Void = { _ in },
                dictation: (any Dictation)? = nil, subSessions: [SubSession] = [],
                openSubSession: @escaping (SubSession) -> Void = { _ in }, endSubSession: ((SubSession) -> Void)? = nil,
                @ViewBuilder controls: @escaping () -> Controls,
                @ViewBuilder attachments: @escaping () -> Attachments) {
        self.messages = messages
        self.status = status
        self.activity = activity
        self.error = error
        self.emptyTitle = emptyTitle
        self.emptyBody = emptyBody
        self.emptyFootnote = emptyFootnote
        self.loadEarlier = loadEarlier
        self._draft = draft
        self.placeholder = placeholder
        self.busy = busy
        self.sending = sending
        self.attachmentCount = attachmentCount
        self.dictation = dictation
        self.subSessions = subSessions
        self.openSubSession = openSubSession
        self.endSubSession = endSubSession
        self.send = send
        self.stop = stop
        self.steer = steer
        self.controls = controls
        self.attachments = attachments
        self.suggestions = suggestions
        self.pick = pick
    }

    /// Set as a message is sent, for the moment the composer and the
    /// thread both change: the thread holds still through it.
    @State private var sendingNow = false
    /// The composer's height, for the thread to keep its bottom above it.
    @State private var composerHeight: CGFloat = 0
    @State private var sendingEnds: Task<Void, Never>?
    /// The user typing: set by each change to the draft and let go a moment
    /// after the last, or at once when the draft empties (sent). The
    /// thread's new rows wait meanwhile.
    @State private var typing = false
    @State private var typingEnds: Task<Void, Never>?
    /// The call for earlier rows, held across passes for the thread: given
    /// a closure, it would be evaluated again on each of this view's.
    @State private var earlier = ViewAction()

    /// Sending, with the thread told first — in the same update as the
    /// draft clearing and the message going in.
    private func held(_ action: @escaping () -> Void) -> () -> Void {
        {
            sendingNow = true
            action()
            // One end at a time: a second send takes over the first's.
            sendingEnds?.cancel()
            sendingEnds = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                sendingNow = false
            }
        }
    }

    public var body: some View {
        earlier.run = loadEarlier ?? {}
        return TranscriptView(messages: messages, busy: busy, status: status, activity: activity, error: error,
                              emptyTitle: emptyTitle, emptyBody: emptyBody, emptyFootnote: emptyFootnote,
                              earlier: loadEarlier == nil ? nil : earlier, sending: sendingNow, composerHeight: composerHeight,
                              typing: typing)
            .agentComposerBar {
                AgentComposer(draft: $draft, placeholder: placeholder, busy: busy,
                              attachmentCount: attachmentCount, send: held(send), stop: stop, steer: steer.map(held),
                              sending: sending, suggestions: suggestions, pick: pick, dictation: dictation,
                              subSessions: subSessions, openSubSession: openSubSession, endSubSession: endSubSession,
                              controls: controls, attachments: attachments)
                    .background(GeometryReader { proxy in
                        // Whole points, and only a real change: a measure
                        // that differs by a fraction would write again and
                        // lay the screen out once more for nothing.
                        Color.clear.onChange(of: proxy.size.height.rounded(), initial: true) { _, height in
                            if abs(height - composerHeight) >= 1 { composerHeight = height }
                        }
                    })
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: draft) { _, now in
                typingEnds?.cancel()
                guard !now.isEmpty else {
                    if typing { typing = false }
                    return
                }
                if !typing { typing = true }
                typingEnds = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    typing = false
                }
            }
    }
}

extension AgentView where Controls == EmptyView, Attachments == EmptyView {
    public init(messages: [TranscriptMessage], activity: String? = nil,
                error: String? = nil, emptyTitle: String = "What should we build?", emptyBody: String,
                emptyFootnote: String? = nil, draft: Binding<String>, placeholder: String = "Message the agent…",
                busy: Bool, send: @escaping () -> Void, stop: @escaping () -> Void, loadEarlier: (() -> Void)? = nil) {
        self.init(messages: messages, activity: activity, error: error,
                  emptyTitle: emptyTitle, emptyBody: emptyBody, emptyFootnote: emptyFootnote, draft: draft,
                  placeholder: placeholder, busy: busy, send: send, stop: stop, steer: nil, loadEarlier: loadEarlier,
                  controls: { EmptyView() }, attachments: { EmptyView() })
    }
}
