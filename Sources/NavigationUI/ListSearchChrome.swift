import SwiftUI

/// Messages' list chrome, the iOS 26 shape: on a phone a bar floating over
/// the list with a search field and a compose button; at regular width the
/// search field sits under the navigation bar (the host's `.searchable`)
/// and compose is a toolbar item.
public struct ListSearchChrome<Content: View>: View {
    @Binding var text: String
    let prompt: String
    let composeLabel: String
    let compose: (() -> Void)?
    @ViewBuilder let content: () -> Content
    #if os(macOS)
    @FocusState private var searching: Bool
    #endif

    public init(text: Binding<String>, prompt: String = "Search",
                composeLabel: String = "New", compose: (() -> Void)? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self._text = text
        self.prompt = prompt
        self.composeLabel = composeLabel
        self.compose = compose
        self.content = content
    }

    public var body: some View {
        #if !os(macOS) && !os(tvOS)
        // The system's own search and compose, which iOS 26 (and the
        // portable SwiftUI) draws as glass items in the bottom bar.
        if #available(iOS 26.0, *) {
            content()
                .searchable(text: $text, prompt: prompt)
                .toolbar {
                    // The field takes the bar, with compose beside it, as
                    // the Messages inbox has them.
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    if let compose {
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) {
                            Button(composeLabel, systemImage: "square.and.pencil", action: compose)
                        }
                    }
                }
        } else {
            content()
                .searchable(text: $text, prompt: prompt)
                .toolbar {
                    if let compose {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: compose) { Image(systemName: "square.and.pencil") }
                                .accessibilityLabel(composeLabel)
                        }
                    }
                }
        }
        #else
        // The Mac's shape: the field under the navigation bar, not in it;
        // compose stays a toolbar item.
        content()
            .safeAreaInset(edge: .top) { searchField.padding(.horizontal, 12).padding(.bottom, 8) }
            .toolbar {
                if let compose {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: compose) { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel(composeLabel)
                    }
                }
            }
        #endif
    }

    /// The Mac's field: a rounded search box.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                #if os(macOS)
                // The window opens on its list, not typing into the search:
                // AppKit hands the first field the keyboard when the window
                // comes up, so it is taken back once it has.
                .focused($searching)
                .task {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    searching = false
                }
                #endif
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear the search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(Color.secondary.opacity(0.18)))
    }

}
