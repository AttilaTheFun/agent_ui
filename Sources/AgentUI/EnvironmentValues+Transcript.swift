import SwiftUI

private struct OpenedTranscriptImageKey: EnvironmentKey {
    static let defaultValue: Binding<String?> = .constant(nil)
}

private struct OpenedToolCallsKey: EnvironmentKey {
    static let defaultValue: Binding<[TranscriptMessage]?> = .constant(nil)
}

private struct NewRowsPillSecondsKey: EnvironmentKey {
    static let defaultValue: Double = 4
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

    /// How long the new-rows pill stays after the last rows it counts came
    /// in, in seconds (4). A UI test that reads the pill on a slow machine
    /// sets it longer, so the pill is still there when the test looks.
    public var newRowsPillSeconds: Double {
        get { self[NewRowsPillSecondsKey.self] }
        set { self[NewRowsPillSecondsKey.self] = newValue }
    }
}
