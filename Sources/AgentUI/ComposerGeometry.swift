import SwiftUI

/// Where the composer's box is in the window, as its last layout put it:
/// how much room the suggestions' menu has above it. A reference SwiftUI
/// doesn't watch, so the layout writing it invalidates nothing. Held in
/// `@State` it was a write in every layout pass, and on a Mac with an
/// inspector beside the chat the pass that wrote it asked for another
/// (Visor's Mac proof spinning at 100% CPU, 10 Nov 2026). The menu reads it
/// when typing shows it.
@MainActor
final class ComposerGeometry {
    var roomAbove: CGFloat = 400
}
