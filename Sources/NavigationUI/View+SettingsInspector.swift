import SwiftUI

extension View {
    /// The app's Settings, as `SettingsInspectorButton` opens it: the split
    /// view's trailing inspector in two columns (a Mac's window, an iPad's),
    /// and in one (a phone, a narrow window) a sheet with Done, since an
    /// inspector on a collapsed split view does not present. Attach it twice,
    /// on the split view's detail column (`.detail`) and on the whole split
    /// view (`.splitView`): each takes effect only where it is the platform's
    /// place (`SettingsInspectorPlacement`), the other doing nothing. While it
    /// is open it takes the trailing side, so an app closes any inspector of
    /// its own first. Settings asked for at once (signed out, say) opens just
    /// after the window's first layout, never during it.
    ///
    /// Widths: the detail column says its own minimum
    /// (`navigationSplitViewColumnWidth(min:ideal:)`), the narrowest its
    /// content really lays out in, and the app's window has a minimum that
    /// fits the sidebar, that and the inspector's 280 points. When the three
    /// don't fit, the sidebar is squeezed, and on macOS a detail that can't
    /// shrink as far as it is given sends AppKit's update-constraints pass
    /// round until it throws NSGenericException ("more Update Constraints in
    /// Window passes than there are views in the window") the moment Settings
    /// opens (Monitor, 9 Nov 2026: a 900-point window left its dashboard 390).
    ///
    ///     NavigationSplitView {
    ///         Sidebar()
    ///             .navigationSplitViewColumnWidth(min: 230, ideal: 270)
    ///     } detail: {
    ///         Detail()
    ///             .navigationSplitViewColumnWidth(min: 560, ideal: 640)
    ///             .settingsInspector(isPresented: $settingsPresented, attachedTo: .detail) { SettingsForm() }
    ///     }
    ///     // On a Mac the window's minimum is 230 + 560 + 280 = 1,070 or more:
    ///     // .frame(minWidth: 1_100), with a default size above it.
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
