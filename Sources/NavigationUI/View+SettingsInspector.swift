import SwiftUI

extension View {
    /// The app's Settings, as `SettingsInspectorButton` opens it: the split
    /// view's trailing inspector in two columns (a Mac's window, an iPad's),
    /// and in one (a phone, a narrow window) a sheet with Done, since an
    /// inspector on a collapsed split view does not present. Attached to the
    /// whole `NavigationSplitView`, never inside its detail column
    /// (`SettingsInspectorPlacement`: on a Mac one there makes AppKit widen
    /// the window until it throws). While it is open it takes the trailing
    /// side, so an app closes any inspector of its own first. Settings asked
    /// for at once (signed out, say) opens just after the window's first
    /// layout, never during it.
    ///
    /// Widths: the detail column says its own minimum
    /// (`navigationSplitViewColumnWidth(min:ideal:)`), the narrowest its
    /// content really lays out in, and the app's Mac window has a minimum
    /// that fits the sidebar's ideal width, the detail's minimum and the
    /// inspector's ideal (320): AppKit lays the columns out at their ideal
    /// widths, not their minimums, and gives the detail what is left.
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

    /// Before 0.49 an app attached Settings twice, on the detail column and
    /// on the whole split view, and each platform took one. Now the split
    /// view's presents everywhere and the detail column's does nothing:
    /// attach once, with `settingsInspector(isPresented:settings:)`.
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
