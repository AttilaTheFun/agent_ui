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
