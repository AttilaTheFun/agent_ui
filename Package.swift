// swift-tools-version: 5.9

// AgentUI: chat interfaces as SwiftUI packages — Messages.app's inbox and
// thread, an agent's transcript and composer in the Claude app's shape, and
// the container views (split view, inspector) that hold them — with the data
// and the navigation left to the app. Every target imports SwiftUI and
// nothing else, so it builds against Apple's SwiftUI here and against a
// reimplementation of the same API elsewhere.
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
        // The examples' fake data source, so the Xcode example apps can link it.
        .library(name: "ExampleData", targets: ["ExampleData"]),
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
        .testTarget(name: "AgentUIPackageTests", dependencies: ["AgentUI"]),
        .testTarget(name: "MessagesUIPackageTests", dependencies: ["InboxUI", "MessagesUI", "NavigationUI"]),
        // The examples' shared data. The example apps themselves are Xcode
        // targets (Examples/AgentUIExamples.xcodeproj): an app bundle is
        // what gives them the current macOS chrome and an iOS destination.
        .target(name: "ExampleData", dependencies: ["InboxUI", "MessagesUI"], path: "Examples/ExampleData"),
    ]
)
