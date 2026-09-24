# AgentUI

Chat interfaces as SwiftUI packages: Messages.app's inbox and thread, an
agent's transcript and composer in the Claude app's shape, and the container
views that hold them — with the data and the navigation left to the app.

Every product imports SwiftUI and nothing else. On Apple platforms that is
the system framework; elsewhere (wasm, Linux, Android, Windows) it is a
reimplementation of the same API, so one source builds everywhere.

## Products

- **InboxUI** — `InboxView`, the conversation list from
  `[ConversationSummary]` with a selection binding, mimicking Messages.app's
  inbox page; `InboxCell` on its own.
- **MessagesUI** — `ThreadView`, Messages.app's thread page: the messages
  (`MessageView`, one per `MessageItem` — text, image, video, album, or
  `custom(kind:payload:)` drawn by your `messageContentRenderer`), the
  `MessageComposer` with `ComposerAccessories`, the `ConversationTitle`;
  `MacConversationTitlebar` puts the title in the Mac's titlebar.
- **AgentUI** — `AgentView`, the agent's chat page: the `TranscriptView`
  (user and assistant bubbles, tool activity rows, the streaming reply, an
  empty state) over the `AgentComposer` (attachments, a growing field, the
  app's pills and buttons, send or stop). Ported from the Universal UI
  Playground; Visor drives it from a remote Claude Code or Codex session.
- **NavigationUI** — `SplitView` (sidebar, detail, inspector; the app's
  column bindings), `InspectorView` (a pane's frame with the X),
  `adaptiveInspector(isPresented:compact:)` (an inspector, or a sheet on a
  phone), `EmptyDetail`.

InboxUI and MessagesUI re-export **MessagesCore**: the model values
(`ConversationSummary`, `MessageItem`, `MessageContent`), `MessagesTheme`
(`.messagesTheme(_:)`), `Avatar`, `MessagesTime`, and the native styles.

## Examples

`Examples/AgentUIExamples.xcodeproj` has four app targets for iOS and macOS:
StackExample (a NavigationStack: inbox pushes thread), SplitExample
(Messages' split view with the inspector and the Mac's titlebar title),
TabbedExample (messages as one tab, a stack on a phone and a split view
wider), and AgentExample (`AgentView` on a fake agent). See Examples/README.md.

## Platforms

iOS 17 and macOS 14 are built and tested here. tvOS and watchOS are not
supported: the layout leans on NavigationSplitView, inspectors and
keyboard-driven composers that do not exist there. Non-Apple platforms
build when a `SwiftUI` module of the same API is on the search path.

## Consumers

[Visor](https://github.com/AttilaTheFun/visor) uses AgentUI and
NavigationUI, pinning this repo by revision through
rules_swift_package_manager. InboxUI and MessagesUI serve messaging apps;
any SwiftPM or Bazel project can depend on the products it needs.

## License

Apache 2.0; see LICENSE.
