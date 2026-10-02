@_exported import MessagesCore
import SwiftUI

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
