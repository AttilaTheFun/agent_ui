import SwiftUI

/// The detail column's container: Apple's SwiftUI gives the column its bar
/// (a nested stack strips it on a collapsed phone and squeezes the Mac's
/// sidebar); other SwiftUIs give a column a bar only inside a stack.
struct DetailColumn<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if canImport(UIKit) || canImport(AppKit)
        content()
        #else
        NavigationStack { content() }
        #endif
    }
}
