import SwiftUI

/// Over the composer while the thread is read further up: how many rows came
/// in below, and a tap to go down to them. Glass on 26, like the composer's
/// box, a thin material before it.
struct NewRowsPill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(count == 1 ? "1 new message" : "\(count) new messages", systemImage: "arrow.down")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(PillGlass())
        .accessibilityIdentifier("new-rows-pill")
    }
}

/// The pill's material: the composer's, as a capsule.
private struct PillGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
