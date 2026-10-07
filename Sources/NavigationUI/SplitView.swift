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
        #if os(tvOS)
        // A TV: the two columns side by side, laid out here. The system's
        // split view lays its sidebar OVER the detail at a width of its
        // own (ignoring the one asked for) and its balanced style shows
        // one column at a time; neither gives a thread the room beside a
        // list. The sidebar is a card at the system's width, the detail
        // what is left.
        HStack(spacing: 0) {
            sidebar
                .frame(width: SplitMetrics.tvSidebarWidth)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.vertical, 24)
                .padding(.leading, 24)
            DetailColumn { detail }
        }
        #else
        // Messages' edges under the bars: the list of conversations a hard
        // band, the conversation a soft fade.
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            sidebar.hardTopEdge()
        } detail: {
            DetailColumn { detail }.softTopEdge()
        }
        .navigationSplitViewStyle(.balanced)
        #endif
    }
}

/// The TV's own split: the sidebar's width, which the thread's column
/// (AgentUI's TranscriptMetrics) is laid out beside.
public enum SplitMetrics {
    public static let tvSidebarWidth: CGFloat = 480
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
