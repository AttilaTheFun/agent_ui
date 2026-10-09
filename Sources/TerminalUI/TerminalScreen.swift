import Observation
import SwiftTerm
import SwiftUI

/// A terminal's state, as SwiftTerm's emulator keeps it: what the program
/// on the far side drew (fed in as bytes), and what typing encodes to (sent
/// back out). The app moves the bytes — `feed` what arrives, send what
/// `onInput` gives — and `TerminalScreenView` draws `frame`.
///
/// Main-actor state, lent to the view by the app, like `TranscriptActions`.
/// Everything that touches the emulator holds its lock, as SwiftTerm asks
/// of a host that drives it without its own views.
/// Observed (Observation) through `frame` alone: what a view draws.
@MainActor
@Observable
public final class TerminalScreen {
    /// What the terminal shows now.
    public private(set) var frame: TerminalFrame
    @ObservationIgnored public private(set) var cols: Int
    @ObservationIgnored public private(set) var rows: Int
    /// Whether a view has given it its size yet; until then `cols` and
    /// `rows` are only what it was made with.
    @ObservationIgnored public private(set) var sized = false
    /// Bytes for the program: what was typed, encoded as the terminal's
    /// modes say, and the terminal's answers to the program's queries.
    @ObservationIgnored public var onInput: (([UInt8]) -> Void)?
    /// The screen took a new size (the view laid out): the program should
    /// be told.
    @ObservationIgnored public var onResize: ((_ cols: Int, _ rows: Int) -> Void)?

    private let outlet = TerminalOutlet()
    private let terminal: Terminal
    /// A frame is owed: drawn once per turn of the main actor, however many
    /// chunks arrive in it.
    @ObservationIgnored private var drawing: Task<Void, Never>?

    public init(cols: Int = 80, rows: Int = 24) {
        self.cols = max(2, cols)
        self.rows = max(1, rows)
        terminal = Terminal(delegate: outlet, options: TerminalOptions(cols: max(2, cols), rows: max(1, rows)))
        frame = .blank(cols: max(2, cols), rows: max(1, rows))
        draw()
    }

    /// Output from the program.
    public func feed(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        terminal.terminalLock.withLock { terminal.feed(byteArray: bytes) }
        flush()
        drawSoon()
    }

    /// Back to a fresh screen: what follows is the whole screen again (a
    /// replay), not more of it.
    public func startOver() {
        terminal.terminalLock.withLock { terminal.resetToInitialState() }
        flush()
        draw()
    }

    /// The view's size in cells. The emulator reflows to it, and the app is
    /// told — the first time, whether or not it changed — so the program
    /// draws for it too.
    public func resize(cols: Int, rows: Int) {
        let cols = max(2, cols), rows = max(1, rows)
        guard cols != self.cols || rows != self.rows || !sized else { return }
        sized = true
        self.cols = cols
        self.rows = rows
        terminal.terminalLock.withLock { terminal.resize(cols: cols, rows: rows) }
        draw()
        onResize?(cols, rows)
    }

    /// Text the user typed, as typing (not a paste).
    public func type(_ text: String) {
        guard !text.isEmpty else { return }
        terminal.terminalLock.withLock { _ = terminal.sendHostText(text) }
        flush()
    }

    /// A key that is not text, or text with Control, Option or Command
    /// held. `key` is a browser key name — "Enter", "Backspace", "Tab",
    /// "Escape", "ArrowUp", "Home", "PageDown", "Delete", "F1" — or the
    /// character itself. Returns false when it encodes to nothing, so the
    /// caller can treat it as plain text.
    @discardableResult
    public func press(_ key: String, modifiers: TerminalModifiers = []) -> Bool {
        let sent = terminal.terminalLock.withLock {
            terminal.sendHostKey(key: key, code: "", modifiers: modifiers.rawValue, eventType: 1, text: nil) == 1
        }
        flush()
        return sent
    }

    /// Text pasted: bracketed when the program asked for that.
    public func paste(_ text: String) {
        guard !text.isEmpty else { return }
        terminal.terminalLock.withLock { _ = terminal.sendHostTextPaste(text) }
        flush()
    }

    /// Scrolls back through what has gone off the top (negative) or toward
    /// the present (positive), by rows.
    public func scroll(by rows: Int) {
        guard rows != 0 else { return }
        terminal.scrollViewport(rows)
        draw()
    }

    /// Sends what the emulator queued for the program.
    private func flush() {
        let bytes = outlet.take()
        if !bytes.isEmpty { onInput?(bytes) }
    }

    private func drawSoon() {
        guard drawing == nil else { return }
        drawing = Task { [weak self] in
            await Task.yield()
            self?.drawing = nil
            self?.draw()
        }
    }

    private func draw() {
        let snapshot = terminal.makeRenderSnapshot(scope: .full)
        terminal.terminalLock.withLock { terminal.clearUpdateRange() }
        let next = TerminalFrame(snapshot)
        if next != frame { frame = next }
    }
}
