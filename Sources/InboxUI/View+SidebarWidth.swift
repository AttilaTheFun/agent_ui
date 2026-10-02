import SwiftUI

extension View {
    /// Messages' sidebar is wide enough for a name, a time and a two-line
    /// preview; SwiftUI's default sidebar is not. Applied directly, not
    /// through a `@ViewBuilder` branch, or the preference never reaches
    /// the split view. A range, not equal bounds: a fixed sidebar with an
    /// inspector over-constrained the window.
    public func sidebarWidth() -> some View {
        navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
    }
}
