/// Text helpers without Foundation (which not every SwiftUI's host has).
public enum AgentText {
    public static func isBlank(_ text: String) -> Bool {
        text.allSatisfy { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" }
    }

    public static func trimmed(_ text: String) -> String {
        var scalars = Substring(text)
        while let first = scalars.first, first.isWhitespace || first.isNewline { scalars = scalars.dropFirst() }
        while let last = scalars.last, last.isWhitespace || last.isNewline { scalars = scalars.dropLast() }
        return String(scalars)
    }
}
