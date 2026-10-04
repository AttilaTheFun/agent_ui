import MessagesCore
import SwiftUI

/// The phone composer's send button: a 40×30 capsule, glass on 26 and a
/// plain fill elsewhere, tinted when there is something to send.
struct SendCapsule: View {
    @Environment(\.messagesTheme) private var theme
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 30)
                .background(glassOrFill)
                .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        // An arrow and nothing else: named for whoever cannot see it.
        .accessibilityLabel("Send")
    }

    private var tint: Color { enabled ? theme.accent : theme.secondaryText.opacity(0.5) }

    @ViewBuilder private var glassOrFill: some View {
        if #available(macOS 26, iOS 26, *) {
            Color.clear.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
        } else {
            tint
        }
    }
}
