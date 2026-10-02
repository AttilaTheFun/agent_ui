import SwiftUI

extension View {
    /// Runs `action` when the height the scroll view shows its content in
    /// changes (its frame, or its insets from the keyboard and the bars).
    /// The portable SwiftUI keeps its own offset.
    @ViewBuilder func onVisibleHeightChange(_ action: @escaping () -> Void) -> some View {
        #if canImport(UIKit) || canImport(AppKit)
        self.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
        } action: { old, new in
            if old != new { action() }
        }
        #else
        self
        #endif
    }

    /// Told when the scrolled content's height changes: rows measured,
    /// added or grown.
    @ViewBuilder func onContentHeightChange(_ action: @escaping () -> Void) -> some View {
        #if canImport(UIKit) || canImport(AppKit)
        self.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentSize.height
        } action: { old, new in
            if old != new { action() }
        }
        #else
        self
        #endif
    }

    /// The bottom stays put when the list or its content changes size;
    /// with `false`, the top. The portable SwiftUI keeps the offset.
    func bottomAnchoredOnResize(_ bottom: Bool = true) -> some View {
        defaultScrollAnchor(bottom ? .bottom : .top, for: .sizeChanges)
    }
}
