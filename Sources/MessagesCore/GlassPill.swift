import SwiftUI

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
