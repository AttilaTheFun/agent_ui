import SwiftUI

/// A renderer for `MessageContent.custom`: the app's own message kinds.
/// Returns nil to fall back to a plain caption of the kind.
public typealias MessageContentRenderer = @Sendable (_ kind: String, _ payload: String, _ isMine: Bool) -> AnyView?
