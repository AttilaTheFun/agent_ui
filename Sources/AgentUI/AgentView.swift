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

    /// - Parameters:
    ///   - messages: the record; the only thing that adds rows.
    ///   - status/activity: what the turn is doing, in the status row under the thread.
    ///   - error: the last failure, in the status row while idle.
    ///   - busy: the agent is working; the status row spins and the composer offers Stop.
    ///   - sending: a message sent is not on the record yet; the send button says so.
    public init(messages: [TranscriptMessage], status: [ActivityItem] = [], activity: String? = nil,
                error: String? = nil, emptyTitle: String = "What should we build?", emptyBody: String,
                emptyFootnote: String? = nil, draft: Binding<String>, placeholder: String = "Message the agent…",
                busy: Bool, sending: Bool = false, attachmentCount: Int = 0, send: @escaping () -> Void,
                stop: @escaping () -> Void, steer: (() -> Void)? = nil, loadEarlier: (() -> Void)? = nil,
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
        self.send = send
        self.stop = stop
        self.steer = steer
        self.controls = controls
        self.attachments = attachments
    }

    /// The composer's height, measured: the transcript re-pins its bottom
    /// as the box grows with a longer message.
    @State private var composerHeight: CGFloat = 0

    /// The thread as it was when a message was sent, held for a moment:
    /// the send's own changes (the field emptying, the composer shrinking)
    /// settle before a row or a status moves the thread. Only the send
    /// button's spinner changes meanwhile.
    @State private var held: Held?

    struct Held {
        let messages: [TranscriptMessage]
        let busy: Bool
        let status: [ActivityItem]
        let activity: String?
        let error: String?
    }

    /// Long enough for the keyboard to have gone.
    static var holdAfterSend: UInt64 { 550_000_000 }

    private func hold(_ action: @escaping () -> Void) -> () -> Void {
        {
            held = Held(messages: messages, busy: busy, status: status, activity: activity, error: error)
            action()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.holdAfterSend)
                held = nil
            }
        }
    }

    public var body: some View {
        let shown = held ?? Held(messages: messages, busy: busy, status: status, activity: activity, error: error)
        TranscriptView(messages: shown.messages, busy: shown.busy, status: shown.status, activity: shown.activity, error: shown.error,
                       emptyTitle: emptyTitle, emptyBody: emptyBody, emptyFootnote: emptyFootnote, loadEarlier: loadEarlier,
                       bottomInset: composerHeight)
            .agentComposerBar {
                AgentComposer(draft: $draft, placeholder: placeholder, busy: busy,
                              attachmentCount: attachmentCount, send: hold(send), stop: stop, steer: steer.map(hold),
                              sending: sending, controls: controls, attachments: attachments)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .onAppear { composerHeight = geometry.size.height }
                            .onChange(of: geometry.size.height) { height in composerHeight = height }
                    })
            }
            .scrollDismissesKeyboard(.interactively)
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

extension View {
    /// The composer as bar chrome at the bottom edge: `safeAreaBar` on 26
    /// (the glass edge treatment), `safeAreaInset` before and elsewhere.
    @ViewBuilder public func agentComposerBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            safeAreaBar(edge: .bottom, content: bar)
        } else {
            safeAreaInset(edge: .bottom, content: bar)
        }
        #else
        safeAreaInset(edge: .bottom, content: bar)
        #endif
    }
}
