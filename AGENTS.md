# AgentUI, for agents

Chat interfaces as SwiftUI packages, consumed by Visor
(github.com/AttilaTheFun/visor) and other apps. Read `README.md` first for
what the pieces are.

## Changes

This repo is public. Every change to `main` goes through a pull request:
`main` is protected, direct pushes are rejected, and the CI check (the
tests) must pass before a pull request can merge. Keep each pull request
to one focused change, and say in it how the change was verified.

## Layout

- `Package.swift` at the root: the five products (InboxUI, MessagesUI,
  AgentUI, MarkdownViews, NavigationUI), the shared `MessagesCore` target, the
  tests, and `ExampleData` (the examples' fake store). Nothing else.
- `Sources/MessagesCore/`: the model values, MessagesTheme, the native
  styles, Avatar, MessagesPlatform — what the inbox and the thread share;
  re-exported by InboxUI and MessagesUI.
- `Sources/InboxUI/`: InboxView. `Sources/MessagesUI/`: ThreadView,
  MessageView, MessageComposer, ConversationTitle, MacConversationTitlebar.
  `Sources/AgentUI/`: AgentView, TranscriptView and its rows, AgentComposer.
  `Sources/MarkdownViews/`: MarkdownText and its parser (blocks, inline
  spans, tables), re-exported by AgentUI.
  `Sources/NavigationUI/`: SplitView, InspectorView. A file per type, named
  after it; `View+Topic.swift` for what a target adds to `View`.
- `Tests/AgentUIPackageTests/`: XCTest, `swift test`.
- `Examples/`: the four example apps as an Xcode project generated from
  `project.yml` with XcodeGen, plus `ExampleData`. Run them from Xcode;
  do not add `swift run` executables back (see Examples/README.md for why).

## Rules

- Every target imports SwiftUI and nothing else. No app code, no Bazel, no
  third-party dependencies. It is built here against Apple's SwiftUI and
  elsewhere (wasm, Android, Linux, Windows) against a
  reimplementation of the same API, so:
  - Use only SwiftUI API that exists on iOS 18 / macOS 15, behind
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
- The manifest stays in the Swift 5 language mode, because the other
  SwiftUIs these sources build against are not ready for 6; CI holds the
  code to the Swift 6 mode with warnings as errors (`swift test -Xswiftc
  -swift-version -Xswiftc 6 -Xswiftc -warnings-as-errors`), so run that
  before pushing. No `@unchecked Sendable`, and no shared singletons for
  view state: state a row needs from its thread goes through the
  environment (`openedTranscriptImage`).
- Views are main-actor isolated by their conformance to `View`, on Apple's
  SwiftUI and on Isomer's (since Isomer 0.14), so a view needs no explicit
  `@MainActor`, and should not carry one. What a host lends
  (`TranscriptActions`, `TranscriptImages`) is `@MainActor` state. No
  `nonisolated(unsafe)` anywhere.
- One public or internal type per file, named after it; only nested types
  (`Foo.Bar`) and `private`/`fileprivate` helpers share a file.
- A delayed step in a view (`settle`, the arrival of rows, a send) keeps
  its task and cancels the one before it, so two in a row do not cut
  each other short. The delays themselves are measured against recordings
  (Visor's `tools/probes/frames/send_motion.sh`); do not change one
  without measuring again.
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

## A release's proof

A release's draft comes with a proof of its demo apps, filed in the review
store by commit, as Isomer's and OS Server's are: `Tools/proof.sh
<version>` builds the four example apps for the iPhone simulator (XcodeGen,
then xcodebuild), launches each and pictures its first screen into
`.proof/review-ios` with a manifest; from a reviews checkout,
`bazel run //reviews/harnesses:publish_proof -- runs <agent_ui>/.proof
--commit <sha>` files it. Make it on the release's commit.

## Verifying

`swift build && swift test` for the library (and the Swift 6 line above). For anything visual, run an
example app from the Xcode project (the Mac chrome only looks right from
an app bundle built against the current SDK). Releases are tagged
`vMAJOR.MINOR.PATCH` (v0.36.1). Consumers pin this repo by version in their
`Package.swift` and `Package.resolved` (rules_swift_package_manager); a
branch in development may pin a revision, a release may not — nor may this
repo's own release pin anything but released versions (CI's `pins` job on
main, `Tools/released_pins.sh`). SwiftPM will not resolve a package pinned
by version whose own dependencies are pinned by revision.

## The repository's icon

`.github/AgentUI.icon` (Icon Composer) and its rendering, `.github/icon.png`,
where Reviews and other tools look for a repository's icon. Rendered with
`ictool` (in Xcode's Icon Composer.app, Contents/Executables):

    ictool .github/AgentUI.icon --export-image --output-file .github/icon.png \
        --platform iOS --rendition Default --width 512 --height 512 --scale 1

No README in .github: GitHub would show it as the repository's.
