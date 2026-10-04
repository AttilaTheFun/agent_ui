// Guards for what the thread and the composer looked like when they were
// right: laid out by SwiftUI itself (ImageRenderer), so a change that
// brings a regression back fails here rather than on someone's phone.

import SwiftUI
import XCTest
@testable import AgentUI

@MainActor
final class LayoutRegressionTests: XCTestCase {
    /// The size `view` takes when offered `width` and `height` (nil: as
    /// much as it wants).
    private func size(of view: some View, width: CGFloat? = nil, height: CGFloat? = nil) -> CGSize {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        guard let image = renderer.cgImage else {
            XCTFail("nothing rendered")
            return .zero
        }
        return CGSize(width: CGFloat(image.width) / renderer.scale, height: CGFloat(image.height) / renderer.scale)
    }

    /// A list item longer than its line wraps onto every line it needs,
    /// even offered less height — as a list cell offers a row by its
    /// estimate — rather than stopping at "…".
    func testAListItemWraps() {
        let words = "**keep the order rows were written in**, so a row edited twice while offline reaches the server as its last edit, not its first"
        let oneLine = size(of: MarkdownText("- short"), width: 300).height
        let paragraph = size(of: Text(words), width: 300).height
        XCTAssertGreaterThan(paragraph, oneLine * 2.5, "the words need several lines")
        let item = size(of: MarkdownText("- " + words), width: 300, height: oneLine).height
        XCTAssertGreaterThanOrEqual(item, paragraph - 1, "the item takes them all, offered one line")
    }

    /// The send button's target is the circle and the room around it: taps
    /// beside the circle land on it.
    func testTheSendTargetIsLargerThanItsCircle() {
        let circle = AgentComposerMetrics.controlHeight
        let target = size(of: Image(systemName: "arrow.up").agentCircleTarget())
        XCTAssertGreaterThanOrEqual(target.width, circle + 2 * AgentComposerMetrics.gap)
        XCTAssertGreaterThanOrEqual(target.height, circle + AgentComposerMetrics.gap + AgentComposerMetrics.textInset)
    }
}

/// Earlier rows put in above the thread: what keeps the row that was first
/// at the top, rather than the list showing the page's own first row.
@MainActor
final class EarlierRowsTests: XCTestCase {
    private func row(_ id: String, _ text: String = "words") -> TranscriptMessage {
        TranscriptMessage(id: id, role: .assistant, text: text)
    }

    private func call(_ id: String) -> TranscriptMessage {
        TranscriptMessage(id: id, role: .assistant, text: "", activities: ["Bash: ls"])
    }

    func testAPageInFrontIsAPrepend() {
        let old = [row("a"), row("b")]
        XCTAssertTrue(TranscriptView.prepends([row("x"), row("y")] + old, to: old))
        XCTAssertFalse(TranscriptView.prepends(old + [row("c")], to: old), "rows after the last are an append")
        XCTAssertFalse(TranscriptView.prepends([row("x"), row("b")], to: old), "the first row gone is a replacement")
        XCTAssertFalse(TranscriptView.prepends(old, to: old))
        XCTAssertFalse(TranscriptView.prepends([row("x")], to: []))
    }

    func testTheRowKeptIsTheOldFirst() {
        let old = [row("a"), row("b")]
        XCTAssertEqual(TranscriptView.firstKept(of: old, in: [row("x")] + old), "a")
    }

    /// Tool calls at the top of the thread join the run of calls the page
    /// ends with, under the page's id: the next row of the old ones is kept.
    func testARunJoinedAcrossThePageKeepsTheNextRow() {
        let old = [call("c2"), row("b")]
        let new = [row("x"), call("c1")] + old
        XCTAssertEqual(TranscriptBlock.blocks(new).map(\.id), ["x", "calls-c1", "b"])
        XCTAssertEqual(TranscriptView.firstKept(of: old, in: new), "b")
    }
}
