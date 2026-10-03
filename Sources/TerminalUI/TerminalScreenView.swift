import SwiftUI

/// A terminal, drawn in SwiftUI from its screen's frame: a grid of
/// monospaced runs on their backgrounds, and the cursor. It sizes the
/// screen to fit (`TerminalScreen.onResize` tells the app), takes typing
/// through a field of its own (so a phone's keyboard comes up when the
/// terminal is tapped), keys like the arrows and Escape where the platform
/// reports key presses, and a row of those keys on a phone. Dragging
/// scrolls back through what has gone off the top.
public struct TerminalScreenView: View {
    @ObservedObject var screen: TerminalScreen
    let fontSize: CGFloat
    let keyBar: Bool
    let paste: (() -> String?)?
    /// One cell, measured from the font.
    @State private var cell: CGSize = .zero
    /// The field's text: always the sentinel, between keystrokes.
    @State private var typed = TerminalScreenView.sentinel
    @FocusState private var focused: Bool
    /// Control, held from the key bar for the next key.
    @State private var control = false
    /// How far a scroll has dragged that has not yet moved a whole row.
    @State private var dragged: CGFloat = 0

    /// - Parameters:
    ///   - keyBar: a row of Escape, Control, Tab and the arrows under the
    ///     terminal, for a keyboard without them (a phone's).
    ///   - paste: what the pasteboard holds, for the key bar's Paste and
    ///     Command-V; the app has the pasteboard, the view does not.
    public init(screen: TerminalScreen, fontSize: CGFloat = 13, keyBar: Bool = false, paste: (() -> String?)? = nil) {
        self.screen = screen
        self.fontSize = fontSize
        self.keyBar = keyBar
        self.paste = paste
    }

    /// What the field holds between keystrokes, so a deletion shows as the
    /// sentinel going.
    static let sentinel = " "

    private var font: Font { .system(size: fontSize, design: .monospaced) }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    screen.frame.background
                    if cell.width > 0 {
                        grid
                        cursor
                    }
                    field
                }
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
                .gesture(scrolling)
                .onChange(of: proxy.size, initial: true) { fit(proxy.size) }
                .onChange(of: cell) { fit(proxy.size) }
            }
            .clipped()
            if keyBar { keys }
        }
        .background(measure)
    }

    // MARK: Drawing

    private var grid: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(screen.frame.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.runs.enumerated()), id: \.offset) { _, run in
                        Text(run.text)
                            .font(font)
                            .bold(run.bold)
                            .italic(run.italic)
                            .underline(run.underline)
                            .strikethrough(run.strikethrough)
                            .foregroundColor(run.faint ? run.foreground.opacity(0.6) : run.foreground)
                            .lineLimit(1)
                            // Laid out by cells, whatever the glyphs measure.
                            .fixedSize()
                            .frame(width: CGFloat(run.cells) * cell.width, height: cell.height, alignment: .leading)
                            .background(run.background)
                    }
                }
                .frame(height: cell.height, alignment: .leading)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var cursor: some View {
        let cursor = screen.frame.cursor
        if cursor.visible {
            Rectangle()
                .fill(cursor.color.opacity(focused ? 0.6 : 0.3))
                .frame(width: cursor.shape == .bar ? 2 : cell.width, height: cursor.shape == .underline ? 2 : cell.height)
                .offset(x: CGFloat(cursor.col) * cell.width,
                        y: CGFloat(cursor.row) * cell.height + (cursor.shape == .underline ? cell.height - 2 : 0))
                .allowsHitTesting(false)
        }
    }

    /// One cell's size: twenty capitals of the font, measured once.
    private var measure: some View {
        Text(String(repeating: "M", count: 20))
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .hidden()
            .background(GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size, initial: true) { _, size in
                    cell = CGSize(width: size.width / 20, height: size.height)
                }
            })
    }

    /// The screen takes as many whole cells as fit.
    private func fit(_ size: CGSize) {
        guard cell.width > 0, cell.height > 0 else { return }
        screen.resize(cols: Int(size.width / cell.width), rows: Int(size.height / cell.height))
    }

    /// Dragging down shows what went off the top; up comes back.
    private var scrolling: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard cell.height > 0 else { return }
                let moved = value.translation.height - dragged
                let rows = Int(moved / cell.height)
                guard rows != 0 else { return }
                screen.scroll(by: -rows)
                dragged += CGFloat(rows) * cell.height
            }
            .onEnded { _ in dragged = 0 }
    }

    // MARK: Typing

    /// The field the keyboard types into, at the cursor so a phone's
    /// suggestions and an input method's candidates appear by it.
    private var field: some View {
        TextField("", text: $typed, axis: .vertical)
            .focused($focused)
            .autocorrectionDisabled()
            .terminalKeys(handle)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .offset(x: CGFloat(screen.frame.cursor.col) * cell.width, y: CGFloat(screen.frame.cursor.row) * cell.height)
            .onChange(of: typed) { _, now in take(now) }
            .accessibilityLabel("Terminal input")
    }

    /// What the field's text became: the keystrokes that made it, sent,
    /// and the field back to the sentinel.
    private func take(_ now: String) {
        guard now != Self.sentinel else { return }
        if now.hasPrefix(Self.sentinel) {
            send(String(now.dropFirst(Self.sentinel.count)))
        } else {
            // The sentinel was deleted: a backspace.
            screen.press("Backspace")
            send(now)
        }
        typed = Self.sentinel
    }

    /// Typed text: a line break is Enter, and a held Control applies to
    /// the first character.
    private func send(_ text: String) {
        var plain = ""
        for character in text {
            if character == "\n" || character == "\r" {
                screen.type(plain)
                plain = ""
                screen.press("Enter")
            } else if control {
                screen.type(plain)
                plain = ""
                screen.press(String(character).lowercased(), modifiers: .control)
                control = false
            } else {
                plain.append(character)
            }
        }
        screen.type(plain)
    }

    /// A key press, where the platform reports them: the keys that are not
    /// text, and text with a modifier, go to the terminal here; plain text
    /// is left to the field.
    private func handle(_ key: TerminalKey) -> Bool {
        var modifiers = key.modifiers
        if modifiers.contains(.command) {
            guard key.character == "v", let text = paste?() else { return false }
            screen.paste(text)
            return true
        }
        if let name = key.name {
            if control { modifiers.insert(.control); control = false }
            screen.press(name, modifiers: modifiers)
            return true
        }
        if let character = key.character, control || modifiers.contains(.control) || modifiers.contains(.option) {
            if control { modifiers.insert(.control); control = false }
            return screen.press(String(character).lowercased(), modifiers: modifiers)
        }
        return false
    }

    // MARK: Keys a phone's keyboard does not have

    private var keys: some View {
        HStack(spacing: 6) {
            key("esc") { screen.press("Escape") }
            Button { control.toggle() } label: { Text("ctrl").frame(minWidth: 28) }
                .buttonStyle(.bordered)
                .tint(control ? .accentColor : nil)
                .accessibilityLabel("Control")
                .accessibilityAddTraits(control ? .isSelected : [])
            key("tab") { screen.press("Tab") }
            key("←") { screen.press("ArrowLeft") }
            key("↓") { screen.press("ArrowDown") }
            key("↑") { screen.press("ArrowUp") }
            key("→") { screen.press("ArrowRight") }
            if let paste {
                Spacer(minLength: 0)
                key("paste") { if let text = paste() { screen.paste(text) } }
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(minWidth: 22) }
            .buttonStyle(.bordered)
    }
}
