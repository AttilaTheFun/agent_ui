import MessagesCore
import SwiftUI

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
