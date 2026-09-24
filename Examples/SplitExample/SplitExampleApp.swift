import ExampleData
import InboxUI
import MessagesUI
import NavigationUI
import SwiftUI
#if os(macOS)
import AppKit
#endif

// Messages.app's shape: the split view with the inbox as the sidebar, the
// thread as the detail, the details as an inspector (a sheet on a phone).
// The Mac's title is the titlebar accessory.
#if os(macOS)
/// The titlebar title is installed before the window first shows: added
/// to a window already on screen, the accessory's band came up opaque and
/// clipped the avatar.
@MainActor final class Titlebar {
    static let shared = MacConversationTitlebar()
}

final class SplitAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Titlebar.shared.install()
    }
}
#endif

@main
struct SplitExampleApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(SplitAppDelegate.self) private var delegate
    #endif

    var body: some Scene {
        WindowGroup {
            SplitRoot()
        }
        .defaultSize(width: 960, height: 640)
    }
}

struct SplitRoot: View {
    @StateObject private var store = ExampleStore()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: String?
    @State private var columns: NavigationSplitViewVisibility = .automatic
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var details = false
    #if os(macOS)
    private var titlebar: MacConversationTitlebar { Titlebar.shared }
    #endif

    private var compact: Bool {
        #if os(macOS)
        false
        #else
        sizeClass == .compact
        #endif
    }

    private var open: String? { selection ?? (compact ? nil : store.conversations.first?.id) }

    var body: some View {
        SplitView(columns: $columns, compactColumn: $compactColumn, inspectorPresented: $details, compact: compact) {
            InboxView(conversations: store.conversations, selection: $selection)
                .navigationTitle("Messages")
        } detail: {
            Group {
                if let id = open {
                    ExampleThread(store: store, id: id, onTitleTap: { details.toggle() })
                } else {
                    EmptyDetail(title: "Select a conversation")
                }
            }
            // Compose at the leading end of the content's bar, beside the
            // sidebar, where Messages keeps it.
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("New Message", systemImage: "square.and.pencil") {}
                }
            }
        } inspector: {
            if let id = open, let conversation = store.conversation(id) {
                InspectorView(isPresented: details, close: { details = false }) {
                    ExampleDetails(conversation: conversation)
                }
            }
        }
        #if os(macOS)
        .task {
            titlebar.onTap = { details.toggle() }
        }
        .onChange(of: open, initial: true) { _, id in
            titlebar.title = id.flatMap(store.conversation).map { ($0.name, $0.avatar, $0.presence) }
        }
        #endif
    }
}
