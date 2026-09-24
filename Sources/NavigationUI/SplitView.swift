import SwiftUI

/// The two-column layout: a sidebar, a detail, an inspector pane.
/// Messages' shape (the inbox, the open conversation, the details), and
/// Visor's (the computers, the agent, the connection form). Optional: an app
/// can put its screens in a NavigationStack, or in a tab, instead (see the
/// examples).
///
/// Column visibility and the compact column are the app's bindings, so it
/// can land a phone on the detail when the inbox is empty and open the
/// sidebar from a toggle.
public struct SplitView<Sidebar: View, Detail: View, Inspector: View>: View {
    @Binding var columns: NavigationSplitViewVisibility
    @Binding var compactColumn: NavigationSplitViewColumn
    @Binding var inspectorPresented: Bool
    let compact: Bool
    let sidebar: Sidebar
    let detail: Detail
    let inspector: Inspector

    /// - Parameters:
    ///   - compact: a phone's single column, where details are a sheet.
    public init(columns: Binding<NavigationSplitViewVisibility>,
                compactColumn: Binding<NavigationSplitViewColumn>,
                inspectorPresented: Binding<Bool>, compact: Bool,
                @ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder detail: () -> Detail,
                @ViewBuilder inspector: () -> Inspector) {
        self._columns = columns
        self._compactColumn = compactColumn
        self._inspectorPresented = inspectorPresented
        self.compact = compact
        self.sidebar = sidebar()
        self.detail = detail()
        self.inspector = inspector()
    }

    public var body: some View {
        if hasInspector {
            split.adaptiveInspector(isPresented: $inspectorPresented, compact: compact) {
                inspector
            }
        } else {
            split
        }
    }

    /// No inspector at all when none is given: the inspector modifier adds
    /// its own toggle to the Mac's toolbar even while closed.
    private var hasInspector: Bool { !(inspector is EmptyView) }

    private var split: some View {
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            sidebar
        } detail: {
            DetailColumn { detail }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

extension SplitView where Inspector == EmptyView {
    /// Sidebar and detail only.
    public init(columns: Binding<NavigationSplitViewVisibility>,
                compactColumn: Binding<NavigationSplitViewColumn>,
                @ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder detail: () -> Detail) {
        self.init(columns: columns, compactColumn: compactColumn, inspectorPresented: .constant(false), compact: false,
                  sidebar: sidebar, detail: detail, inspector: { EmptyView() })
    }
}

/// The detail column's container: Apple's SwiftUI gives the column its bar
/// (a nested stack strips it on a collapsed phone and squeezes the Mac's
/// sidebar); other SwiftUIs give a column a bar only inside a stack.
struct DetailColumn<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if canImport(UIKit) || canImport(AppKit)
        content()
        #else
        NavigationStack { content() }
        #endif
    }
}

/// The detail column when nothing is open.
public struct EmptyDetail: View {
    let title: String
    let subtitle: String?

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
    }
}


/// The three-column layout: a sidebar, a content column, a detail — Mail's
/// shape (accounts, the inbox, the message) and Visor's (the computers, a
/// computer's projects and sessions, the agent). A phone shows one column
/// at a time and walks sidebar → content → detail.
public struct ThreeColumnSplitView<Sidebar: View, Content: View, Detail: View>: View {
    @Binding var columns: NavigationSplitViewVisibility
    @Binding var compactColumn: NavigationSplitViewColumn
    let sidebar: Sidebar
    let content: Content
    let detail: Detail

    public init(columns: Binding<NavigationSplitViewVisibility>,
                compactColumn: Binding<NavigationSplitViewColumn>,
                @ViewBuilder sidebar: () -> Sidebar,
                @ViewBuilder content: () -> Content,
                @ViewBuilder detail: () -> Detail) {
        self._columns = columns
        self._compactColumn = compactColumn
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
    }

    public var body: some View {
        // The content column gets its bar like the sidebar (every SwiftUI
        // wraps the list columns); only the detail needs DetailColumn.
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            sidebar
        } content: {
            content
        } detail: {
            DetailColumn { detail }
        }
        // The automatic style starts the list columns at their ideal width
        // and gives the detail the rest; balanced spreads the window across
        // all three and prominentDetail widens the lists to their maximum.
        .navigationSplitViewStyle(.automatic)
    }
}

/// Messages' list chrome, the iOS 26 shape: on a phone a bar floating over
/// the list with a search field and a compose button; at regular width the
/// search field sits under the navigation bar (the host's `.searchable`)
/// and compose is a toolbar item.
public struct ListSearchChrome<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var text: String
    let prompt: String
    let composeLabel: String
    let compose: (() -> Void)?
    @ViewBuilder let content: () -> Content

    public init(text: Binding<String>, prompt: String = "Search",
                composeLabel: String = "New", compose: (() -> Void)? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self._text = text
        self.prompt = prompt
        self.composeLabel = composeLabel
        self.compose = compose
        self.content = content
    }

    private var compact: Bool { sizeClass == .compact }

    public var body: some View {
        #if os(iOS)
        // The system's own search and compose, which iOS 26 draws as glass
        // items in the bottom bar.
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
        #elseif os(macOS)
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
        #else
        // The portable SwiftUI: the same two shapes, drawn here.
        if compact {
            content()
                .safeAreaInset(edge: .bottom) { floatingBar }
        } else {
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
        }
        #endif
    }

    /// The field itself: a rounded search box.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
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

    /// The phone's bar: a search field and, beside it, compose.
    private var floatingBar: some View {
        HStack(spacing: 10) {
            searchField.frame(height: 44)
            if let compose {
                Button(action: compose) {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.secondary.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(composeLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
