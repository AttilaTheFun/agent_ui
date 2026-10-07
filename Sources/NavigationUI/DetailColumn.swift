import SwiftUI

/// The detail column's container: Apple's SwiftUI gives the column its bar
/// (a nested stack strips it on a collapsed phone and squeezes the Mac's
/// sidebar); a TV's, and other SwiftUIs', give a column a bar only inside
/// a stack (a TV's bare column draws the title over the content).
struct DetailColumn<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if (canImport(UIKit) || canImport(AppKit)) && !os(tvOS)
        content()
        #else
        NavigationStack { content() }
        #endif
    }
}
