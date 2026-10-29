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

private struct BranchFromMessageKey: EnvironmentKey {
    static let defaultValue: MessageAction? = nil
}

private struct TranscriptSharingAllowedKey: EnvironmentKey {
    static let defaultValue = true
}

private struct SuggestionsInPopoverKey: EnvironmentKey {
    #if os(iOS)
    static let defaultValue = true
    #else
    static let defaultValue = false
    #endif
}

extension EnvironmentValues {
    /// The picture open over the thread a row is in: a row sets it to
    /// have the thread show that picture whole.
    var openedTranscriptImage: Binding<String?> {
        get { self[OpenedTranscriptImageKey.self] }
        set { self[OpenedTranscriptImageKey.self] = newValue }
    }

    /// Branch from Here, under each of the agent's replies, where the app
    /// takes it: told the reply's id.
    var branchFromMessage: MessageAction? {
        get { self[BranchFromMessageKey.self] }
        set { self[BranchFromMessageKey.self] = newValue }
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

    /// Whether the ways to finish a draft (slash commands) are a popover,
    /// over everything as a context menu is, rather than a menu floating
    /// above the composer: true on an iPhone or iPad, where a phone held
    /// sideways has room above its composer only under the navigation
    /// bar. A host on one that isn't built for iOS (Isomer's iPhone app)
    /// sets it, so it looks as the native one does.
    public var suggestionsInPopover: Bool {
        get { self[SuggestionsInPopoverKey.self] }
        set { self[SuggestionsInPopoverKey.self] = newValue }
    }

    /// Whether what the transcript says may be taken out of it: its words
    /// selected, a message copied or shared, a picture shared (true). A
    /// host whose transcripts must stay in the app sets it false.
    public var transcriptSharingAllowed: Bool {
        get { self[TranscriptSharingAllowedKey.self] }
        set { self[TranscriptSharingAllowedKey.self] = newValue }
    }
}
