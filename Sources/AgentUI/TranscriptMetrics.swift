import SwiftUI

/// The transcript's geometry, shared with the composer: messages sit 16pt
/// from the edges; the composer sits with them while the keyboard is away
/// and pulls in when it is up, to leave room to write.
public enum TranscriptMetrics {
    public static let edgeInset: CGFloat = AgentComposerMetrics.tv ? 32 : 16
    /// The last cell of the transcript: with the last row's own 6pt below
    /// it and the composer's 8pt above the box, 32pt between the two.
    public static let bottomGap: CGFloat = 18
    /// A thread is uncomfortable to read across a large display: the
    /// messages and the composer stop here and centre in a wider column.
    /// (A TV's type is near twice a phone's, read from across a room: the
    /// column is wider in the same measure, and clear of the sidebar the
    /// TV lays over the detail's leading edge.)
    public static let maxContentWidth: CGFloat = AgentComposerMetrics.tv ? 1000 : 720
    /// A picture's corner, in the transcript and in the viewer.
    public static let imageCorner: CGFloat = 8
    /// The longest side a picture takes in the transcript.
    public static let thumbnail: CGFloat = 220

    /// The size a picture of `pixels` is drawn at under `maxEdge`: its own
    /// shape, scaled to fit, never enlarged — and never thinner than
    /// legible, however long a strip it is. The same rule sizes a reserved
    /// frame and the picture that later fills it, so nothing moves.
    public static func fitted(_ pixels: CGSize, maxEdge: CGFloat) -> CGSize? {
        guard maxEdge > 0, pixels.width > 0, pixels.height > 0 else { return nil }
        let scale = min(maxEdge / pixels.width, maxEdge / pixels.height, 1)
        let floor = min(maxEdge, 96)
        let longest = max(pixels.width, pixels.height)
        let width = max(pixels.width * scale, floor * pixels.width / longest)
        let height = max(pixels.height * scale, floor * pixels.height / longest)
        return CGSize(width: width, height: height)
    }
}
