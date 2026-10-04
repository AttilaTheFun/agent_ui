// swift-tools-version: 5.9

// AgentUI: chat interfaces as SwiftUI packages — Messages.app's inbox and
// thread, an agent's transcript and composer in the Claude app's shape, and
// the container views (split view, inspector) that hold them, and a terminal
// — with the data and the navigation left to the app. Every target imports
// SwiftUI and nothing else (TerminalUI also SwiftTerm's portable emulator),
// so it builds against Apple's SwiftUI here and against a reimplementation
// of the same API elsewhere.
import PackageDescription

let package = Package(
    name: "AgentUI",
    platforms: [.iOS("18.0"), .macOS("15.0")],
    products: [
        // The inbox: `InboxView`, `InboxCell` (Messages.app's conversation list).
        .library(name: "InboxUI", targets: ["InboxUI"]),
        // The thread: `ThreadView`, `MessageView`, `MessageComposer`, the title.
        .library(name: "MessagesUI", targets: ["MessagesUI"]),
        // The agent: `AgentView`, `TranscriptView`, `AgentComposer`.
        .library(name: "AgentUI", targets: ["AgentUI"]),
        // The containers: `SplitView`, `InspectorView`, `EmptyDetail`.
        .library(name: "NavigationUI", targets: ["NavigationUI"]),
        // A terminal: `TerminalScreen` (SwiftTerm's emulator) drawn by
        // `TerminalScreenView` in SwiftUI.
        .library(name: "TerminalUI", targets: ["TerminalUI"]),
        // The examples' fake data source, so the Xcode example apps can link it.
        .library(name: "ExampleData", targets: ["ExampleData"]),
    ],
    dependencies: [
        // SwiftTerm's portable core — the emulator, not its UIKit/AppKit
        // views — upstream, at the merge that builds it for Android
        // (migueldeicaza/SwiftTerm#733). A Bazel build, which runs no
        // SwiftPM plugins, patches in what its build plugin generates.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", revision: "839d4fa1ffd4ea2ede5664e1c1fb13cc5771e11a"),
    ],
    targets: [
        // What the inbox and the thread share: the model values, the theme,
        // the avatar, the native styles. Re-exported by both, so an app that
        // imports either sees `ConversationSummary` and friends.
        .target(name: "MessagesCore"),
        .target(name: "InboxUI", dependencies: ["MessagesCore"]),
        .target(name: "MessagesUI", dependencies: ["MessagesCore"]),
        .target(name: "AgentUI"),
        .target(name: "NavigationUI"),
        .target(name: "TerminalUI", dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")]),
        .testTarget(name: "AgentUIPackageTests", dependencies: ["AgentUI"]),
        .testTarget(name: "TerminalUIPackageTests", dependencies: ["TerminalUI"]),
        .testTarget(name: "MessagesUIPackageTests", dependencies: ["InboxUI", "MessagesUI", "NavigationUI"]),
        // The examples' shared data. The example apps themselves are Xcode
        // targets (Examples/AgentUIExamples.xcodeproj): an app bundle is
        // what gives them the current macOS chrome and an iOS destination.
        .target(name: "ExampleData", dependencies: ["InboxUI", "MessagesUI"], path: "Examples/ExampleData"),
    ]
)
