import MessagesCore
import SwiftUI

/// Messages' composer. On a phone a pill that grows upward with a 40×30
/// send capsule pinned 6pt from its bottom right corner, 16pt from the
/// keyboard and sides while typing and 24pt from the sides, flush with
/// the safe area, otherwise; on a desktop a 32pt pill where Return sends.
public struct MessageComposer<Leading: View, Trailing: View>: View {
    @Environment(\.messagesTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The field is being typed in: on a phone, the keyboard is up.
    @FocusState private var typing: Bool
    @Binding var draft: String
    let placeholder: String
    let accessories: ComposerAccessories<Leading, Trailing>
    let send: () -> Void

    public init(draft: Binding<String>, placeholder: String = "Message",
                accessories: ComposerAccessories<Leading, Trailing>, send: @escaping () -> Void) {
        self._draft = draft
        self.placeholder = placeholder
        self.accessories = accessories
        self.send = send
    }

    /// Messages' two composers: on a phone the bubble carries a send
    /// button; on a desktop Return sends and there is no button. The web
    /// is a phone when narrow, a desktop when wide.
    private var showsSendButton: Bool { ComposerMetrics.isPhoneComposer(sizeClass: sizeClass) }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            accessories.leading
            if showsSendButton { phone } else { desktop }
            accessories.trailing
        }
        .padding(.horizontal, ComposerMetrics.horizontalInset(sizeClass: sizeClass, keyboardVisible: typing))
        .padding(.top, showsSendButton ? 6 : 8)
        // A phone's composer sits on the home-indicator safe area; a browser
        // tab has none, so it keeps 8pt of its own above the edge.
        .padding(.bottom, showsSendButton ? (typing ? 16 : (MessagesPlatform.isWeb ? 8 : 0)) : 8)
        // The composer lines up with the messages above it.
        .frame(maxWidth: ThreadMetrics.maxContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var phone: some View {
        GlassPill(content:
            ZStack(alignment: .bottomTrailing) {
                TextField(placeholder, text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused($typing)
                    .frame(maxWidth: .infinity, minHeight: 18, alignment: .topLeading)
                    .padding(.leading, 14)
                    .padding(.trailing, 52)
                    .padding(.vertical, 10)
                SendCapsule(enabled: !draft.isEmpty, action: send)
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
            }
        )
        .frame(maxWidth: .infinity)
    }

    private var desktop: some View {
        GlassPill(content:
            TextField(placeholder, text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .frame(maxWidth: .infinity, minHeight: 20)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .onSubmit(send)
        )
        .frame(maxWidth: .infinity)
    }
}

extension MessageComposer where Leading == EmptyView, Trailing == EmptyView {
    public init(draft: Binding<String>, placeholder: String = "Message", send: @escaping () -> Void) {
        self.init(draft: draft, placeholder: placeholder, accessories: .none, send: send)
    }
}
