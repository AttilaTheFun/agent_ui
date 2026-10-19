import SwiftUI

extension View {
    /// A pane beside the detail: the split view's inspector, except on a
    /// phone, where a sheet does what the inspector would (an inspector on
    /// a collapsed split view does not present).
    @ViewBuilder public func adaptiveInspector<Pane: View>(isPresented: Binding<Bool>, compact: Bool,
                                                         @ViewBuilder pane: @escaping () -> Pane) -> some View {
        if compact {
            sheet(isPresented: isPresented, content: pane)
        } else {
            // A width of its own: SwiftUI's default came out a few points
            // different from one launch to the next (the Mac's pictures of
            // the same screen differed).
            inspector(isPresented: isPresented) { pane().inspectorColumnWidth(min: 260, ideal: 300, max: 420) }
        }
    }
}
