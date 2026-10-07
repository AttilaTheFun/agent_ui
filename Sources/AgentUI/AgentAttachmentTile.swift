import SwiftUI

/// An attachment thumbnail with its remove button, for the composer's
/// strip; tapped, it opens what it holds (`open`), where the app shows
/// attachments whole.
public struct AgentAttachmentTile<Thumbnail: View>: View {
    let remove: () -> Void
    let open: (() -> Void)?
    let thumbnail: Thumbnail

    public init(remove: @escaping () -> Void, open: (() -> Void)? = nil, @ViewBuilder thumbnail: () -> Thumbnail) {
        self.remove = remove
        self.open = open
        self.thumbnail = thumbnail()
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let open {
                    Button(action: open) { picture }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open the attachment")
                } else {
                    picture
                }
            }
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .removeGlyphStyle()
            }
            .buttonStyle(.plain)
            .padding(3)
        }
    }

    private var picture: some View {
        thumbnail
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
