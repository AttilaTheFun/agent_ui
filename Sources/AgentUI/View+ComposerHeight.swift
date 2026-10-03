import SwiftUI

extension View {
    /// Runs `action` when the composer below the thread changes height, on
    /// a Mac. Elsewhere the change reaches the scroll view as a change in
    /// its visible height (`onVisibleHeightChange`), which already keeps
    /// the bottom in view; doing it twice there would fight the send's own
    /// scroll.
    @ViewBuilder func onComposerHeightChange(_ height: CGFloat, _ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onChange(of: height) { old, new in
            if old > 0, old != new { action() }
        }
        #else
        self
        #endif
    }
}
