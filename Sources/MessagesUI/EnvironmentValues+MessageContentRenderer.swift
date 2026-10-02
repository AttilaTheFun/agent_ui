import SwiftUI

private struct MessageContentRendererKey: EnvironmentKey {
    static let defaultValue: MessageContentRenderer? = nil
}

extension EnvironmentValues {
    public var messageContentRenderer: MessageContentRenderer? {
        get { self[MessageContentRendererKey.self] }
        set { self[MessageContentRendererKey.self] = newValue }
    }
}
