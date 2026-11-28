#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import AgentUI

/// The slash commands' menu in a narrow window: Stage Manager's narrowest
/// iPad window is 320 pt, and the popover, 332 pt wide whatever the
/// window, was cut off at its edges there.
@MainActor
final class SuggestionWidthTests: XCTestCase {
    private let suggestions = [
        AgentSuggestion(text: "/compact ", title: "/compact", detail: "Summarize the conversation so far to free up context"),
        AgentSuggestion(text: "/clear ", title: "/clear", detail: "Start over with an empty conversation"),
        AgentSuggestion(text: "/model ", title: "/model", detail: "Choose the model the agent uses"),
    ]

    /// A 320 pt window's composer, within its margins.
    private let narrow = 320 - 2 * TranscriptMetrics.edgeInset

    private func spin(_ seconds: Double = 0.05) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func width(of view: some View, offered: CGFloat? = nil) -> CGFloat {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: offered, height: nil)
        guard let image = renderer.cgImage else {
            XCTFail("nothing rendered")
            return .infinity
        }
        return CGFloat(image.width) / renderer.scale
    }

    /// The popover's list is no wider than a narrow composer, and 332 pt
    /// as before wherever the composer is wider.
    func testThePopoversListIsNoWiderThanTheComposer() {
        let list = { (composer: CGFloat) in
            ComposerSuggestions.PopoverList(suggestions: self.suggestions, width: composer, pick: { _ in })
        }
        XCTAssertLessThanOrEqual(width(of: list(narrow)), narrow + 0.5, "within a 320 pt window's composer")
        XCTAssertEqual(width(of: list(600)), 332, accuracy: 0.5, "as wide as it was in a wider window")
    }

    /// The menu a Mac shows, offered a narrow composer's width, keeps to it.
    func testTheMenuIsNoWiderThanTheComposer() {
        let menu = ComposerSuggestions(draft: .constant("/"), suggest: { _ in self.suggestions }, room: 400, width: narrow, pick: { _ in })
            .environment(\.suggestionsInPopover, false)
        XCTAssertLessThanOrEqual(width(of: menu, offered: narrow), narrow + 0.5)
    }

    /// The composer in a 320 pt window, its draft a slash: the popover that
    /// comes up is within the window, its list within the composer, which
    /// measures its own width and hands it to the popover. (A Mac draws the
    /// popover as an iPad does, in a window of its own.)
    func testThePopoverFitsA320PointWindow() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        let composer = AgentComposer(draft: .constant("/"), busy: false, send: {}, stop: {},
                                     suggestions: { _ in self.suggestions }) {
            EmptyView()
        } attachments: {
            EmptyView()
        }
        .environment(\.suggestionsInPopover, true)
        window.contentView = NSHostingView(rootView: VStack { Spacer(); composer })
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        var popover: NSWindow?
        for _ in 0..<40 where popover == nil {
            spin()
            popover = NSApplication.shared.windows.first { $0 !== window && $0.isVisible && String(describing: type(of: $0)).contains("Popover") }
        }
        let shown = try XCTUnwrap(popover, "no popover came up")
        // The list scrolls: its scroll view is as wide as it is.
        let list = try XCTUnwrap(scrollView(in: try XCTUnwrap(shown.contentView)), "no list in the popover")
        XCTAssertLessThanOrEqual(list.frame.width + 2 * 6, narrow + 0.5, "the list, and its room each side, within the composer")
        XCTAssertLessThanOrEqual(shown.frame.width, window.frame.width, "the popover within the window")
    }

    private func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        for sub in view.subviews { if let found = scrollView(in: sub) { return found } }
        return nil
    }
}
#endif
