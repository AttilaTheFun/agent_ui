import SwiftUI

extension View {
    /// The composer as bar chrome at the bottom edge: `safeAreaBar` on 26
    /// (the glass edge treatment), `safeAreaInset` before and elsewhere.
    @ViewBuilder public func agentComposerBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            safeAreaBar(edge: .bottom, content: bar)
        } else {
            safeAreaInset(edge: .bottom, content: bar)
        }
        #else
        safeAreaInset(edge: .bottom, content: bar)
        #endif
    }
}
