/// Where an app attached `settingsInspector(isPresented:attachedTo:)`: since
/// 0.49 the whole split view on every platform (`settingsInspector(isPresented:settings:)`
/// attaches it there in one call), and an attachment on the detail column
/// does nothing.
///
/// - On a Mac an inspector anywhere in the detail column, closed or open, set
///   AppKit's update-constraints pass widening the window each pass when the
///   detail's stack changed its root (a selection), until it threw
///   NSGenericException; on the whole split view it doesn't (Applications'
///   finding, 9 Nov 2026: its window went from 1,200 to 4,287 points wide).
///   The detail's own minimum width (`navigationSplitViewColumnWidth`) is
///   what keeps the inspector from pushing the other columns out.
/// - On an iPad the inspector on the detail column took the detail's
///   navigation title and dimmed it; on the whole split view it doesn't.
public enum SettingsInspectorPlacement: Sendable {
    /// The split view's detail column: no longer presents (0.49).
    case detail
    /// The whole split view: every platform's.
    case splitView

    /// The platform's own: the whole split view, everywhere.
    static var platform: SettingsInspectorPlacement { .splitView }
}
