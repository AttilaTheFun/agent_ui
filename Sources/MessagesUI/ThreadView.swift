@_exported import MessagesCore
import SwiftUI

/// A renderer for `MessageContent.custom`: the app's own message kinds.
/// Returns nil to fall back to a plain caption of the kind.
public typealias MessageContentRenderer = @Sendable (_ kind: String, _ payload: String, _ isMine: Bool) -> AnyView?

private struct MessageContentRendererKey: EnvironmentKey {
    static let defaultValue: MessageContentRenderer? = nil
}

extension EnvironmentValues {
    public var messageContentRenderer: MessageContentRenderer? {
        get { self[MessageContentRendererKey.self] }
        set { self[MessageContentRendererKey.self] = newValue }
    }
}

extension View {
    /// How custom message kinds are drawn beneath this view.
    public func messageContentRenderer(_ renderer: @escaping MessageContentRenderer) -> some View {
        environment(\.messageContentRenderer, renderer)
    }
}

/// The thread: Messages' chat page. Messages scroll under the bar, the
/// composer is bar chrome at the bottom, the title is the avatar-and-pill
/// (in the bar on a phone; on the Mac the app installs it as a titlebar
/// accessory, see `MacConversationTitlebar`). Tapping the title calls
/// `onTitleTap`, which is where the app shows its details.
public struct ThreadView<Leading: View, Trailing: View>: View {
    @Environment(\.messagesTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    let conversation: ConversationSummary
    let messages: [MessageItem]
    /// What to say above an empty thread.
    let emptyText: String?
    /// A line under the messages (delivery, "they're offline"), or nothing.
    let footer: String?
    @Binding var draft: String
    let accessories: ComposerAccessories<Leading, Trailing>
    /// A long press (or secondary click) on a bubble offers these; the app
    /// gets the message and the emoji. Nil: no reactions.
    let onReact: ((MessageItem, String) -> Void)?
    let send: () -> Void
    let onTitleTap: () -> Void

    public init(conversation: ConversationSummary, messages: [MessageItem], emptyText: String? = nil,
                footer: String? = nil, draft: Binding<String>,
                accessories: ComposerAccessories<Leading, Trailing>,
                send: @escaping () -> Void, onTitleTap: @escaping () -> Void,
                onReact: ((MessageItem, String) -> Void)? = nil) {
        self.conversation = conversation
        self.onReact = onReact
        self.messages = messages
        self.emptyText = emptyText
        self.footer = footer
        self._draft = draft
        self.accessories = accessories
        self.send = send
        self.onTitleTap = onTitleTap
    }

    public var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if messages.isEmpty, let emptyText {
                        HStack {
                            Spacer()
                            Text(emptyText)
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding(.top, 24)
                    }
                    ForEach(messages) { message in
                        MessageView(message: message)
                            .contextMenu {
                                if let onReact {
                                    ForEach(ThreadReactions.defaults, id: \.self) { emoji in
                                        Button(emoji) { onReact(message, emoji) }
                                    }
                                }
                            }
                    }
                    if let footer {
                        HStack {
                            Spacer()
                            Text(footer)
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                // 16pt from the edges on a phone, always; the composer
                // alone moves out when the keyboard is away.
                .padding(.horizontal, ComposerMetrics.messageInset(sizeClass: sizeClass))
                .padding(.vertical, 8)
                // A thread is uncomfortable to read across a large display.
                .frame(maxWidth: ThreadMetrics.maxContentWidth)
                // At least the viewport tall, bottom-aligned: a short
                // history sits at the bottom and the bar's scroll-edge
                // treatment covers only what scrolls beneath it.
                .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .bottom)
            }
            .softTopEdge()
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .composerBar {
            MessageComposer(draft: $draft, accessories: accessories, send: send)
        }
        // The name pill is the title on a phone: it replaces the inline
        // title, with the avatar in front. On the Mac the bar's title is
        // empty; the app draws the same shape as a titlebar accessory.
        .navigationTitle(MessagesPlatform.isMac ? "" : conversation.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !MessagesPlatform.isMac {
                ToolbarItem(placement: .principal) {
                    Button(action: onTitleTap) {
                        ConversationTitle(name: conversation.name, avatar: conversation.avatar,
                                          presence: conversation.presence)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // On a phone the pill hangs below the bar, outside the bar's hit
        // region, so the content's top takes taps there for it.
        .overlay(alignment: .top) {
            if !MessagesPlatform.isMac {
                Color.clear
                    .frame(width: 240, height: 40)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTitleTap)
            }
        }
    }
}

extension ThreadView where Leading == EmptyView, Trailing == EmptyView {
    public init(conversation: ConversationSummary, messages: [MessageItem], emptyText: String? = nil,
                footer: String? = nil, draft: Binding<String>,
                send: @escaping () -> Void, onTitleTap: @escaping () -> Void,
                onReact: ((MessageItem, String) -> Void)? = nil) {
        self.init(conversation: conversation, messages: messages, emptyText: emptyText, footer: footer,
                  draft: draft, accessories: .none, send: send, onTitleTap: onTitleTap, onReact: onReact)
    }
}

/// The emojis a long press on a bubble offers, in Messages' order.
public enum ThreadReactions {
    public static let defaults = ["❤️", "👍", "👎", "😂", "‼️", "❓"]
}

/// One message (Messages' bubble): a text bubble, a picture, a clip, an album, or the app's
/// own kind. Ours on the right in the accent, theirs on the left in grey.
public struct MessageView: View {
    @Environment(\.messagesTheme) private var theme
    @Environment(\.messageContentRenderer) private var renderer
    let message: MessageItem

    public init(message: MessageItem) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 0) {
            if message.isMine { Spacer(minLength: 60) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 2) {
                content
                if !message.reactions.isEmpty { reactions }
            }
            if !message.isMine { Spacer(minLength: 60) }
        }
        .padding(.vertical, 1)
    }

    /// The reactions under the bubble: an emoji with its count in a small
    /// capsule, tinted when ours is among them.
    private var reactions: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions, id: \.emoji) { reaction in
                Text(reaction.count > 1 ? "\(reaction.emoji) \(reaction.count)" : reaction.emoji)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(reaction.mine ? theme.accent.opacity(0.18) : theme.bubbleTheirs)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private var content: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(.body)
                .foregroundColor(message.isMine ? .white : theme.text)
                // However many lines the message needs — never truncated.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(message.isMine ? theme.bubbleMine : theme.bubbleTheirs)
                .cornerRadius(18)
        case .image(let item):
            MediaTile(item: item, isVideo: false)
        case .video(let item):
            MediaTile(item: item, isVideo: true)
        case .album(let items):
            AlbumTile(items: items)
        case .custom(let kind, let payload):
            if let custom = renderer?(kind, payload, message.isMine) {
                custom
            } else {
                Text(kind)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.bubbleTheirs)
                    .cornerRadius(18)
            }
        }
    }
}

/// A picture or a clip's poster, at its aspect ratio, capped in width.
struct MediaTile: View {
    @Environment(\.messagesTheme) private var theme
    let item: MediaItem
    let isVideo: Bool

    /// Bubble-sized from the ratio: `aspectRatio(_:contentMode:)` is not
    /// in every SwiftUI, and the size is known before the bytes are.
    private var size: CGSize {
        let width: CGFloat = 260
        return CGSize(width: width, height: width / max(item.aspectRatio, 0.2))
    }

    var body: some View {
        let source = isVideo ? (item.poster ?? item.url) : item.url
        AsyncImage(url: source) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            theme.bubbleTheirs
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay {
            if isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

/// Several pictures in one bubble: a two-column grid.
struct AlbumTile: View {
    @Environment(\.messagesTheme) private var theme
    let items: [MediaItem]

    /// Two square tiles a row (a grid without LazyVGrid, which not every
    /// SwiftUI has).
    var body: some View {
        let side: CGFloat = (260 - 3) / 2
        VStack(spacing: 3) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                HStack(spacing: 3) {
                    ForEach(Array(items[start..<min(start + 2, items.count)].enumerated()), id: \.offset) { _, item in
                        AsyncImage(url: item.poster ?? item.url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            theme.bubbleTheirs
                        }
                        .frame(width: side, height: side)
                        .clipped()
                    }
                    if items.count - start == 1 { Spacer(minLength: 0) }
                }
            }
        }
        .frame(width: 260)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

/// The old name of `MessageView`.
public typealias MessageBubble = MessageView

/// How wide a thread gets before it stops growing and centres instead.
public enum ThreadMetrics {
    public static let maxContentWidth: CGFloat = 720
}
