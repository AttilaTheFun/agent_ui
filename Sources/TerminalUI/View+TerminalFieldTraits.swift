import SwiftUI

extension View {
    /// A field for a terminal's typing: no capital letter put in at the
    /// start of a line, where the keyboard would. (The Mac's SwiftUI has no
    /// such setting: its keyboard puts in none.)
    @ViewBuilder func terminalFieldTraits() -> some View {
        #if os(macOS)
        self
        #else
        textInputAutocapitalization(.never)
        #endif
    }
}
