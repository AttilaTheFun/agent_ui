import SwiftUI

// The agent's composer, in the Claude app's shape: one rounded box holding
// the attachments picked for the next message, a growing text field, and a
// row with the app's controls (attach, model, effort…) on the left and send
// — or stop, while the agent works — on the right. Liquid Glass on iOS 26 /
// macOS 26, a material box before and on other SwiftUIs.

/// A way to finish what is being typed, offered above the field: a slash
/// command, for one. Picking it puts `text` in the draft.
public struct AgentSuggestion: Identifiable, Equatable, Sendable {
    public var id: String { text }
    /// What the draft becomes ("/compact ").
    public var text: String
    /// What the row says ("/compact").
    public var title: String
    /// One line on what it does.
    public var detail: String

    public init(text: String, title: String, detail: String = "") {
        self.text = text
        self.title = title
        self.detail = detail
    }
}

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
                            .lineLimit(1...10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .allowsHitTesting(false)
                    }
                    TextField(sendingWords == nil ? placeholder : "", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focused($focused)
                        .id(fieldGeneration)
                        .onSubmit { if canSend { fire(send) } }
                        // Return sends; Shift-Return is a newline. Where keys
                        // can be read (a Mac, a hardware keyboard on a phone),
                        // both are decided here and the field sees neither;
                        // elsewhere the submit above is what sends.
                        .returnSendsShiftReturnBreaks(draft: $draft) { if canSend { fire(send) } }
                }
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

public enum AgentComposerMetrics {
    /// Every control along the composer's bottom row stands the same
    /// height — the capsules on the left, the round send button on the
    /// right, and anything an app puts between them — so the row reads as
    /// one line of controls rather than a jumble of sizes. A control that
    /// is a circle is this across as well.
    public static let controlHeight: CGFloat = 36
    /// The one gap in the composer: from the box's edges, between the
    /// controls, and between them and the message. The space between the
    /// last control and the send button is the exception — it is whatever
    /// is left.
    public static let gap: CGFloat = 8
    /// What the message itself sits in from: the box's top and sides, and
    /// the row of controls below it. Wider than `gap`, because a line of
    /// text wants more air around it than a capsule does.
    public static let textInset: CGFloat = 12
    /// The message's own padding, on top of the box's: together they make
    /// `textInset`.
    static var inner: CGFloat { textInset - gap }
    /// The send button's fill.
    public static let sendTint = Color.indigo
    /// Stopping wears the same colour: it is the same button, saying what
    /// it can do now.
    public static let stopTint = Color.indigo
}

/// The composer's box: a 24pt rounded rectangle, Liquid Glass on 26.
struct AgentGlassBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // The bar buttons' material everywhere: glass where there is glass,
        // a thin material before it. The portable SwiftUI draws both, as a
        // frosted tint on the web and a translucent one on Android.
        if #available(iOS 26, macOS 26, *) {
            content().glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else {
            content().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

extension View {
    /// The composer's round action button (send, stop). Drawn rather than
    /// styled: a system button's circle sits inside the frame it is given
    /// by an amount only it knows, which left the send button smaller than
    /// the gauge beside it and shy of the corner. A filled circle of our
    /// own is exactly `controlHeight` across and exactly where it is put.
    public func agentCircleButton(tint: Color = AgentComposerMetrics.sendTint) -> some View {
        buttonStyle(.plain)
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(width: AgentComposerMetrics.controlHeight, height: AgentComposerMetrics.controlHeight)
            .background(Circle().fill(tint))
            .contentShape(Circle())
    }

    /// A composer control that is a drawing of its own — a gauge, an
    /// avatar — and wants no chrome under it: the same circle as the send
    /// button, and nothing behind it.
    public func agentBareCircleButton() -> some View {
        buttonStyle(.plain)
            .frame(width: AgentComposerMetrics.controlHeight, height: AgentComposerMetrics.controlHeight)
            .contentShape(Circle())
    }

    /// A composer pill (the model, the effort, a mode): a solid tinted
    /// capsule, which reads against the glass box where glass-on-glass all
    /// but disappears.
    public func agentPillButton() -> some View {
        buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            // The row's one height, so a capsule and the round button
            // beside it line up top and bottom.
            .frame(height: AgentComposerMetrics.controlHeight)
            .background(Capsule().fill(Color.primary.opacity(0.1)))
    }

    /// A composer's small round control (attach): a solid tinted circle.
    public func agentSoftCircleButton() -> some View {
        buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .frame(width: AgentComposerMetrics.controlHeight, height: AgentComposerMetrics.controlHeight)
            .background(Circle().fill(Color.primary.opacity(0.1)))
    }
}

/// A pill's label: a title with the up/down chevron of a picker.
public struct AgentPillLabel: View {
    let title: String

    public init(_ title: String) { self.title = title }

    public var body: some View {
        HStack(spacing: 4) {
            Text(title).lineLimit(1)
            Image(systemName: "chevron.up.chevron.down").font(.caption2)
        }
    }
}

/// An attachment thumbnail with its remove button, for the composer's strip.
public struct AgentAttachmentTile<Thumbnail: View>: View {
    let remove: () -> Void
    let thumbnail: Thumbnail

    public init(remove: @escaping () -> Void, @ViewBuilder thumbnail: () -> Thumbnail) {
        self.remove = remove
        self.thumbnail = thumbnail()
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .removeGlyphStyle()
            }
            .buttonStyle(.plain)
            .padding(3)
        }
    }
}

/// Text helpers without Foundation (which not every SwiftUI's host has).
public enum AgentText {
    public static func isBlank(_ text: String) -> Bool {
        text.allSatisfy { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" }
    }

    public static func trimmed(_ text: String) -> String {
        var scalars = Substring(text)
        while let first = scalars.first, first.isWhitespace || first.isNewline { scalars = scalars.dropFirst() }
        while let last = scalars.last, last.isWhitespace || last.isNewline { scalars = scalars.dropLast() }
        return String(scalars)
    }
}

extension View {
    /// The remove glyph's white-on-dark palette (the two-colour
    /// `foregroundStyle` is Apple's SwiftUI only).
    func removeGlyphStyle() -> some View {
        foregroundStyle(.white, .black.opacity(0.6))
    }
}

extension View {
    /// Return sends and Shift-Return inserts a newline, on the platforms
    /// whose SwiftUI reports key presses.
    @ViewBuilder func returnSendsShiftReturnBreaks(draft: Binding<String>, send: @escaping () -> Void) -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        self.onKeyPress(.return, phases: .down) { press in
            if press.modifiers.contains(.shift) {
                draft.wrappedValue += "\n"
            } else {
                send()
            }
            return .handled
        }
        #else
        self
        #endif
    }
}

/// The suggestions above the field: a few rows, the rest a scroll away.
struct SuggestionList: View {
    let suggestions: [AgentSuggestion]
    let pick: (AgentSuggestion) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button { pick(suggestion) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.callout.monospaced().weight(.medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if !suggestion.detail.isEmpty {
                                Text(suggestion.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AgentComposerMetrics.inner)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggestion-" + suggestion.title)
                }
            }
        }
        // Up to about five rows before it scrolls.
        .frame(maxHeight: min(CGFloat(suggestions.count) * 46, 230))
        .scrollBounceBehavior(.basedOnSize)
    }
}
