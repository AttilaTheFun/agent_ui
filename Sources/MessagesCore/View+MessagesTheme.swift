import SwiftUI

extension View {
    /// The colours for everything MessagesUI draws beneath this view.
    public func messagesTheme(_ theme: MessagesTheme) -> some View {
        environment(\.messagesTheme, theme)
    }
}
