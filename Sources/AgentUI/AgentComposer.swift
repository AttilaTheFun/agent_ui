import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    let controls: Controls
    let attachments: Attachments
    @FocusState private var focused: Bool
    /// Bumped after a send. Apple's multi-line field goes on showing what
    /// the app cleared out from under it while it has focus, so it is
    /// given a new identity and made to read the binding again.
    @State private var fieldGeneration = 0

    /// - Parameters:
    ///   - busy: the agent is working; the send button becomes a stop button.
    ///   - attachmentCount: how many attachments `attachments` shows.
    ///   - controls: the buttons and pills beside the send button.
    ///   - attachments: the thumbnails above the field.
    public init(draft: Binding<String>, placeholder: String = "Message the agent…", busy: Bool,
                attachmentCount: Int = 0, send: @escaping () -> Void, stop: @escaping () -> Void,
                steer: (() -> Void)? = nil,
                @ViewBuilder controls: () -> Controls, @ViewBuilder attachments: () -> Attachments) {
        self._draft = draft
        self.placeholder = placeholder
        self.busy = busy
        self.attachmentCount = attachmentCount
        self.send = send
        self.stop = stop
        self.steer = steer
        self.controls = controls()
        self.attachments = attachments()
    }

    private var canSend: Bool { !AgentText.isBlank(draft) || attachmentCount > 0 }

    /// Sends, then makes sure the field shows what the app now holds.
    /// Apple's `TextField(axis: .vertical)` keeps drawing the text it had
    /// when it is focused, so the message stayed in the box and the box
    /// stayed tall after it had gone. A fresh identity reads the binding
    /// again; focus is put straight back so the keyboard does not flinch.
    private func fire(_ action: () -> Void) {
        action()
        guard draft.isEmpty else { return }
        fieldGeneration &+= 1
        focused = true
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
                if attachmentCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AgentComposerMetrics.gap) { attachments }
                            .padding(.horizontal, AgentComposerMetrics.inner)
                    }
                    .padding(.bottom, AgentComposerMetrics.gap)
                }
                TextField(placeholder, text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AgentComposerMetrics.inner)
                    .padding(.top, AgentComposerMetrics.inner)
                    .padding(.bottom, AgentComposerMetrics.textInset)
                    .focused($focused)
                    .id(fieldGeneration)
                    .onSubmit { if canSend { fire(send) } }
                    // Return sends; Shift-Return is a newline. Where keys
                    // can be read (a Mac, a hardware keyboard on a phone),
                    // both are decided here and the field sees neither;
                    // elsewhere the submit above is what sends.
                    .returnSendsShiftReturnBreaks(draft: $draft) { if canSend { fire(send) } }
                HStack(spacing: AgentComposerMetrics.gap) {
                    controls
                    // The one flexible gap: everything else is `gap`.
                    Spacer(minLength: AgentComposerMetrics.gap)
                    if busy, canSend, let steer {
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(iOS 26, macOS 26, *) {
            content().glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else {
            content().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        #else
        // No glass on the portable SwiftUI: a translucent panel in the
        // scheme's tone with a hairline, so the messages behind it show
        // through as they do under glass.
        content()
            .background(RoundedRectangle(cornerRadius: 24)
                .fill(scheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14).opacity(0.72) : Color(red: 0.96, green: 0.96, blue: 0.97).opacity(0.72)))
            .background(RoundedRectangle(cornerRadius: 24)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1))
        #endif
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
    @ViewBuilder func removeGlyphStyle() -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        foregroundStyle(.white, .black.opacity(0.6))
        #else
        foregroundColor(.white)
        #endif
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
