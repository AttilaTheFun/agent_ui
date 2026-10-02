import SwiftUI

private struct MessagesThemeKey: EnvironmentKey {
    static let defaultValue = MessagesTheme()
}

extension EnvironmentValues {
    public var messagesTheme: MessagesTheme {
        get { self[MessagesThemeKey.self] }
        set { self[MessagesThemeKey.self] = newValue }
    }
}
