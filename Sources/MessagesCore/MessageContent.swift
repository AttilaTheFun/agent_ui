/// What a message carries. Text is the common case; media renders in
/// bubbles of its own; `custom` is anything else, drawn by a renderer the
/// app supplies (`messageContentRenderer`).
public enum MessageContent: Hashable, Sendable {
    case text(String)
    case image(MediaItem)
    case video(MediaItem)
    case album([MediaItem])
    /// An app-defined kind with an opaque payload (JSON, an id, anything).
    case custom(kind: String, payload: String)
}
