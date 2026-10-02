import SwiftUI

/// What the app adds to the composer: a leading control (the + of
/// Messages), a trailing one, both optional. Everything else — the
/// field, the send button, the geometry — is the composer's.
public struct ComposerAccessories<Leading: View, Trailing: View> {
    let leading: Leading
    let trailing: Trailing

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }
}

extension ComposerAccessories where Leading == EmptyView, Trailing == EmptyView {
    public static var none: ComposerAccessories { .init(leading: { EmptyView() }, trailing: { EmptyView() }) }
}
