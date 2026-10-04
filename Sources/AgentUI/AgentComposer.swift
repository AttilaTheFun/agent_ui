import SwiftUI

// The agent's composer, in the Claude app's shape: one rounded box holding
// the attachments picked for the next message, a growing text field, and a
// row with the app's controls (attach, model, effort…) on the left and send
// — or stop, while the agent works — on the right. Liquid Glass on iOS 26 /
// macOS 26, a material box before and on other SwiftUIs.

/// The composer's leading controls and the attachment strip are the app's:
/// what an attachment is (a photo, a file, a screenshot) and how it is
/// picked differ per app; the composer only lays them out.
public struct AgentComposer<Controls: View, Attachments: View>: View {
    @Binding var draft: String
    let placeholder: String
    let busy: Bool
    /// How many attachments the strip holds; none hides the strip.
    let attachmentCount: Int
    let send: () -> Void
    let stop: () -> Void
    /// Say this now, ahead of the turn in flight: the app interrupts and
    /// hands it over. Without one, a busy composer only stops.
    let steer: (() -> Void)?
    /// A message sent is not on the record yet: the send button shows a
    /// spinner and says so until it is.
    let sending: Bool
    let controls: Controls
    let attachments: Attachments
    /// Ways to finish a draft, shown above the field while there are any.
    let suggest: (String) -> [AgentSuggestion]
    let pick: (AgentSuggestion) -> Void
    @FocusState private var focused: Bool
    /// Bumped after a send. Apple's multi-line field goes on showing what
    /// the app cleared out from under it while it has focus, so it is
    /// given a new identity and made to read the binding again.
    @State private var fieldGeneration = 0
    /// The words just sent, shown in the box, faint, while they are on
    /// their way.
    @State private var sentWords: String?
    /// The words last handed to the app, until the field sees whether the
    /// app cleared the draft for them (sent them) or kept it.
    @State private var handedOver: String?

    /// - Parameters:
    ///   - busy: the agent is working; the send button becomes a stop button.
    ///   - attachmentCount: how many attachments `attachments` shows.
    ///   - sending: a message sent is not on the record yet.
    ///   - controls: the buttons and pills beside the send button.
    ///   - attachments: the thumbnails above the field.
    ///   - suggestions: ways to finish a draft (slash commands), listed
    ///     above the field; `pick` is told which was tapped. Asked as the
    ///     draft changes, by the view that shows them.
    public init(draft: Binding<String>, placeholder: String = "Message the agent…", busy: Bool,
                attachmentCount: Int = 0, send: @escaping () -> Void, stop: @escaping () -> Void,
                steer: (() -> Void)? = nil, sending: Bool = false,
                suggestions: @escaping (String) -> [AgentSuggestion] = { _ in [] }, pick: @escaping (AgentSuggestion) -> Void = { _ in },
                @ViewBuilder controls: () -> Controls, @ViewBuilder attachments: () -> Attachments) {
        self.suggest = suggestions
        self.pick = pick
        self._draft = draft
        self.placeholder = placeholder
        self.busy = busy
        self.attachmentCount = attachmentCount
        self.send = send
        self.stop = stop
        self.steer = steer
        self.sending = sending
        self.controls = controls()
        self.attachments = attachments()
    }

    /// Hands `words` to the app. The composer's body does not read the
    /// draft (typing redraws the field and the send button alone), so
    /// what it would read here is the draft of its last redraw: the words
    /// come from the view that sent them, and whether the app took them
    /// is seen by the field, which reads the draft (`settle`).
    private func fire(_ action: () -> Void, words: String) {
        handedOver = words
        action()
    }

    /// The draft changed after a hand-over. Cleared, the words were sent:
    /// the keyboard stays up and the field keeps focus, to write the next
    /// message. Apple's multi-line field can go on drawing the words just
    /// sent while it is focused, and a phone's keyboard can hand them back
    /// (a pending autocorrection) just after the app has cleared the
    /// draft. So the draft is then set to a space and then to nothing: two
    /// real changes, each pushed into the field it has, which keeps its
    /// focus and the keyboard. (A new field would read the draft too, but
    /// takes the keyboard down.) On a Mac, where there is no keyboard to
    /// lose, the field is renewed. Kept, nothing was sent: leave it.
    private func settle(cleared: Bool) {
        guard let words = handedOver else { return }
        handedOver = nil
        guard cleared else { return }
        // Shown in the box until the message is on the record, and gone
        // from it as the message arrives in the thread.
        if !AgentText.isBlank(words) { sentWords = AgentText.trimmed(words) }
        #if os(macOS)
        fieldGeneration &+= 1
        focused = true
        #else
        Task { @MainActor in
            await Task.yield()
            draft = " "
            await Task.yield()
            draft = ""
        }
        #endif
    }

    public var body: some View {
        Group {
            if #available(iOS 26, macOS 26, *) {
                GlassEffectContainer(spacing: 10) { box }
            } else {
                box
            }
        }
        // One inset, whatever the keyboard is doing: the bar is attached
        // with `safeAreaInset(edge: .bottom)`, and SwiftUI moves the safe
        // area itself when a keyboard comes up. Watching UIKit's
        // notifications to nudge the padding bought a Messages-like
        // shuffle at the cost of the only keyboard-aware code in the app.
        .padding(.horizontal, TranscriptMetrics.edgeInset)
        // The room between the last message and the box is the transcript's
        // last cell (TranscriptMetrics.bottomGap), not padding here, so it
        // scrolls with the thread.
        .padding(.top, 8)
        .padding(.bottom, 12)
        // The composer lines up with the messages above it.
        .frame(maxWidth: TranscriptMetrics.maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var box: some View {
        AgentGlassBox {
            // Spacing by hand: the message keeps `textInset` from the box
            // and from the controls, while the controls keep `gap`. The
            // row of controls carries its own room to the box's edge and
            // to the message (`controlsRoom`), so the send button can take
            // taps in it.
            VStack(alignment: .leading, spacing: 0) {
                ComposerSuggestions(draft: $draft, suggest: suggest, pick: pick)
                if attachmentCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AgentComposerMetrics.gap) { attachments }
                            .padding(.horizontal, AgentComposerMetrics.inner)
                    }
                    .padding(.bottom, AgentComposerMetrics.gap)
                    .padding(.trailing, AgentComposerMetrics.gap)
                }
                ComposerField(draft: $draft, placeholder: placeholder, sentWords: sentWords, sending: sending, focused: $focused,
                              generation: fieldGeneration, attachmentCount: attachmentCount, handedOver: handedOver != nil,
                              submit: { fire(send, words: $0) }, settle: settle)
                .padding(.horizontal, AgentComposerMetrics.inner)
                .padding(.top, AgentComposerMetrics.inner)
                .padding(.trailing, AgentComposerMetrics.gap)
                HStack(spacing: AgentComposerMetrics.gap) {
                    controls
                        .padding(.top, AgentComposerMetrics.controlsRoom.top)
                        .padding(.bottom, AgentComposerMetrics.controlsRoom.bottom)
                    // The one flexible gap: everything else is `gap`.
                    Spacer(minLength: AgentComposerMetrics.gap)
                    #if canImport(AppKit) || canImport(UIKit)
                    // Escape stops the agent, as it does in its terminal,
                    // whatever the button shows (a message on its way, too).
                    if busy {
                        Button("Stop", action: stop)
                            .keyboardShortcut(.escape, modifiers: [])
                            .opacity(0)
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                    #endif
                    ComposerSendButton(draft: $draft, busy: busy, sending: sending, attachmentCount: attachmentCount,
                                       send: { fire(send, words: $0) }, steer: steer.map { steer in { fire(steer, words: $0) } },
                                       stop: stop)
                }
            }
            .padding(.top, AgentComposerMetrics.gap)
            .padding(.leading, AgentComposerMetrics.gap)
            // On the record: the words leave the box as the message
            // arrives in the thread, the same update.
            .onChange(of: sending) { _, now in if !now { sentWords = nil } }
        }
    }
}

extension AgentComposer where Controls == EmptyView, Attachments == EmptyView {
    public init(draft: Binding<String>, placeholder: String = "Message the agent…", busy: Bool,
                send: @escaping () -> Void, stop: @escaping () -> Void) {
        self.init(draft: draft, placeholder: placeholder, busy: busy, send: send, stop: stop,
                  controls: { EmptyView() }, attachments: { EmptyView() })
    }
}
