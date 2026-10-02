import SwiftUI

// Native styles, shared by every product. Every button takes a platform style rather than drawing
// its own capsule: that is what gives the press-down, the glass on macOS 26
// / iOS 26, and the platform's own sizing. The 26 styles are picked behind
// an availability check; older releases and other SwiftUIs get the
// bordered ones.

extension View {
    /// The filled call-to-action.
    @ViewBuilder public func prominentButton() -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
        #else
        buttonStyle(.borderedProminent)
        #endif
    }

    /// The outlined, secondary action.
    @ViewBuilder public func secondaryButton() -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
        #else
        buttonStyle(.bordered)
        #endif
    }

    /// A custom bar item's glass: toolbar buttons get it for a plain label,
    /// not for a composed one, so the pill draws its own on 26.
    @ViewBuilder public func glassCapsule() -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
        }
        #else
        // No glass on the portable SwiftUI: a translucent capsule stands in.
        self.background(Capsule().fill(Color.gray.opacity(0.18)))
        #endif
    }

    /// The soft scroll-edge effect under the bar on macOS 26 / iOS 26.
    @ViewBuilder public func softTopEdge() -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// The composer as bar chrome at the bottom edge: `safeAreaBar` on 26
    /// (the glass edge treatment), `safeAreaInset` before and elsewhere.
    @ViewBuilder public func composerBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
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

/// Messages' composer pill: Liquid Glass where the OS has it, a translucent
/// rounded rect with a hairline everywhere else.
public struct GlassPill<C: View>: View {
    @Environment(\.messagesTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    let content: C

    public init(content: C) { self.content = content }

    public var body: some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 19))
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }

    /// No glass on the portable SwiftUI: a near-opaque panel in the
    /// scheme's tone with a hairline, so the pill reads over the messages
    /// scrolling behind it (the same panel AgentUI's box draws).
    private var fallback: some View {
        content
            .background(RoundedRectangle(cornerRadius: 19)
                .fill(scheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14).opacity(0.94) : Color(red: 0.96, green: 0.96, blue: 0.97).opacity(0.94)))
            .background(RoundedRectangle(cornerRadius: 19).stroke(theme.inputBorder, lineWidth: 1))
    }
}
