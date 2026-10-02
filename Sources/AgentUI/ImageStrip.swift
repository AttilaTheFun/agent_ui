import SwiftUI

/// Thumbnails of a message's images (screenshots, attached mocks), on
/// the side its message is on: yours right, the agent's left. Tap one to
/// see it whole.
public struct ImageStrip: View {
    let urls: [String]
    let sizes: [CGSize?]
    let alignment: HorizontalAlignment
    @Environment(\.openedTranscriptImage) private var opened

    public init(urls: [String], sizes: [CGSize?] = [], alignment: HorizontalAlignment = .leading) {
        self.urls = urls
        self.sizes = sizes
        self.alignment = alignment
    }

    /// The frame a picture takes before it has arrived, when its size is
    /// known: the row is its final shape from the start.
    private func reserved(_ index: Int) -> CGSize? {
        guard index < sizes.count, let pixels = sizes[index] else { return nil }
        return TranscriptMetrics.fitted(pixels, maxEdge: TranscriptMetrics.thumbnail)
    }

    public var body: some View {
        if !urls.isEmpty {
            HStack(spacing: 6) {
                if alignment == .trailing { Spacer(minLength: 0) }
                ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                    Button {
                        // Held by the thread, not here: a transcript row
                        // is rebuilt on every delta that arrives, and
                        // state inside one goes with it — which is why
                        // the viewer once opened onto nothing.
                        opened.wrappedValue = url
                    } label: {
                        TranscriptImage(url: url, maxEdge: TranscriptMetrics.thumbnail)
                            .frame(width: reserved(index)?.width, height: reserved(index)?.height)
                            .clipShape(RoundedRectangle(cornerRadius: TranscriptMetrics.imageCorner))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open the picture")
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            // The row has to be as wide as the message or the spacer has
            // nothing to push against and the pictures sit wherever they
            // happen to fall.
            .frame(maxWidth: .infinity)
        }
    }
}
