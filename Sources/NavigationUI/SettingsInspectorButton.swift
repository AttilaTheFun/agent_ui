import SwiftUI

/// The app's way to its Settings, in the navigation bar: "Settings" with a
/// gear, beside the sidebar's toggle in two columns, at the top leading edge
/// in one. It toggles `isPresented`, which `settingsInspector` presents (the
/// standalone tab apps' shape, Logan, 9 Nov 2026: no tab bar, Settings an
/// inspector). The library sets no shortcut: an app, or Shireworks hosting
/// it, gives ⌘, itself.
///
///     .toolbar { SettingsInspectorButton(isPresented: $settingsPresented) }
public struct SettingsInspectorButton: ToolbarContent {
    @Binding var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { isPresented.toggle() } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Settings")
            .accessibilityIdentifier("settings")
        }
    }
}
