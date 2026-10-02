import MessagesCore
import SwiftUI

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
