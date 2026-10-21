// Guards for what the thread and the composer looked like when they were
// right: laid out by SwiftUI itself (ImageRenderer), so a change that
// brings a regression back fails here rather than on someone's phone.

import SwiftUI
import XCTest
@testable import AgentUI
@testable import MarkdownViews

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

    /// A code block's line longer than the width wraps within it (a
    /// connection code is one long word), rather than running off the side
    /// to be scrolled to.
    func testACodeBlockWraps() {
        let code = String(repeating: "eyJhZGRyZXNzZXMiOlsiaHR0cHM6", count: 12)
        let block = size(of: MarkdownText("```\n" + code + "\n```"), width: 300)
        let oneLine = size(of: MarkdownText("```\nshort\n```"), width: 300).height
        XCTAssertLessThanOrEqual(block.width, 300.5, "the block stays within the width")
        XCTAssertGreaterThan(block.height, oneLine * 3, "the line wraps onto several")
    }

    /// A message's pictures wider than the message become a carousel
    /// within its width: four phone screenshots side by side ran off the
    /// screen and took the message's words with them. Two that fit stay a
    /// row as wide as they are.
    func testPicturesTooWideBecomeACarousel() {
        func width(_ count: Int) -> CGFloat {
            let urls = (0..<count).map { "https://example.invalid/image-\($0).png" }
            let strip = ImageStrip(urls: urls, sizes: Array(repeating: CGSize(width: 1179, height: 2556), count: count), alignment: .trailing)
            let renderer = ImageRenderer(content: strip)
            renderer.proposedSize = ProposedViewSize(width: 300, height: nil)
            guard let image = renderer.cgImage else { return .infinity }
            return CGFloat(image.width) / renderer.scale
        }
        XCTAssertLessThanOrEqual(width(4), 300.5, "four screenshots stay within the message")
        XCTAssertLessThanOrEqual(width(2), 300.5)
    }

    /// Your message's carousel is as wide as the thread, not cut off at
    /// the margin your words keep on the left: its pictures scroll to the
    /// screen's edge.
    func testYourCarouselIsAsWideAsTheThread() {
        let urls = (0..<4).map { "https://example.invalid/image-\($0).png" }
        let message = TranscriptMessage(id: "m", role: .user, text: "Four screenshots",
                                        imageURLs: urls, imageSizes: Array(repeating: CGSize(width: 1179, height: 2556), count: 4))
        let row = TranscriptRow(message: message)
        let renderer = ImageRenderer(content: row)
        renderer.proposedSize = ProposedViewSize(width: 300, height: nil)
        let width = renderer.cgImage.map { CGFloat($0.width) / renderer.scale } ?? 0
        XCTAssertEqual(width, 300, accuracy: 0.5, "the row takes the thread's width, and no more")
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
