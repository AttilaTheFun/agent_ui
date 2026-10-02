import SwiftUI

extension View {
    /// How custom message kinds are drawn beneath this view.
    public func messageContentRenderer(_ renderer: @escaping MessageContentRenderer) -> some View {
        environment(\.messageContentRenderer, renderer)
    }
}
