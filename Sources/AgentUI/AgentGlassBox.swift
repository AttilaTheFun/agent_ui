import SwiftUI

/// The composer's box: a 24pt rounded rectangle, Liquid Glass on 26.
struct AgentGlassBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // The bar buttons' material everywhere: glass where there is glass,
        // a thin material before it. The portable SwiftUI draws both, as a
        // frosted tint on the web and a translucent one on Android.
        if #available(iOS 26, macOS 26, *) {
            content().glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else {
            content().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
