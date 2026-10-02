import MessagesCore
import SwiftUI

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
