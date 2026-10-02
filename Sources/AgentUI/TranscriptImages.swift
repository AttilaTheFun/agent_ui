import SwiftUI
#if canImport(AppKit) || canImport(UIKit)
import Foundation
#endif

/// How the transcript shows an image URL. The default is `AsyncImage`
/// (remote / blob URLs on the web); an app whose images are local files
/// installs its own loader (the iOS Playground decodes them from disk —
/// `AsyncImage` over `file://` URLs is unreliable there).
///
/// Main-actor state, like `TranscriptActions`.
@MainActor
public enum TranscriptImages {
    /// Draw the picture behind a reference, no larger than `maxEdge` on
    /// its longest side (0 for as large as it likes). The app returns it
    /// already at its own proportions: a box the size of the largest
    /// allowed picture would leave a tall screenshot floating in the
    /// middle of it, and the rounded corner clipping empty space.
    public static var render: ((String, CGFloat) -> AnyView)?
    #if canImport(AppKit) || canImport(UIKit)
    /// The bytes behind a reference, for a viewer that wants to hand the
    /// picture to a share sheet (and so to Save Image). Apple only: the
    /// portable SwiftUI has no Foundation to put them in and nowhere to
    /// share them to.
    public static var data: ((String) async -> Data?)?
    #endif
}
