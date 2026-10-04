import SwiftUI

extension View {
    /// The soft scroll edge under the navigation bar: what scrolls under
    /// it fades out, with no band or line where the bar ends.
    @ViewBuilder func softTopEdge() -> some View {
        if #available(iOS 26, macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}
