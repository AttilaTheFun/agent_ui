import SwiftUI

extension View {
    /// The app's Settings, as `SettingsInspectorButton` opens it, attached
    /// once to the whole `NavigationSplitView` on every platform: the split
    /// view's trailing inspector in two columns (a Mac's window, an iPad's),
    /// and in one (a phone, a narrow window) a sheet with Done, since an
    /// inspector on a collapsed split view does not present. On a Mac this
    /// is the placement for a detail whose stack's root changes with the
    /// selection, which an inspector in the detail column can loop; the
    /// other is `settingsInspector(isPresented:attachedTo:)`, the detail
    /// column there (`SettingsInspectorPlacement` says which fits when).
    /// It is the window's only inspector: on a Mac a second one on the
    /// trailing side, even closed (a page's own, attached inside the detail),
    /// sent AppKit's update-constraints pass round until the app spun or
    /// threw (Visor's Mac proof, 10 Nov 2026). An app with an inspector of
    /// its own shows it and Settings in one pane of its own instead (Visor's
    /// TrailingPane), with `SettingsInspectorButton` opening it. Settings
    /// asked for at once (signed out, say) opens just after the window's
    /// first layout, never during it.
    ///
    /// Widths: the detail column says its own minimum, once, on its stack's
    /// root content (`navigationSplitViewColumnWidth(min:ideal:)`), the
    /// narrowest its content really lays out in, and the app's Mac window
    /// has a minimum that fits the sidebar's ideal width, the detail's
    /// minimum and the inspector's ideal (320): AppKit lays the columns out
    /// at their ideal widths, not their minimums, and gives the detail what
    /// is left.
    ///
    ///     NavigationSplitView {
    ///         Sidebar()
    ///             .navigationSplitViewColumnWidth(min: 230, ideal: 270)
    ///     } detail: {
    ///         Detail()
    ///             .navigationSplitViewColumnWidth(min: 560, ideal: 640)
    ///     }
    ///     .settingsInspector(isPresented: $settingsPresented) { SettingsForm() }
    ///     // On a Mac the window's minimum is 270 + 560 + 320 = 1,150 or more:
    ///     // .frame(minWidth: 1_160), with a default size above it.
    public func settingsInspector<Settings: View>(isPresented: Binding<Bool>,
                                                  @ViewBuilder settings: @escaping () -> Settings) -> some View {
        modifier(SettingsInspectorPresentation(isPresented: isPresented, settings: settings))
    }

    /// The app's Settings at the platform's own place, attached twice, on
    /// the split view's detail column (`.detail`) and on the whole split view
    /// (`.splitView`): each takes effect only where it is the platform's
    /// (`SettingsInspectorPlacement`: the detail column on a Mac, the whole
    /// split view elsewhere), the other doing nothing.
    ///
    ///     NavigationSplitView { Sidebar() } detail: {
    ///         Detail()
    ///             .settingsInspector(isPresented: $settingsPresented, attachedTo: .detail) { SettingsForm() }
    ///     }
    ///     .settingsInspector(isPresented: $settingsPresented, attachedTo: .splitView) { SettingsForm() }
    @ViewBuilder public func settingsInspector<Settings: View>(isPresented: Binding<Bool>, attachedTo placement: SettingsInspectorPlacement,
                                                              @ViewBuilder settings: @escaping () -> Settings) -> some View {
        if placement == SettingsInspectorPlacement.platform {
            modifier(SettingsInspectorPresentation(isPresented: isPresented, settings: settings))
        } else {
            self
        }
    }
}

/// `settingsInspector`'s presentation: the size class decides it, and a Mac
/// always has two columns.
private struct SettingsInspectorPresentation<Settings: View>: ViewModifier {
    @Binding var isPresented: Bool
    let settings: () -> Settings
    /// The window has been laid out once. Until then nothing is presented,
    /// so the inspector never joins the window's first layout. (The
    /// NSGenericException Issues and Monitor met opening Settings on a Mac
    /// turned out to be columns that didn't fit, at launch or later: the
    /// widths in `settingsInspector`'s documentation are the fix.)
    @State private var laidOut = false
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var compact: Bool {
        #if os(macOS)
        false
        #else
        sizeClass == .compact
        #endif
    }

    /// What is presented: the app's binding, once the window is laid out.
    private var shown: Binding<Bool> {
        Binding(get: { laidOut && isPresented }, set: { isPresented = $0 })
    }

    func body(content: Content) -> some View {
        presented(content)
            // Appearing is part of the first layout; the next turn of the
            // main actor is after it.
            .task {
                await Task.yield()
                laidOut = true
            }
    }

    @ViewBuilder private func presented(_ content: Content) -> some View {
        if compact {
            content.sheet(isPresented: shown) {
                NavigationStack {
                    settings()
                        .navigationTitle("Settings")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isPresented = false }
                                    .accessibilityIdentifier("settings-done")
                            }
                        }
                }
            }
        } else {
            // Its width set, as the other inspectors': SwiftUI's default came
            // out a few points different from one launch to the next.
            content.inspector(isPresented: shown) {
                settings().inspectorColumnWidth(min: 280, ideal: 320, max: 420)
            }
        }
    }
}
