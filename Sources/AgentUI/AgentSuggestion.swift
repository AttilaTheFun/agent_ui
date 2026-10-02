/// A way to finish what is being typed, offered above the field: a slash
/// command, for one. Picking it puts `text` in the draft.
public struct AgentSuggestion: Identifiable, Equatable, Sendable {
    public var id: String { text }
    /// What the draft becomes ("/compact ").
    public var text: String
    /// What the row says ("/compact").
    public var title: String
    /// One line on what it does.
    public var detail: String

    public init(text: String, title: String, detail: String = "") {
        self.text = text
        self.title = title
        self.detail = detail
    }
}
