import SwiftUI

/// The colours. Messages' by default: blue for what we sent, grey for what
/// arrived, the semantic text colours so light and dark need no second
/// set. Replace any of them with `.messagesTheme(_:)`.
public struct MessagesTheme: Sendable {
    public var accent = Color(red: 0.04, green: 0.52, blue: 1.0)
    public var bubbleMine = Color(red: 0.04, green: 0.52, blue: 1.0)
    public var bubbleTheirs = Color.secondary.opacity(0.22)
    public var text = Color.primary
    public var secondaryText = Color.secondary
    public var inputBorder = Color.secondary.opacity(0.35)
    public var online = Color(red: 0.20, green: 0.72, blue: 0.35)
    public var idle = Color(red: 0.98, green: 0.75, blue: 0.14)
    public var offline = Color.secondary.opacity(0.5)
    /// Opaque: the avatar sits in front of the title pill.
    public var avatar = Color(red: 0.55, green: 0.57, blue: 0.60)
    public var danger = Color(red: 0.86, green: 0.22, blue: 0.20)

    public init() {}
}

private struct MessagesThemeKey: EnvironmentKey {
    static let defaultValue = MessagesTheme()
}

extension EnvironmentValues {
    public var messagesTheme: MessagesTheme {
        get { self[MessagesThemeKey.self] }
        set { self[MessagesThemeKey.self] = newValue }
    }
}

extension View {
    /// The colours for everything MessagesUI draws beneath this view.
    public func messagesTheme(_ theme: MessagesTheme) -> some View {
        environment(\.messagesTheme, theme)
    }
}
