// A host whose transcripts must stay in the app sets
// transcriptSharingAllowed false: the agent's messages then come without
// their copy and share buttons (and their words without selection, the
// picture viewer without share). By default they are all there.

import SwiftUI
import XCTest
@testable import AgentUI

@MainActor
final class TranscriptSharingTests: XCTestCase {
    private func height(of view: some View) -> CGFloat {
        let renderer = ImageRenderer(content: view.frame(width: 300))
        renderer.proposedSize = ProposedViewSize(width: 300, height: nil)
        guard let image = renderer.cgImage else {
            XCTFail("nothing rendered")
            return 0
        }
        return CGFloat(image.height) / renderer.scale
    }

    func testAMessageKeptInTheAppHasNoCopyOrShare() {
        XCTAssertTrue(EnvironmentValues().transcriptSharingAllowed, "allowed unless the host says otherwise")
        let words = height(of: MarkdownText("All done."))
        let shared = height(of: AssistantBubble(text: "All done."))
        let kept = height(of: AssistantBubble(text: "All done.").environment(\.transcriptSharingAllowed, false))
        XCTAssertGreaterThan(shared, words + 10, "the copy and share buttons under the words")
        XCTAssertEqual(kept, words, accuracy: 1, "only the words")
    }
}
