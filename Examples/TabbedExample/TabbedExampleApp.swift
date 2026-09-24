import ExampleData
import InboxUI
import MessagesUI
import NavigationUI
import SwiftUI

// An app where messages are one tab among others (a feed, a profile). On a
// phone the tab holds a NavigationStack; on an iPad or a Mac the same tab
// expands into the split view. The other tabs know nothing of messages.
@main
struct TabbedExampleApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    List(1..<20) { n in Text("Post \(n)") }
                        .navigationTitle("Feed")
                }
                .tabItem { Label("Feed", systemImage: "list.bullet.rectangle") }
                MessagesTab()
                    .tabItem { Label("Messages", systemImage: "message") }
                Text("Profile")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
        }
        .defaultSize(width: 960, height: 640)
    }
}

struct MessagesTab: View {
    @StateObject private var store = ExampleStore()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: String?
    @State private var path: [String] = []
    @State private var columns: NavigationSplitViewVisibility = .automatic
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var details = false

    private var compact: Bool {
        #if os(macOS)
        false
        #else
        sizeClass == .compact
        #endif
    }

    var body: some View {
        if compact {
            NavigationStack(path: $path) {
                InboxView(conversations: store.conversations, selection: Binding(
                    get: { path.last }, set: { if let id = $0 { path = [id] } }
                ))
                .navigationTitle("Messages")
                .navigationDestination(for: String.self) { id in
                    ExampleThread(store: store, id: id, onTitleTap: { details = true })
                }
            }
            .sheet(isPresented: $details) {
                if let id = path.last, let conversation = store.conversation(id) {
                    InspectorView(isPresented: true, close: { details = false }) {
                        ExampleDetails(conversation: conversation)
                    }
                }
            }
        } else {
            SplitView(columns: $columns, compactColumn: $compactColumn, inspectorPresented: $details, compact: false) {
                InboxView(conversations: store.conversations, selection: $selection)
                    .navigationTitle("Messages")
            } detail: {
                if let id = selection ?? store.conversations.first?.id {
                    ExampleThread(store: store, id: id, onTitleTap: { details.toggle() })
                } else {
                    EmptyDetail(title: "Select a conversation")
                }
            } inspector: {
                if let id = selection ?? store.conversations.first?.id, let conversation = store.conversation(id) {
                    InspectorView(isPresented: details, close: { details = false }) {
                        ExampleDetails(conversation: conversation)
                    }
                }
            }
        }
    }
}
