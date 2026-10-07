import SwiftUI

extension View {
    /// A pane beside the detail: the split view's inspector, except on a
    /// phone, where a sheet does what the inspector would (an inspector on
    /// a collapsed split view does not present), and on a TV, which has
    /// no inspector.
    @ViewBuilder public func adaptiveInspector<Pane: View>(isPresented: Binding<Bool>, compact: Bool,
                                                         @ViewBuilder pane: @escaping () -> Pane) -> some View {
        #if os(tvOS)
        sheet(isPresented: isPresented, content: pane)
        #else
        if compact {
            sheet(isPresented: isPresented, content: pane)
        } else {
            inspector(isPresented: isPresented, content: pane)
        }
        #endif
    }
}
