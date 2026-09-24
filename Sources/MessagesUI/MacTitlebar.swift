#if os(macOS)
import AppKit
import MessagesCore
import SwiftUI

/// The Mac's thread title as a titlebar accessory. An NSToolbar clips its
/// items to the bar, content drawn under the bar is blurred by the bar's
/// material, and hiding the material loses the scroll edge's hover reveal;
/// an accessory shares the bar, so the avatar-and-pill can hang from it
/// with everything else intact.
///
/// The app updates `title` (nil on the inbox) and gets `onTap` when the
/// avatar or pill is clicked. The avatar sits up in the bar, where the
/// titlebar takes every click, so a local event monitor takes those first.
@MainActor
public final class MacConversationTitlebar: ObservableObject {
    /// What to draw, or nothing.
    @Published public var title: (name: String, avatar: AvatarSource, presence: Presence)?
    public var onTap: () -> Void = {}

    private var hosting: NSHostingView<TitleView>?
    private var monitor: Any?
    private var attached = false
    private var observer: NSObjectProtocol?

    public init() {}

    /// Attaches to the first titled, toolbar-bearing window that becomes
    /// key (or is key already).
    public func install() {
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.attach(to: note.object as? NSWindow) }
        }
        DispatchQueue.main.async { [weak self] in
            self?.attach(to: NSApp.keyWindow ?? NSApp.windows.first { $0.styleMask.contains(.titled) })
        }
    }

    public func attach(to window: NSWindow?) {
        guard !attached, let window, window.styleMask.contains(.titled), window.toolbar != nil else { return }
        attached = true
        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .bottom
        let hosting = NSHostingView(rootView: TitleView(model: self))
        hosting.frame.size.height = ConversationTitle.macHang + 8
        accessory.view = hosting
        window.addTitlebarAccessoryViewController(accessory)
        self.hosting = hosting
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let rect = self.avatarRect(in: event.window),
                  rect.contains(event.locationInWindow) else { return event }
            self.onTap()
            return nil
        }
    }

    /// The avatar in the window's coordinates (origin bottom left):
    /// centred on the accessory's band, its top 13pt below the window's
    /// top as measured.
    private func avatarRect(in window: NSWindow?) -> NSRect? {
        guard let hosting, let window, hosting.window === window, title != nil else { return nil }
        let band = hosting.convert(hosting.bounds, to: nil)
        let size = ConversationTitle.macAvatar
        return NSRect(x: band.midX - size / 2, y: window.frame.height - 13 - size, width: size, height: size)
    }

    struct TitleView: View {
        @ObservedObject var model: MacConversationTitlebar

        var body: some View {
            if let title = model.title {
                ConversationTitle(name: title.name, avatar: title.avatar, presence: title.presence)
                    // Only the part hanging below the toolbar is the
                    // accessory's band; the rest is drawn above its top.
                    .offset(y: ConversationTitle.macHang
                        - (ConversationTitle.macAvatar - ConversationTitle.overlap + ConversationTitle.pillHeight))
                    .frame(maxWidth: .infinity)
                    .frame(height: ConversationTitle.macHang + 8, alignment: .top)
                    .contentShape(Rectangle())
                    .onTapGesture { model.onTap() }
            } else {
                Color.clear.frame(height: 0)
            }
        }
    }
}
#endif
