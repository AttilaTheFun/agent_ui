import SwiftUI

extension View {
    /// The composer at the bottom edge, as an inset: the thread scrolls
    /// under it and rests above it. Not `safeAreaBar`: on iOS 26 and 27 a
    /// scroll view with a safe-area bar, on any edge, takes the long press
    /// that selects text, so no message could be copied from (checked in a
    /// scratch app: the same list selects with an inset and not with a
    /// bar, whatever the bar holds and whatever its edge effect).
    public func agentComposerBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0, content: bar)
    }
}
