import MessagesCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// What the app adds to the composer: a leading control (the + of
/// Messages), a trailing one, both optional. Everything else — the
/// field, the send button, the geometry — is the composer's.
public struct ComposerAccessories<Leading: View, Trailing: View> {
    let leading: Leading
    let trailing: Trailing

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }
}

extension ComposerAccessories where Leading == EmptyView, Trailing == EmptyView {
    public static var none: ComposerAccessories { .init(leading: { EmptyView() }, trailing: { EmptyView() }) }
}

/// Messages' composer. On a phone a pill that grows upward with a 40×30
/// send capsule pinned 6pt from its bottom right corner, 16pt from the
/// keyboard and sides while typing and 24pt from the sides, flush with
/// the safe area, otherwise; on a desktop a 32pt pill where Return sends.
public struct MessageComposer<Leading: View, Trailing: View>: View {
    @Environment(\.messagesTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject private var keyboard = KeyboardState.shared
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
        .padding(.horizontal, ComposerMetrics.horizontalInset(sizeClass: sizeClass, keyboardVisible: keyboard.visible))
        .padding(.top, showsSendButton ? 6 : 8)
        // A phone's composer sits on the home-indicator safe area; a browser
        // tab has none, so it keeps 8pt of its own above the edge.
        .padding(.bottom, showsSendButton ? (keyboard.visible ? 16 : (MessagesPlatform.isWeb ? 8 : 0)) : 8)
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

/// The composer's geometry, shared with the thread. On a phone the bubbles
/// sit 16pt from the edges, always; the composer sits with them while the
/// keyboard is up and moves out to 24pt when it is away, to sit with the
/// screen's corners. On a desktop both are 12pt.
public enum ComposerMetrics {
    public static func isPhoneComposer(sizeClass: UserInterfaceSizeClass?) -> Bool {
        if MessagesPlatform.isDesktop { return false }
        if MessagesPlatform.isWeb { return sizeClass == .compact }
        return true
    }

    /// The composer's side inset.
    public static func horizontalInset(sizeClass: UserInterfaceSizeClass?, keyboardVisible: Bool) -> CGFloat {
        // The 24pt rests inside an iPhone's rounded corners; a browser tab
        // has no such corners, so the web keeps the messages' 16pt throughout.
        isPhoneComposer(sizeClass: sizeClass) ? ((keyboardVisible || MessagesPlatform.isWeb) ? 16 : 24) : 12
    }

    /// The messages' side inset: the composer's with the keyboard up.
    public static func messageInset(sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isPhoneComposer(sizeClass: sizeClass) ? 16 : 12
    }
}

extension MessageComposer where Leading == EmptyView, Trailing == EmptyView {
    public init(draft: Binding<String>, placeholder: String = "Message", send: @escaping () -> Void) {
        self.init(draft: draft, placeholder: placeholder, accessories: .none, send: send)
    }
}

/// Whether the on-screen keyboard is up (iOS); always down elsewhere.
final class KeyboardState: ObservableObject {
    static let shared = KeyboardState()
    @Published var visible = false

    private init() {
        #if canImport(UIKit) && !os(tvOS)
        let center = NotificationCenter.default
        center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
            self?.visible = true
        }
        center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            self?.visible = false
        }
        #endif
    }
}

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
    }

    private var tint: Color { enabled ? theme.accent : theme.secondaryText.opacity(0.5) }

    @ViewBuilder private var glassOrFill: some View {
        #if canImport(AppKit) || canImport(UIKit)
        if #available(macOS 26, iOS 26, *) {
            Color.clear.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
        } else {
            tint
        }
        #else
        tint
        #endif
    }
}
