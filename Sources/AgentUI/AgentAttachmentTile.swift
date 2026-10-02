import SwiftUI

/// An attachment thumbnail with its remove button, for the composer's strip.
public struct AgentAttachmentTile<Thumbnail: View>: View {
    let remove: () -> Void
    let thumbnail: Thumbnail

    public init(remove: @escaping () -> Void, @ViewBuilder thumbnail: () -> Thumbnail) {
        self.remove = remove
        self.thumbnail = thumbnail()
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .removeGlyphStyle()
            }
            .buttonStyle(.plain)
            .padding(3)
        }
    }
}
