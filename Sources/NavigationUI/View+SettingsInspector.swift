import SwiftUI

extension View {
    /// The app's Settings, as `SettingsInspectorButton` opens it: the split
    /// view's trailing inspector in two columns (a Mac's window, an iPad's),
    /// and in one (a phone, a narrow window) a sheet with Done, since an
    /// inspector on a collapsed split view does not present. Put it on the
    /// app's top-level view, the one that takes `settingsPresented`; while it
    /// is open it takes the trailing side, so an app closes any inspector of
    /// its own first. Settings asked for at once (signed out, say) opens just
    /// after the window's first layout, never during it. The app gives its
    /// window a minimum width that fits every column, the inspector's 280
    /// points included, or the sidebar is squeezed.
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
    /// The window has been laid out once. Until then nothing is presented:
    /// on macOS an inspector opened during the window's first layout throws
    /// NSGenericException ("more Update Constraints in Window passes than
    /// there are views in the window"), found by Issues on a Mac, 9 Nov 2026.
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
