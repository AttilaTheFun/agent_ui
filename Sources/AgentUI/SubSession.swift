/// A conversation opened from the one on the page: a fork of it, a branch
/// of it, a side question about it, or a subagent its agent sent off. Its
/// row above the composer and its capsule in a list show it; the app says
/// what it is and what opening and ending it do.
public struct SubSession: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        /// A copy of the conversation that goes on by itself.
        case fork
        /// A copy of the conversation up to a point, gone on from there.
        case branch
        /// Questions about the conversation that do not go into it.
        case side
        /// An agent the conversation's agent sent off with a task.
        case subagent

        /// What it is, in a word or two.
        public var label: String {
            switch self {
            case .fork: "Fork"
            case .branch: "Branch"
            case .side: "Side question"
            case .subagent: "Subagent"
            }
        }

        public var symbol: String {
            switch self {
            case .fork: "arrow.triangle.branch"
            case .branch: "arrow.uturn.left"
            case .side: "text.bubble"
            case .subagent: "person.2"
            }
        }
    }

    public var id: String
    public var kind: Kind
    /// Its name: a fork's title, a subagent's task, a side question's
    /// latest question.
    public var title: String
    /// One line under the name: what was said last, or what it is doing.
    public var detail: String?
    /// It is working on something: the row spins.
    public var working: Bool

    public init(id: String, kind: Kind, title: String, detail: String? = nil, working: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.working = working
    }
}
