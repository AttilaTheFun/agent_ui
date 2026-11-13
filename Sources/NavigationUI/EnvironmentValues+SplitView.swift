import SwiftUI

private struct SplitViewColumnsSideBySideKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether a `SplitView`'s columns show side by side (a Mac, an iPad in
    /// a wide window), or are collapsed into a stack (an iPhone, a narrow
    /// iPad window), where choosing a row pushes its detail. Set by
    /// `SplitView` for its columns: an app reads it in place of asking which
    /// platform it is on.
    public var splitViewColumnsSideBySide: Bool {
        get { self[SplitViewColumnsSideBySideKey.self] }
        set { self[SplitViewColumnsSideBySideKey.self] = newValue }
    }
}
