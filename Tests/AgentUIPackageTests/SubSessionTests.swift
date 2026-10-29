@testable import AgentUI
import XCTest

final class SubSessionTests: XCTestCase {
    func testEachKindSaysWhatItIs() {
        let kinds: [SubSession.Kind] = [.fork, .branch, .side, .subagent]
        XCTAssertEqual(kinds.map(\.label), ["Fork", "Branch", "Side question", "Subagent"])
        XCTAssertEqual(Set(kinds.map(\.symbol)).count, kinds.count, "each kind has a symbol of its own")
    }

    func testARowsDetailDefaultsToItsKind() {
        let side = SubSession(id: "s", kind: .side, title: "Why?")
        XCTAssertNil(side.detail)
        XCTAssertFalse(side.working)
    }
}
