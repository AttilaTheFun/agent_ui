# Examples

Three ways to put the Messages pieces together, all on `ExampleData`, a fake store
with an echo reply, a fourteen-message history per thread, and one custom
message kind ("build"):

- **StackExample**: a NavigationStack, the phone-only shape. The inbox
  pushes the thread; the title presents the details as a sheet.
- **SplitExample**: Messages.app's split view with the inspector and, on
  the Mac, the titlebar title.
- **TabbedExample**: messages as one tab of a tabbed app; a stack when
  compact, the split view when wide.

And one for AgentUI:

- **AgentExample**: `AgentView` alone, on a fake agent that streams an echo
  back after an activity line and a tool row.

Open `AgentUIExamples.xcodeproj` and run a scheme: each example has an
`_iOS` and an `_macOS` target (StackExample_iOS, SplitExample_macOS, …)
sharing one set of sources. They are app targets on purpose: a bare `swift run`
binary is stamped with its deployment target as its SDK, and macOS 26
gives such a binary the pre-26 chrome (no glass, a title bar that clips
the thread's title), which is not what the package looks like.

The project is generated from `project.yml` with XcodeGen
(`brew install xcodegen`, then `xcodegen generate --spec
Examples/project.yml`, then open `Examples/AgentUIExamples.xcodeproj`).
The project is generated, not committed: edit the spec.
