/// Where an app attaches `settingsInspector(isPresented:attachedTo:)`, which
/// takes effect only where the placement is the platform's: on a Mac the
/// detail column, on an iPhone, an iPad and Isomer's platforms the whole
/// split view, as in 0.48 (0.50 restored it after 0.49 moved the Mac to the
/// split view). An app attaches at both, and each platform takes its own.
/// `settingsInspector(isPresented:settings:)` is the other choice: the whole
/// split view on every platform, attached once.
///
/// Which fits an app on a Mac is its detail's to say (9 Nov 2026, real apps
/// on macOS 27):
/// - The detail column: Issues, Reviews and Monitor present and close it
///   cleanly across selection changes. Applications' detail, whose stack's
///   root changes with the selection, crashed with it there even closed:
///   the split view took a new minimum from the detail each
///   update-constraints pass until AppKit threw.
/// - The whole split view: Applications' selection changes are clean, but
///   it clipped Issues' columns and Settings at 1,280 points, and Reviews'
///   inside Shireworks' tab view. The window's minimum must hold the
///   sidebar's ideal width, the detail's minimum and the inspector's 320.
/// - What loops is the detail's content more than the placement: on a Mac,
///   a grouped `Form` whose rows hold controls of a firm width
///   (`.fixedSize()` capsules, bordered buttons) kept moving the column's
///   minimum while the inspector reshaped it, and AppKit's
///   update-constraints pass went round (a selection change with the detail
///   placement, Settings opened with either). The same rows in a `List`
///   were still, with Settings closed and open (Applications, 9 Nov 2026).
///   On a Mac, a page like that is a `List`, or keeps those controls out
///   of its rows.
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
