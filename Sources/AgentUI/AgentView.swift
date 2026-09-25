import SwiftUI

/// The agent's chat page: the transcript over the composer, the shape the
/// Playground developed and Visor reuses for a remote agent. The messages,
/// the streaming reply and the activity line are the app's values, kept
/// current from whatever drives the agent (an in-process tool loop, a
/// Claude Code or Codex process on another machine); the composer's
/// controls and attachments are the app's views.
public struct AgentView<Controls: View, Attachments: View>: View {
    let messages: [TranscriptMessage]
    let streams: [StreamedMessage]
    let activity: String?
    /// The turn's streamed status lines so far, for the footer.
    let status: [ActivityItem]
    let error: String?
    let emptyTitle: String
    let emptyBody: String
    let emptyFootnote: String?
    /// Asks for what the thread holds before what is shown; nil when it is all here.
    let loadEarlier: (() -> Void)?
    @Binding var draft: String
    let placeholder: String
    let busy: Bool
    let attachmentCount: Int
    let send: () -> Void
    let stop: () -> Void
    /// Interrupt the turn and say what is written now; nil leaves a busy
    /// composer with only Stop.
    let steer: (() -> Void)?
    /// Said and not on the record yet: shown in the composer.
    let outgoing: [OutgoingMessage]
    /// Takes a queued message back into the field.
    let edit: ((OutgoingMessage) -> Void)?
    let controls: () -> Controls
    let attachments: () -> Attachments

    /// - Parameters:
    ///   - streams: the replies being written, or written and not yet on the record, one row each by message id.
    ///   - activity: what the agent is doing right now ("Building"), or nothing.
    ///   - error: the last failure, under the transcript.
    ///   - emptyTitle/emptyBody/emptyFootnote: the empty state.
    ///   - busy: the agent is working; the composer offers Stop.
    ///   - outgoing: messages said and not on the record yet, shown in the composer.
    ///   - edit: takes a queued message back into the field.
    public init(messages: [TranscriptMessage], streams: [StreamedMessage] = [], activity: String? = nil, status: [ActivityItem] = [],
                error: String? = nil, emptyTitle: String = "What should we build?", emptyBody: String,
                emptyFootnote: String? = nil, draft: Binding<String>, placeholder: String = "Message the agent…",
                busy: Bool, attachmentCount: Int = 0, send: @escaping () -> Void, stop: @escaping () -> Void,
                steer: (() -> Void)? = nil, outgoing: [OutgoingMessage] = [],
                edit: ((OutgoingMessage) -> Void)? = nil, loadEarlier: (() -> Void)? = nil,
                @ViewBuilder controls: @escaping () -> Controls,
                @ViewBuilder attachments: @escaping () -> Attachments) {
        self.loadEarlier = loadEarlier
        self.messages = messages
        self.streams = streams
        self.activity = activity
        self.status = status
        self.error = error
        self.emptyTitle = emptyTitle
        self.emptyBody = emptyBody
        self.emptyFootnote = emptyFootnote
        self._draft = draft
        self.placeholder = placeholder
        self.busy = busy
        self.attachmentCount = attachmentCount
        self.send = send
        self.stop = stop
        self.steer = steer
        self.outgoing = outgoing
        self.edit = edit
        self.controls = controls
        self.attachments = attachments
    }

    /// The composer's height, measured: the transcript re-pins its bottom
    /// as the box grows with a longer message.
    @State private var composerHeight: CGFloat = 0

    public var body: some View {
        // The thread is the record and the replies being written; what
        // the turn is doing, a failure and what is on its way are the
        // composer's, over its field.
        TranscriptView(messages: messages, streams: streams, activity: nil, status: [], error: nil,
                       emptyTitle: emptyTitle, emptyBody: emptyBody, emptyFootnote: emptyFootnote, loadEarlier: loadEarlier,
                       bottomInset: composerHeight)
            .agentComposerBar {
                AgentComposer(draft: $draft, placeholder: placeholder, busy: busy,
                              attachmentCount: attachmentCount, send: send, stop: stop, steer: steer,
                              status: status, activity: activity, error: error, outgoing: outgoing, edit: edit, controls: controls, attachments: attachments)
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
    public init(messages: [TranscriptMessage], streams: [StreamedMessage] = [], activity: String? = nil,
                error: String? = nil, emptyTitle: String = "What should we build?", emptyBody: String,
                emptyFootnote: String? = nil, draft: Binding<String>, placeholder: String = "Message the agent…",
                busy: Bool, send: @escaping () -> Void, stop: @escaping () -> Void, loadEarlier: (() -> Void)? = nil) {
        self.init(messages: messages, streams: streams, activity: activity, error: error,
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
