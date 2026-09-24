import SwiftUI

/// A circle with an initial, a symbol or a picture, and the presence dot
/// at its lower right.
public struct Avatar: View {
    @Environment(\.messagesTheme) private var theme
    let source: AvatarSource
    let size: CGFloat
    let presence: Presence

    public init(_ source: AvatarSource, size: CGFloat, presence: Presence = .hidden) {
        self.source = source
        self.size = size
        self.presence = presence
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(theme.avatar)
                .frame(width: size, height: size)
                .overlay(glyph)
                .clipShape(Circle())
            if presence != .hidden {
                Circle()
                    .fill(dot)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
            }
        }
    }

    private var dot: Color {
        switch presence {
        case .online: theme.online
        case .idle: theme.idle
        case .offline, .hidden: theme.offline
        }
    }

    @ViewBuilder private var glyph: some View {
        switch source {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)
        case .initial(let text):
            Text(String(text.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(.white)
        case .image(let url):
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
            .frame(width: size, height: size)
        }
    }
}
