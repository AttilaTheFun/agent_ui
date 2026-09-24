# AgentUI, for agents

Chat interfaces as SwiftUI packages, consumed by Visor
(github.com/AttilaTheFun/visor) and other apps. Read `README.md` first for
what the pieces are.

## Layout

- `Package.swift` at the root: the four products (InboxUI, MessagesUI,
  AgentUI, NavigationUI), the shared `MessagesCore` target, the tests, and
  `ExampleData` (the examples' fake store). Nothing else.
- `Sources/MessagesCore/`: Model, Theme, Styles, Avatar, Platform — what the
  inbox and the thread share; re-exported by InboxUI and MessagesUI.
- `Sources/InboxUI/`: InboxView. `Sources/MessagesUI/`: ThreadView (with
  MessageView), Composer, Title, MacTitlebar. `Sources/AgentUI/`: AgentView,
  Transcript, AgentComposer. `Sources/NavigationUI/`: SplitView,
  InspectorView.
- `Tests/AgentUIPackageTests/`: XCTest, `swift test`.
- `Examples/`: the four example apps as an Xcode project generated from
  `project.yml` with XcodeGen, plus `ExampleData`. Run them from Xcode;
  do not add `swift run` executables back (see Examples/README.md for why).

## Rules

- Every target imports SwiftUI and nothing else. No app code, no Bazel, no third-party dependencies. It is built here against Apple's
  SwiftUI and elsewhere (wasm, Android, Linux, Windows) against a
  reimplementation of the same API, so:
  - Use only SwiftUI API that exists on iOS 17 / macOS 14, behind
    `#available` for anything newer (the 26 glass styles are the pattern),
    and behind `canImport(UIKit) || canImport(AppKit)` when the other
    SwiftUI lacks it.
  - Foundation use stays to the essentials: Date, URL, Calendar. No
    DateFormatter, Data, JSONDecoder, FileManager, URLSession,
    NotificationCenter (the last only under `canImport(UIKit)`). AgentUI
    avoids Foundation altogether (`AgentText` trims by hand).
  - Platform differences go through `MessagesPlatform` (compile-time
    `#if os`), never a runtime platform enum from outside.
  - `CGFloat` comes through `import SwiftUI`, not CoreGraphics.
- Data and navigation belong to the app. Views take value types
  (`ConversationSummary`, `MessageItem`, `TranscriptMessage`) and bindings
  or closures; they do not own selection, presentation, or a data source.
  AgentView's composer controls and attachments are the app's views.
- Geometry that several pieces share lives in one place (`ComposerMetrics`
  for the composer's and bubbles' insets, `ConversationTitle`'s constants
  for the Mac titlebar). Change it there, not in a consumer.
- Anything Messages-specific in look and feel is deliberate and measured
  against Messages.app on the same OS; consumers must not carry their own
  copies of these views. AgentUI's look is the Claude app's; consumers must
  not carry copies.

## Verifying

`swift build && swift test` for the library. For anything visual, run an
example app from the Xcode project (the Mac chrome only looks right from
an app bundle built against the current SDK). Consumers pin this repo by
revision in their `Package.swift` and `Package.resolved` (rules_swift_package_manager);
bump both after pushing.
