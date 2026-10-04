import SwiftUI

extension View {
    /// The soft scroll edge under the navigation bar: what scrolls under
    /// it fades out, with no band or line where the bar ends. A
    /// conversation's, as Messages has it.
    @ViewBuilder func softTopEdge() -> some View {
        if #available(iOS 26, macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    /// The hard scroll edge: a band under the bar, with a line where it
    /// ends. A list of conversations', as Messages has it.
    @ViewBuilder func hardTopEdge() -> some View {
        if #available(iOS 26, macOS 26, *) {
            scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }
}
