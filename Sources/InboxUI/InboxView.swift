@_exported import MessagesCore
import SwiftUI

/// The conversation list: Messages' sidebar. Selection is the app's — a
/// binding it reads to show the thread, in whatever container it chose.
/// The bar's items are the app's too (`.toolbar` on this view); the list
/// carries none, and on the Mac should carry none of its own, so the
/// sidebar toggle is never re-laid out.
public struct InboxView<Extra: View>: View {
    let conversations: [ConversationSummary]
    @Binding var selection: String?
    let extraRows: Extra

    /// - Parameters:
    ///   - conversations: the rows, in order.
    ///   - selection: the open conversation's id.
    ///   - extraRows: rows above the conversations, tagged by the caller
    ///     (a "New Conversation" draft while composing).
    public init(conversations: [ConversationSummary], selection: Binding<String?>,
                @ViewBuilder extraRows: () -> Extra) {
        self.conversations = conversations
        self._selection = selection
        self.extraRows = extraRows()
    }

    public var body: some View {
        List(selection: $selection) {
            extraRows
            ForEach(conversations) { conversation in
                InboxCell(conversation: conversation)
                    .tag(conversation.id)
            }
        }
        // Messages: rows on the page with hairlines, not the grouped card.
        .listStyle(.plain)
        .sidebarWidth()
    }
}

extension InboxView where Extra == EmptyView {
    public init(conversations: [ConversationSummary], selection: Binding<String?>) {
        self.init(conversations: conversations, selection: selection) { EmptyView() }
    }
}

/// One inbox row: avatar, name with the time opposite, a two-line preview.
public struct InboxCell: View {
    @Environment(\.messagesTheme) private var theme
    let conversation: ConversationSummary

    public init(conversation: ConversationSummary) {
        self.conversation = conversation
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(conversation.avatar, size: 44, presence: conversation.presence)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.name)
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let time = conversation.timestamp {
                        Text(MessagesTime.label(for: time))
                            .font(.subheadline)
                            .foregroundColor(theme.secondaryText)
                    }
                }
                Text(conversation.preview)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        // The whole row is the tap target, like a List cell.
        .contentShape(Rectangle())
    }
}

extension View {
    /// Messages' sidebar is wide enough for a name, a time and a two-line
    /// preview; SwiftUI's default sidebar is not. Applied directly, not
    /// through a `@ViewBuilder` branch, or the preference never reaches
    /// the split view. A range, not equal bounds: a fixed sidebar with an
    /// inspector over-constrained the window.
    public func sidebarWidth() -> some View {
        navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
    }
}
