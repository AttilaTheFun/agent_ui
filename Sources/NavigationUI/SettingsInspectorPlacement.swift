/// Where an app attaches `settingsInspector`, which takes effect only where
/// its placement is the platform's: the detail column on a Mac, the whole
/// split view on an iPhone, an iPad and Isomer's platforms. An app attaches
/// it at both, and each platform gets its own (Issues' findings, 9 Nov 2026).
///
/// - On a Mac the inspector on the whole split view overflowed the window: the
///   detail kept its width and pushed the sidebar and the inspector past the
///   window's edges. On the detail column it is the split view's trailing
///   column, and the detail gives way.
/// - On an iPad the inspector on the detail column took the detail's
///   navigation title and dimmed it; on the whole split view it doesn't.
public enum SettingsInspectorPlacement: Sendable {
    /// The split view's detail column: a Mac's.
    case detail
    /// The whole split view: an iPhone's, an iPad's, Isomer's.
    case splitView

    /// The platform's own.
    static var platform: SettingsInspectorPlacement {
        #if os(macOS)
        .detail
        #else
        .splitView
        #endif
    }
}
