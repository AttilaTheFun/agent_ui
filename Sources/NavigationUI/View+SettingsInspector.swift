import SwiftUI

extension View {
    /// The app's Settings, as `SettingsInspectorButton` opens it: the split
    /// view's trailing inspector in two columns (a Mac's window, an iPad's),
    /// and in one (a phone, a narrow window) a sheet with Done, since an
    /// inspector on a collapsed split view does not present. Put it on the
    /// app's top-level view, the one that takes `settingsPresented`; while it
    /// is open it takes the trailing side, so an app closes any inspector of
    /// its own first.
    ///
    ///     SplitView(…)
    ///         .settingsInspector(isPresented: $settingsPresented) { SettingsForm() }
    public func settingsInspector<Settings: View>(isPresented: Binding<Bool>,
                                                 @ViewBuilder settings: @escaping () -> Settings) -> some View {
        modifier(SettingsInspectorPresentation(isPresented: isPresented, settings: settings))
    }
}

/// `settingsInspector`'s presentation: the size class decides it, and a Mac
/// always has two columns.
private struct SettingsInspectorPresentation<Settings: View>: ViewModifier {
    @Binding var isPresented: Bool
    let settings: () -> Settings
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

    func body(content: Content) -> some View {
        if compact {
            content.sheet(isPresented: $isPresented) {
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
            content.inspector(isPresented: $isPresented) {
                settings().inspectorColumnWidth(min: 280, ideal: 320, max: 420)
            }
        }
    }
}
