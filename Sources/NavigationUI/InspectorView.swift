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
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark", action: close)
                    }
                    .hidden(!isPresented)
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark", action: close)
                    }
                    #endif
                }
        }
        .inspectorWidth(300)
    }
}

private extension View {
    /// The inspector's width, where there is an inspector column (a TV
    /// shows the pane as a sheet).
    @ViewBuilder func inspectorWidth(_ width: CGFloat) -> some View {
        #if os(tvOS)
        self
        #else
        inspectorColumnWidth(width)
        #endif
    }
}
