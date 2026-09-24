import ExampleData
import InboxUI
import MessagesUI
import NavigationUI
import SwiftUI

// The simplest shape: a NavigationStack. The inbox pushes the thread; the
// thread's title presents the details as a sheet. What a phone-only app
// would do.
@main
struct StackExampleApp: App {
    @StateObject private var store = ExampleStore()
    @State private var path: [String] = []
    @State private var detailsFor: String?

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                InboxView(conversations: store.conversations, selection: Binding(
                    get: { path.last },
                    set: { if let id = $0 { path = [id] } }
                ))
                .navigationTitle("Messages")
                .navigationDestination(for: String.self) { id in
                    ExampleThread(store: store, id: id, onTitleTap: { detailsFor = id })
                }
            }
            .sheet(item: Binding(get: { detailsFor.map(Item.init) }, set: { detailsFor = $0?.id })) { item in
                if let conversation = store.conversation(item.id) {
                    InspectorView(isPresented: true, close: { detailsFor = nil }) {
                        ExampleDetails(conversation: conversation)
                    }
                }
            }
        }
    }

    struct Item: Identifiable { let id: String }
}
