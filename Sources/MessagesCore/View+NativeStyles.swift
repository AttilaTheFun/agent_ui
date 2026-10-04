import SwiftUI

// Native styles, shared by every product. Every button takes a platform style rather than drawing
// its own capsule: that is what gives the press-down, the glass on macOS 26
// / iOS 26, and the platform's own sizing. The 26 styles are picked behind
// an availability check, and older releases get the bordered ones; other
// SwiftUIs draw the 26 styles as their own glass.

extension View {
    /// The filled call-to-action.
    @ViewBuilder public func prominentButton() -> some View {
        if #available(macOS 26, iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// The outlined, secondary action.
    @ViewBuilder public func secondaryButton() -> some View {
        if #available(macOS 26, iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// A custom bar item's glass: toolbar buttons get it for a plain label,
    /// not for a composed one, so the pill draws its own on 26.
    @ViewBuilder public func glassCapsule() -> some View {
        if #available(macOS 26, iOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
        }
    }

    /// The soft scroll-edge effect under the bar on macOS 26 / iOS 26.
    @ViewBuilder public func softTopEdge() -> some View {
        if #available(macOS 26, iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    /// The composer as bar chrome at the bottom edge: `safeAreaBar` on 26
    /// (the glass edge treatment), `safeAreaInset` before.
    @ViewBuilder public func composerBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(macOS 26, iOS 26, *) {
            safeAreaBar(edge: .bottom, content: bar)
        } else {
            safeAreaInset(edge: .bottom, content: bar)
        }
    }
}
