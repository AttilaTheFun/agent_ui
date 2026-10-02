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
            inspector(isPresented: isPresented, content: pane)
        }
    }
}
