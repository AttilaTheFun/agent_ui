/// A key press as the terminal takes it: a key that is not text, by its
/// browser name ("Enter", "ArrowUp"), or the character of the key; and the
/// modifiers held.
struct TerminalKey {
    var name: String?
    var character: Character?
    var modifiers: TerminalModifiers
}
