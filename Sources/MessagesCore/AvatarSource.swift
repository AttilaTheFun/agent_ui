import Foundation

/// What to draw in an avatar's circle.
public enum AvatarSource: Hashable, Sendable {
    /// The first letter of a name.
    case initial(String)
    /// An SF Symbol (the "person.fill" of a new conversation).
    case symbol(String)
    /// A picture.
    case image(URL)
}
