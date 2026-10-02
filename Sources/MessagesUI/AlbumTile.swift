import MessagesCore
import SwiftUI

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
