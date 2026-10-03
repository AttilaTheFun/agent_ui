import SwiftUI

extension View {
    /// A field for a terminal's typing: no capital letter put in at the
    /// start of a line, where the platform's keyboard would.
    @ViewBuilder func terminalFieldTraits() -> some View {
        #if canImport(UIKit)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}
