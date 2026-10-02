import SwiftUI

private struct OpenedTranscriptImageKey: EnvironmentKey {
    static let defaultValue: Binding<String?> = .constant(nil)
}

private struct OpenedToolCallsKey: EnvironmentKey {
    static let defaultValue: Binding<[TranscriptMessage]?> = .constant(nil)
}

extension EnvironmentValues {
    /// The picture open over the thread a row is in: a row sets it to
    /// have the thread show that picture whole.
    var openedTranscriptImage: Binding<String?> {
        get { self[OpenedTranscriptImageKey.self] }
        set { self[OpenedTranscriptImageKey.self] = newValue }
    }

    /// The run of tool calls open for inspection over the thread.
    var openedToolCalls: Binding<[TranscriptMessage]?> {
        get { self[OpenedToolCallsKey.self] }
        set { self[OpenedToolCallsKey.self] = newValue }
    }
}
