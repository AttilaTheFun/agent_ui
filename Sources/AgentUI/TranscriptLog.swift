#if canImport(os)
import os
#endif

/// What the transcript does on its own, told to the system's log where
/// there is one (`log stream --level info --predicate 'subsystem ==
/// "AgentUI"'`), and nowhere elsewhere: its settling, its rows' reveal,
/// and the app's rows changing. Counts, ids and flags only, never a
/// message's words.
@MainActor
enum TranscriptLog {
    #if canImport(os)
    private static let logger = Logger(subsystem: "AgentUI", category: "transcript")
    #endif

    static func info(_ line: @autoclosure () -> String) {
        #if canImport(os)
        let text = line()
        logger.info("\(text, privacy: .public)")
        #endif
    }
}
