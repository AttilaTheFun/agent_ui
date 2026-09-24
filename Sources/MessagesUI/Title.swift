import MessagesCore
import SwiftUI

/// Messages' title: the avatar in front, its top level with the bar's other
/// buttons, overlapping by 5pt a glass pill (name, compact chevron) that
/// hangs below the bar. 60pt on a phone, 40pt on the Mac. In a bar the
/// item is taller than the bar, which centres it, so the phone's is
/// shifted down by half the excess to put the avatar's top where the
/// buttons' tops are.
public struct ConversationTitle: View {
    @Environment(\.messagesTheme) private var theme
    let name: String
    let avatar: AvatarSource
    let presence: Presence

    public init(name: String, avatar: AvatarSource? = nil, presence: Presence = .hidden) {
        self.name = name
        self.avatar = avatar ?? .initial(name)
        self.presence = presence
    }

    public static let macAvatar: CGFloat = 40
    public static let overlap: CGFloat = 5
    public static let pillHeight: CGFloat = 27
    /// How far the pill hangs below the Mac's 52pt toolbar when the
    /// avatar's top sits 8pt below the window's top, level with the bar's
    /// buttons: the part of the title that is a titlebar accessory's own band.
    public static let macHang: CGFloat = 8 + macAvatar - overlap + pillHeight - 52

    private var avatarSize: CGFloat { MessagesPlatform.isMac ? Self.macAvatar : 60 }
    private let barHeight: CGFloat = 44

    public var body: some View {
        if MessagesPlatform.isMac {
            stack
        } else {
            stack.offset(y: (avatarSize - Self.overlap + Self.pillHeight - barHeight) / 2)
        }
    }

    private var stack: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(theme.text)
                Image(systemName: "chevron.compact.forward")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .glassCapsule()
            .padding(.top, avatarSize - Self.overlap)
            Avatar(avatar, size: avatarSize, presence: presence)
        }
    }
}
