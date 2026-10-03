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
    /// Ways to finish the draft, shown above the field while there are any.
    let suggestions: [AgentSuggestion]
    let pick: (AgentSuggestion) -> Void
    @FocusState private var focused: Bool
    /// Bumped after a send. Apple's multi-line field goes on showing what
    /// the app cleared out from under it while it has focus, so it is
    /// given a new identity and made to read the binding again.
    @State private var fieldGeneration = 0
    /// Where the caret is in the field, for a Shift-Return's newline.
    @State private var selection: DraftSelection?
    /// The words just sent, shown in the box, faint, while they are on
    /// their way.
    @State private var sentWords: String?

    /// - Parameters:
    ///   - busy: the agent is working; the send button becomes a stop button.
    ///   - attachmentCount: how many attachments `attachments` shows.
    ///   - sending: a message sent is not on the record yet.
    ///   - controls: the buttons and pills beside the send button.
    ///   - attachments: the thumbnails above the field.
    ///   - suggestions: ways to finish the draft (slash commands), listed
    ///     above the field; `pick` is told which was tapped.
    public init(draft: Binding<String>, placeholder: String = "Message the agent…", busy: Bool,
                attachmentCount: Int = 0, send: @escaping () -> Void, stop: @escaping () -> Void,
                steer: (() -> Void)? = nil, sending: Bool = false,
                suggestions: [AgentSuggestion] = [], pick: @escaping (AgentSuggestion) -> Void = { _ in },
                @ViewBuilder controls: () -> Controls, @ViewBuilder attachments: () -> Attachments) {
        self.suggestions = suggestions
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

    /// The words on their way, while there is nothing new written.
    private var sendingWords: String? { sending && draft.isEmpty ? sentWords : nil }

    private var canSend: Bool { !AgentText.isBlank(draft) || attachmentCount > 0 }

    /// Sends; the keyboard stays up and the field keeps focus, to write
    /// the next message. Apple's multi-line field can go on drawing the
    /// words just sent while it is focused, and a phone's keyboard can
    /// hand them back (a pending autocorrection) just after the app has
    /// cleared the draft. So once the send has settled the draft is set
    /// to a space and then to nothing: two real changes, each pushed into
    /// the field it has, which keeps its focus and the keyboard. (A new
    /// field would read the draft too, but takes the keyboard down.) On a
    /// Mac, where there is no keyboard to lose, the field is renewed.
    private func fire(_ action: @escaping () -> Void) {
        let words = draft
        action()
        // The app kept the draft (nothing was sent): leave it.
        guard draft.isEmpty else { return }
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
            #if canImport(AppKit) || canImport(UIKit)
            if #available(iOS 26, macOS 26, *) {
                GlassEffectContainer(spacing: 10) { box }
            } else {
                box
            }
            #else
            box
            #endif
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
            // and from the controls, while the controls keep `gap`.
            VStack(alignment: .leading, spacing: 0) {
                if !suggestions.isEmpty {
                    SuggestionList(suggestions: suggestions, pick: pick)
                        .padding(.bottom, AgentComposerMetrics.gap)
                }
                if attachmentCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AgentComposerMetrics.gap) { attachments }
                            .padding(.horizontal, AgentComposerMetrics.inner)
                    }
                    .padding(.bottom, AgentComposerMetrics.gap)
                }
                // The words on their way, where they were written, until
                // something new is: laid out with the field, so the box
                // keeps their height until they leave it.
                ZStack(alignment: .topLeading) {
                    if let sendingWords {
                        Text(sendingWords)
                            .foregroundColor(.secondary)
                            .draftLineLimit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .allowsHitTesting(false)
                    }
                    DraftField(placeholder: sendingWords == nil ? placeholder : "", draft: $draft, selection: $selection)
                        .textFieldStyle(.plain)
                        .draftLineLimit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focused($focused)
                        .id(fieldGeneration)
                        .onSubmit { if canSend { fire(send) } }
                        // Return sends; Shift-Return is a newline. Where keys
                        // can be read (a Mac, a hardware keyboard on a phone),
                        // both are decided here and the field sees neither;
                        // elsewhere the submit above is what sends.
                        .returnSendsShiftReturnBreaks(draft: $draft, selection: $selection) { if canSend { fire(send) } }
                }
                .draftScroller(draft: draft, selection: selection)
                .padding(.horizontal, AgentComposerMetrics.inner)
                .padding(.top, AgentComposerMetrics.inner)
                .padding(.bottom, AgentComposerMetrics.textInset)
                HStack(spacing: AgentComposerMetrics.gap) {
                    controls
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
                    if sending {
                        // The send button, spinning until the message is
                        // on the record.
                        Button {} label: { ProgressView().controlSize(.small).tint(.white) }
                            .agentCircleButton()
                            .allowsHitTesting(false)
                            .accessibilityLabel("Sending")
                            .accessibilityIdentifier("sending")
                    } else if busy, canSend, let steer {
                        // Something written while the agent works: say it
                        // now, keep it for after, or just stop.
                        Menu {
                            Button { fire(steer) } label: { Label("Send now", systemImage: "forward.end") }
                            Button { fire(send) } label: { Label("Queue for after", systemImage: "clock") }
                            Button(role: .destructive) { stop() } label: { Label("Stop", systemImage: "stop.fill") }
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .agentCircleButton(tint: AgentComposerMetrics.stopTint)
                        .accessibilityLabel("Stop, send now, or queue")
                        .accessibilityIdentifier("busy-actions")
                    } else if busy {
                        // Nothing written: the button only stops.
                        Button(action: stop) { Image(systemName: "stop.fill") }
                            .agentCircleButton(tint: AgentComposerMetrics.stopTint)
                            .accessibilityLabel("Stop")
                    } else {
                        Button { fire(send) } label: { Image(systemName: "arrow.up") }
                            .agentCircleButton()
                            .disabled(!canSend)
                            .accessibilityLabel("Send")
                    }
                }
            }
            .padding(AgentComposerMetrics.gap)
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
