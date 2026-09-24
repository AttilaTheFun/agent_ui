import SwiftUI

/// An inspector pane's frame (Messages' details, Visor's connection form): a NavigationStack with the X at the leading
/// end of its bar, around whatever the app puts inside. On macOS the X's
/// item stays in the window's toolbar, hidden while the pane is closed —
/// any change to the toolbar's item set crossfades the other items — so
/// keep this mounted and drive `isPresented`.
public struct InspectorView<Content: View>: View {
    let isPresented: Bool
    let close: () -> Void
    let content: Content

    public init(isPresented: Bool, close: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isPresented = isPresented
        self.close = close
        self.content = content()
    }

    public var body: some View {
        NavigationStack {
            content
                .toolbar {
                    #if canImport(AppKit)
                    if #available(macOS 15, *) {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark", action: close)
                        }
                        .hidden(!isPresented)
                    } else {
                        ToolbarItem(placement: .cancellationAction) {
                            if isPresented {
                                Button("Close", systemImage: "xmark", action: close)
                            } else {
                                Color.clear.frame(width: 0, height: 0)
                            }
                        }
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark", action: close)
                    }
                    #endif
                }
        }
        .inspectorColumnWidth(300)
    }
}

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
