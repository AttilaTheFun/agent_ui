import SwiftUI

/// Thumbnails of a message's attachments (screenshots, attached mocks, a
/// video, a file), on the side its message is on: yours right, the
/// agent's left; a carousel, scrolled sideways, when they are wider than
/// the message (four screenshots ran off a phone, and took the message's
/// words with them). The carousel is as wide as the thread, its pictures
/// scrolling to the screen's edges, the message's margin (`inset`) only
/// at its ends. Tap one to see it whole; it spins while its bytes are
/// fetched for that.
public struct ImageStrip: View {
    let urls: [String]
    let sizes: [CGSize?]
    let alignment: HorizontalAlignment
    /// The margin between the thread's edges and the pictures: inside
    /// the carousel's scrolling, so it does not cut them off.
    let inset: CGFloat
    @Environment(\.openedTranscriptImage) private var opened

    public init(urls: [String], sizes: [CGSize?] = [], alignment: HorizontalAlignment = .leading, inset: CGFloat = 0) {
        self.urls = urls
        self.sizes = sizes
        self.alignment = alignment
        self.inset = inset
    }

    /// The frame a picture takes before it has arrived, when its size is
    /// known: the row is its final shape from the start.
    private func reserved(_ index: Int) -> CGSize? {
        guard index < sizes.count, let pixels = sizes[index] else { return nil }
        return TranscriptMetrics.fitted(pixels, maxEdge: TranscriptMetrics.thumbnail)
    }

    public var body: some View {
        if !urls.isEmpty {
            ViewThatFits(in: .horizontal) {
                thumbnails.padding(.horizontal, inset)
                ScrollView(.horizontal, showsIndicators: false) { thumbnails.padding(.horizontal, inset) }
            }
            // As wide as the message, the pictures on its side when they
            // fit.
            .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
        }
    }

    private var thumbnails: some View {
        HStack(spacing: 6) {
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
                        .overlay {
                            if opened.wrappedValue == url {
                                ZStack {
                                    Color.black.opacity(0.3)
                                    ProgressView().tint(.white)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: TranscriptMetrics.imageCorner))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open the attachment")
                // Named for a test that opens one of several.
                .accessibilityIdentifier("attachment-" + String(url.split(separator: "/").last ?? ""))
            }
        }
    }
}
