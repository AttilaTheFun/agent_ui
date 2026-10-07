import SwiftUI

extension View {
    /// Text the user can select a line out of — where the system lets
    /// them: not on a TV, which has no selection.
    @ViewBuilder func selectableText() -> some View {
        #if os(tvOS)
        self
        #else
        textSelection(.enabled)
        #endif
    }

    /// A list row without its separator, where a list draws separators.
    @ViewBuilder func rowSeparatorHidden() -> some View {
        #if os(tvOS)
        self
        #else
        listRowSeparator(.hidden)
        #endif
    }
}
