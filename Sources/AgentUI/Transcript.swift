// The agent's transcript: user/assistant bubbles, tool activity rows, the
// streaming reply, and an empty state — the same rows in both Playgrounds
// and in Visor. Each app maps its chat model to `TranscriptMessage`.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UIKit)
import Foundation
import UIKit
#elseif canImport(AppKit)
import AppKit
import Foundation
#endif

public struct TranscriptMessage: Identifiable, Equatable {
    public enum Role: Equatable { case user, assistant, tool }

    public var id: String
    public var role: Role
    public var text: String
    /// An assistant turn's tool calls, as activity labels ("Building").
    public var activities: [String]
    /// A tool result's tool name (build / crash / import / web_search / …).
    public var toolName: String?
    /// Images to show with the message (URLs the platform's image loader displays).
    public var imageURLs: [String]
    /// Each image's size in pixels, by position in `imageURLs`, when the
    /// app knows it before the bytes arrive: the row is then laid out at
    /// its final size from the first frame instead of reshaping itself
    /// as each picture lands. Nil where unknown.
    public var imageSizes: [CGSize?]

    public init(id: String, role: Role, text: String, activities: [String] = [], toolName: String? = nil,
                imageURLs: [String] = [], imageSizes: [CGSize?] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.activities = activities
        self.toolName = toolName
        self.imageURLs = imageURLs
        self.imageSizes = imageSizes
    }

    /// The known size of the image at `index`, if any.
    public func imageSize(at index: Int) -> CGSize? {
        index < imageSizes.count ? imageSizes[index] : nil
    }
}

/// The scrolling transcript, pinned to its bottom as messages arrive.
/// An assistant message as it streams, or streamed and not yet on the
/// record: its own row, by the message's id, never run together with the
/// message before it.
public struct StreamedMessage: Identifiable, Equatable {
    public let id: String
    public let text: String
    public init(id: String, text: String) { self.id = id; self.text = text }
}

public struct TranscriptView: View {
    /// Whether rows have been shown once: what turns the animations on.
    @State private var populated = false
    /// Every row the thread has drawn.
    @State private var seen: Set<String> = []
    let messages: [TranscriptMessage]
    let streams: [StreamedMessage]
    let activity: String?
    /// The turn's streamed status so far — tool calls, subagents, shells,
    /// thinking — that is not part of the record: a footer under the
    /// thread, the newest line live. Empty between turns.
    let status: [ActivityItem]
    let error: String?
    let emptyTitle: String
    let emptyBody: String
    let emptyFootnote: String?
    /// Given when the thread goes back further than what is shown: a row
    /// at the top that asks for more.
    let loadEarlier: (() -> Void)?
    /// How much of the bottom the composer covers. When it grows — a
    /// message running to more lines — the last row would slip under it;
    /// the list is pinned to its bottom again as this changes.
    let bottomInset: CGFloat

    public init(messages: [TranscriptMessage], streams: [StreamedMessage] = [], activity: String?, status: [ActivityItem] = [],
                error: String?, emptyTitle: String = "What should we build?", emptyBody: String, emptyFootnote: String? = nil,
                loadEarlier: (() -> Void)? = nil, bottomInset: CGFloat = 0) {
        self.loadEarlier = loadEarlier
        self.bottomInset = bottomInset
        self.messages = messages
        self.streams = streams
        self.status = status
        self.activity = activity
        self.error = error
        self.emptyTitle = emptyTitle
        self.emptyBody = emptyBody
        self.emptyFootnote = emptyFootnote
    }

    @ObservedObject private var opened = TranscriptImageOpen.shared
    @ObservedObject private var openedCalls = ToolCallsOpen.shared

    public var body: some View {
        #if canImport(UIKit) || canImport(AppKit)
        EdgeScrolled { toBottom in transcript(toBottom) }
        #else
        ScrollViewReader { proxy in transcript { proxy.scrollTo("bottom", anchor: .bottom) } }
        #endif
    }

    /// The transcript, given how to scroll it to its bottom.
    private func transcript(_ toBottom: @escaping () -> Void) -> some View {
        // A lazy stack in a scroll view anchored at its bottom edge: rows
        // are made as they come on screen, and the bottom stays where it
        // is whatever changes size — a row arriving or growing, the
        // keyboard, the composer — with nothing scrolled by hand. A List
        // sizes its rows by estimate and corrects them as they are laid
        // out, so a scroll to a row landed short and the thread jumped.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let loadEarlier, !messages.isEmpty {
                    Button(action: loadEarlier) {
                        Text("Load earlier messages").font(.footnote).foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .transcriptCell()
                    .id("earlier")
                }
                if messages.isEmpty { emptyState }
                // The record, a run of tool calls folded into one row that
                // opens a sheet; then the replies still being written, so
                // a reply's finished row takes its stream's place.
                let arriving = arrivingIDs
                ForEach(rows) { block in
                    Group {
                        // A reply is one view whether it is being written
                        // or on the record, so it keeps showing its words
                        // at its own pace across the change.
                        if let reply = block.reply {
                            ReplyRow(text: reply.text, streaming: reply.streaming)
                        } else {
                            Arriving(arriving.contains(block.id)) {
                                switch block {
                                case .message(let message): TranscriptRow(message: message)
                                case .calls(let run): ToolCallsRow(run: run)
                                case .stream: EmptyView()
                                }
                            }
                        }
                    }
                    .transcriptCell()
                    .id(block.id)
                }
                // The footer: what is not the record — what the turn is
                // doing, an error — and the room above the composer.
                EphemeralFooter(status: status, activity: activity, error: error)
                    .transcriptCell()
                    .id("bottom")
            }
        }
        .bottomAnchored()
        .onAppear { if !messages.isEmpty { seen = Set(rows.map(\.id)); populated = true } }
        .onChange(of: rows.map(\.id)) { ids in
            if !populated, !messages.isEmpty { populated = true }
            seen.formUnion(ids)
        }
        .sheet(isPresented: Binding(get: { opened.url != nil },
                                    set: { if !$0 { opened.url = nil } })) {
            if let url = opened.url { ImageViewer(url: url) }
        }
        .sheet(isPresented: Binding(get: { openedCalls.run != nil },
                                    set: { if !$0 { openedCalls.run = nil } })) {
            if let run = openedCalls.run { ToolCallsSheet(run: run) }
        }
        // A message sent is read at the bottom, wherever the thread was.
        .onChange(of: messages.last?.id) { _ in
            if messages.last?.role == .user { toBottom() }
        }
    }

    /// The rows new at the end of the thread since it was last drawn:
    /// they grow into place. Not the rows it opened with, nor those put
    /// before the first (earlier messages loaded).
    private var arrivingIDs: Set<String> {
        guard populated else { return [] }
        let ids = rows.map(\.id)
        guard let last = ids.lastIndex(where: seen.contains) else { return [] }
        return Set(ids[(last + 1)...])
    }

    /// The record's blocks, then the streams it does not carry yet. What
    /// is said and not on the record yet is the composer's to show.
    private var rows: [TranscriptBlock] {
        let carried = Set(messages.map(\.id))
        return TranscriptBlock.blocks(messages) + streams.filter { !carried.contains($0.id) }.map(TranscriptBlock.stream)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emptyTitle).font(.title3.bold())
            Text(emptyBody).foregroundColor(.secondary)
            if let emptyFootnote {
                Text(emptyFootnote).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

/// What the transcript draws in one slot: a message, or a run of tool
/// calls folded into one row. A run is consecutive messages that are only
/// tool calls and their results — an assistant row with activities and no
/// words, a tool row with no picture — and is folded into one row however
/// many calls it holds, so the row keeps one identity as the run grows.
public enum TranscriptBlock: Identifiable {
    case message(TranscriptMessage)
    case calls([TranscriptMessage])
    /// A reply still streaming, under the id its finished message will
    /// have: when the record carries that message, the block becomes a
    /// `.message` with the same id in the same place, and the row changes
    /// rather than one going and another arriving.
    case stream(StreamedMessage)

    /// A reply in words only — being written, or on the record — drawn by
    /// the one view that shows its words at its own pace.
    var reply: (text: String, streaming: Bool)? {
        switch self {
        case .stream(let stream): (stream.text, true)
        case .message(let message) where message.role == .assistant && message.activities.isEmpty && !message.text.isEmpty:
            (message.text, false)
        default: nil
        }
    }

    public var id: String {
        switch self {
        case .message(let message): message.id
        case .calls(let run): "calls-" + (run.first?.id ?? "")
        case .stream(let stream): stream.id
        }
    }

    /// Whether a message is a tool call or a tool result and nothing else.
    static func isCall(_ message: TranscriptMessage) -> Bool {
        switch message.role {
        case .assistant: message.text.isEmpty && !message.activities.isEmpty
        case .tool: message.imageURLs.isEmpty
        case .user: false
        }
    }

    /// The number of calls in a run: one per activity label.
    public static func callCount(_ run: [TranscriptMessage]) -> Int {
        run.reduce(0) { $0 + $1.activities.count }
    }

    public static func blocks(_ messages: [TranscriptMessage]) -> [TranscriptBlock] {
        var out: [TranscriptBlock] = []
        var run: [TranscriptMessage] = []
        func flush() {
            guard !run.isEmpty else { return }
            // A run is one row from its first call, under that call's id,
            // however many follow: the row counts up in place rather than
            // a lone call's row giving way to a group's.
            out.append(.calls(run))
            run = []
        }
        for message in messages {
            if isCall(message) {
                run.append(message)
            } else if message.role == .assistant, !message.text.isEmpty, !message.activities.isEmpty {
                // Words and then calls in one message: the words are a row
                // of their own and the calls start (or join) a run, so a
                // turn that speaks and then works reads as one run of work.
                flush()
                var words = message
                words.activities = []
                out.append(.message(words))
                var calls = message
                calls.id = message.id + "#calls"
                calls.text = ""
                run.append(calls)
            } else {
                flush()
                out.append(.message(message))
            }
        }
        flush()
        return out
    }
}

/// Which run of tool calls is open for inspection, if any. Outside the
/// view tree for the same reason the open picture is.
public final class ToolCallsOpen: ObservableObject, @unchecked Sendable {
    public static let shared = ToolCallsOpen()
    @Published public var run: [TranscriptMessage]?
    private init() {}
}

/// A run of tool calls as one line — "Made 12 tool calls" — behind the
/// same chevron a single call has; tapping opens the sheet that lists them.
public struct ToolCallsRow: View {
    let run: [TranscriptMessage]

    public init(run: [TranscriptMessage]) { self.run = run }

    public var body: some View {
        let count = TranscriptBlock.callCount(run)
        Button {
            ToolCallsOpen.shared.run = run
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right.circle").foregroundColor(.secondary)
                Text("Made \(count) tool call\(count == 1 ? "" : "s")").font(.footnote).foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel("Made \(count) tool calls; opens the list")
    }
}

/// The calls in a run, in order, each with what came back.
public struct ToolCallsSheet: View {
    let run: [TranscriptMessage]
    @Environment(\.dismiss) private var dismiss

    public init(run: [TranscriptMessage]) { self.run = run }

    /// Calls paired with results by order: the nth label with the nth
    /// result row that follows it. A result with no label of its own, or
    /// a label with no result yet, stands alone.
    private var items: [(id: String, label: String?, result: String?)] {
        var labels: [(String, String)] = []
        var results: [(String, String)] = []
        for message in run {
            for (i, label) in message.activities.enumerated() { labels.append((message.id + "#\(i)", label)) }
            if message.role == .tool { results.append((message.id, message.text)) }
        }
        var out: [(id: String, label: String?, result: String?)] = []
        for i in 0..<max(labels.count, results.count) {
            let label = i < labels.count ? labels[i] : nil
            let result = i < results.count ? results[i] : nil
            out.append((id: label?.0 ?? result?.0 ?? "\(i)", label: label?.1, result: result?.1))
        }
        return out
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        if let label = item.label {
                            Text(label).font(.footnote.weight(.semibold))
                        }
                        if let result = item.result, !result.isEmpty {
                            Text(result)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(12)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Tool calls")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 420)
        #endif
    }
}

public struct TranscriptRow: View {
    let message: TranscriptMessage

    public init(message: TranscriptMessage) { self.message = message }

    public var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 6) {
                    if !message.imageURLs.isEmpty {
                        ImageStrip(urls: message.imageURLs, sizes: message.imageSizes, alignment: .trailing)
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.18))
                            .cornerRadius(16)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.horizontal, TranscriptMetrics.edgeInset)
        case .assistant:
            VStack(alignment: .leading, spacing: 6) {
                if !message.text.isEmpty { AssistantBubble(text: message.text, streaming: false) }
                ForEach(message.activities.indices, id: \.self) { index in
                    ActivityRow(label: message.activities[index], running: false)
                }
            }
        case .tool:
            toolRow
        }
    }

    @ViewBuilder private var toolRow: some View {
        let firstLine = message.text.split(separator: "\n").first.map(String.init) ?? ""
        // Whatever the tool was called: if it produced a picture, that is
        // the interesting part of the row. It sits left, with the rest of
        // what the agent says.
        if !message.imageURLs.isEmpty {
            ImageStrip(urls: message.imageURLs, sizes: message.imageSizes, alignment: .leading)
                .padding(.horizontal, TranscriptMetrics.edgeInset)
        }
        switch message.toolName {
        case "screenshot":
            EmptyView()
        case "import":
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down").foregroundColor(.secondary)
                Text(message.text).font(.footnote).foregroundColor(.secondary)
            }
            .padding(.horizontal)
        case "crash":
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                Text(firstLine.isEmpty ? "The app crashed" : firstLine).font(.footnote).foregroundColor(.secondary)
            }
            .padding(.horizontal)
        case "web_search", "fetch_url":
            // The research tools: one line of what came back.
            let failed = message.text.hasPrefix("error")
            HStack(spacing: 6) {
                Image(systemName: failed ? "exclamationmark.triangle" : (message.toolName == "web_search" ? "magnifyingglass" : "globe"))
                    .foregroundColor(failed ? .orange : .secondary)
                Text(String(firstLine.prefix(90))).font(.footnote).foregroundColor(.secondary).lineLimit(1)
            }
            .padding(.horizontal)
        case "build":
            let ok = message.text.hasPrefix("ok")
            HStack(spacing: 6) {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill").foregroundColor(ok ? .green : .red)
                Text(ok ? "Build succeeded" : "Build failed — fixing").font(.footnote).foregroundColor(.secondary)
            }
            .padding(.horizontal)
        default:
            EmptyView()
        }
    }
}

public struct AssistantBubble: View {
    let text: String
    let streaming: Bool

    public init(text: String, streaming: Bool) {
        self.text = text
        self.streaming = streaming
    }

    /// No avatar or glyph beside the text: on a phone the width is the
    /// message's. Ours are the gray bubbles on the right; the agent's is
    /// plain text from the left edge.
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarkdownText(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Nothing to act on until the words have stopped arriving; the
            // room for it is kept while they arrive, so the reply does not
            // grow by it when they stop.
            if !text.isEmpty || streaming {
                MessageActions(text: text)
                    .opacity(streaming ? 0 : 1)
                    .disabled(streaming)
                    .accessibilityHidden(streaming)
            }
        }
        .padding(.horizontal, TranscriptMetrics.edgeInset)
        .opacity(streaming ? 0.85 : 1)
    }
}

/// A reply, shown at a steady pace while it is written. Its words arrive
/// in bursts — a few times a second, several lines at once — and shown as
/// they come the reply would grow, and the thread move, by the burst.
/// Instead the words shown catch up with the words come, a little each
/// frame and faster the further behind, so the reply grows a line at a
/// time at the pace it is written. When the record takes over (the same
/// view, with `streaming` false) the words still to show are shown the
/// same way, and then the reply is the record's, with its actions. A
/// reply that was never streamed here is shown whole.
struct ReplyRow: View {
    let text: String
    let streaming: Bool
    /// How much is shown; nil for all of it.
    @State private var shown: Int?
    /// How much there is to show, and whether more is coming, kept for
    /// the pacing loop (which would otherwise see them as they were when
    /// it began).
    @State private var target = 0
    @State private var writing: Bool

    init(text: String, streaming: Bool) {
        self.text = text
        self.streaming = streaming
        _shown = State(initialValue: streaming ? 0 : nil)
        _target = State(initialValue: text.count)
        _writing = State(initialValue: streaming)
    }

    static let frame: UInt64 = 33_000_000
    /// Characters a frame at most: about 1,300 a second.
    static let fastest = 44

    var body: some View {
        AssistantBubble(text: shown.map { String(text.prefix($0)) } ?? text, streaming: streaming || shown != nil)
            .onChange(of: text.count) { count in target = count }
            .onChange(of: streaming) { value in writing = value }
            .task {
                guard shown != nil else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Self.frame)
                    guard let current = shown else { return }
                    let behind = target - current
                    if behind > 0 {
                        // Faster the further behind, to a steady top speed
                        // (about as fast as a model writes): a burst is
                        // shown over the next moments, not in one.
                        shown = current + min(max(3, behind / 8), Self.fastest)
                    } else if !writing {
                        shown = nil
                        return
                    }
                }
            }
    }
}

/// A row that grows into place when it arrives at the end of the thread:
/// the thread, held at its bottom, slides up by the row's height over a
/// moment rather than all at once. Stepped by hand, not animated: an
/// animation in the scroll view's stack has it re-estimate the rows off
/// screen as it runs, and the thread lurches.
struct Arriving<Content: View>: View {
    let content: Content
    @State private var height: CGFloat = 0
    @State private var progress: CGFloat

    init(_ arriving: Bool, @ViewBuilder content: () -> Content) {
        self.content = content()
        _progress = State(initialValue: arriving ? 0 : 1)
    }

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear { height = geometry.size.height }
                    .onChange(of: geometry.size.height) { value in height = value }
            })
            .frame(height: progress < 1 ? height * progress : nil, alignment: .top)
            .clipped()
            .task {
                guard progress < 1 else { return }
                let steps = 7
                for index in 1...steps {
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    if Task.isCancelled { break }
                    let t = CGFloat(index) / CGFloat(steps)
                    progress = 1 - (1 - t) * (1 - t)
                }
                progress = 1
            }
    }
}

/// What to do with something the agent said: take all of it, or send it
/// on. Selecting part of it is the text's own business — these are for
/// when the whole thing is wanted.
public struct MessageActions: View {
    let text: String
    @State private var copied = false

    public init(text: String) { self.text = text }

    public var body: some View {
        HStack(spacing: 14) {
            Button {
                TranscriptActions.put(text)
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied ? "Copied" : "Copy")
            .accessibilityIdentifier("copy-message")
            share
            Spacer()
        }
        .font(.body.weight(.semibold))
        .foregroundColor(.secondary)
        .padding(.top, 4)
    }

    @ViewBuilder private var share: some View {
        #if canImport(AppKit) || canImport(UIKit)
        ShareLink(item: text) {
            Image(systemName: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share-message")
        #else
        if let hand = TranscriptActions.share {
            Button { hand(text) } label: { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share-message")
        }
        #endif
    }
}

/// The two things a host has to lend the transcript: somewhere to put
/// text, and somewhere to send it. Apple has both of its own.
public enum TranscriptActions {
    nonisolated(unsafe) public static var copy: ((String) -> Void)?
    nonisolated(unsafe) public static var share: ((String) -> Void)?

    static func put(_ text: String) {
        if let copy { copy(text); return }
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

public struct ActivityRow: View {
    let label: String
    let running: Bool
    /// The mark of what kind of thing this is, if any.
    let symbol: String?

    public init(label: String, running: Bool, symbol: String? = nil) {
        self.label = label
        self.running = running
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 8) {
            if running {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle").foregroundColor(.secondary)
            }
            if let symbol {
                Image(systemName: symbol).foregroundColor(.secondary).font(.footnote)
            }
            Text(label).font(.footnote).foregroundColor(.secondary).lineLimit(2)
        }
        .padding(.horizontal)
    }
}

/// Under the record: the ephemeral state, and the gap above the composer.
struct EphemeralFooter: View {
    let status: [ActivityItem]
    let activity: String?
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !status.isEmpty || activity != nil {
                ActivityList(items: status, current: activity)
                    .padding(.vertical, 6)
            }
            if let error {
                Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal)
            }
            Color.clear.frame(height: TranscriptMetrics.bottomGap)
        }
    }
}

/// What the turn is doing, in one line: the latest thing still running,
/// else the task under way, else the current label (thinking, the road to
/// the computer). One line whatever the turn does, so the footer keeps its
/// height as calls come and go; the calls themselves are the record's,
/// grouped there.
public struct ActivityList: View {
    let items: [ActivityItem]
    let current: String?

    public init(items: [ActivityItem], current: String?) {
        self.items = items
        self.current = current
    }

    public var body: some View {
        if let line {
            ActivityRow(label: line.label, running: true, symbol: line.symbol)
        }
    }

    private var line: (label: String, symbol: String?)? {
        if let item = items.last(where: { $0.running && $0.kind != .tasks }) {
            return (item.label, Self.symbol(for: item.kind))
        }
        if let tasks = items.last(where: { $0.kind == .tasks })?.tasks,
           let index = tasks.firstIndex(where: { $0.state == .active }) {
            return ("\(tasks[index].title) (\(index + 1) of \(tasks.count))", Self.symbol(for: .tasks))
        }
        return current.map { ($0, nil) }
    }

    static func symbol(for kind: ActivityItem.Kind) -> String {
        switch kind {
        case .thinking: "brain"
        case .shell: "terminal"
        case .monitor: "eye"
        case .subagent: "person.2"
        case .tool: "wrench.and.screwdriver"
        case .tasks: "checklist"
        }
    }
}

/// The transcript's geometry, shared with the composer: messages sit 16pt
/// from the edges; the composer sits with them while the keyboard is away
/// and pulls in when it is up, to leave room to write.
extension View {
    /// Runs `action` as the soft keyboard changes its frame. Only where
    /// there is one: the Mac has none, the portable SwiftUI lets the
    /// host handle it.
    @ViewBuilder func keyboardTracking(_ action: @escaping () -> Void) -> some View {
        #if canImport(UIKit)
        self.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            // The keyboard says how it moves; the scroll moves the same way.
            let info = note.userInfo ?? [:]
            let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            let curve = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int).flatMap(UIView.AnimationCurve.init(rawValue:)) ?? .easeInOut
            let timing = UICubicTimingParameters(animationCurve: curve)
            let animation: Animation = timing.controlPoint1 == .zero && timing.controlPoint2 == CGPoint(x: 1, y: 1)
                ? .linear(duration: duration)
                : .timingCurve(timing.controlPoint1.x, timing.controlPoint1.y, timing.controlPoint2.x, timing.controlPoint2.y, duration: duration)
            withAnimation(animation) { action() }
        }
        #else
        self
        #endif
    }

    /// The bottom stays put: the scroll view opens at its bottom edge and
    /// keeps it when it or its content changes size. The portable SwiftUI
    /// keeps the offset.
    @ViewBuilder func bottomAnchored() -> some View {
        #if canImport(UIKit) || canImport(AppKit)
        self.defaultScrollAnchor(.bottom)
        #else
        self
        #endif
    }

    /// A list whose rows are exactly as tall as what is in them. Apple's
    /// List gives every row a minimum height (44pt on a phone), which
    /// turned an empty scroll-target row into a blank band under the
    /// transcript. The portable list has no such minimum.
    @ViewBuilder func noMinimumRowHeight() -> some View {
        #if canImport(UIKit) || canImport(AppKit)
        self.environment(\.defaultMinListRowHeight, 0)
        #else
        self
        #endif
    }

    /// One transcript row: the stack's 12pt spacing as 6pt above and
    /// below, and the reading width kept on a wide display.
    func transcriptCell() -> some View {
        self
            .padding(.vertical, 6)
            // Two frames with different jobs. The inner one holds the row
            // to the column's width, leading, so a row narrower than the
            // column (an activity line, a lone tool call) sits at the left
            // edge with the rest, not centred in the slack. The outer one
            // centres that column in a window wider than it, so the thread
            // sits in the middle — and lines up with the composer, which
            // centres the same way.
            .frame(maxWidth: TranscriptMetrics.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    /// A row with nothing of the list's own around it: no insets, no
    /// background. The portable SwiftUI has neither modifier yet and its
    /// plain list draws neither, so there it is the row as it is.
    @ViewBuilder func plainListRow() -> some View {
        #if canImport(UIKit) || canImport(AppKit)
        self.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
        #else
        self
        #endif
    }
}

public enum TranscriptMetrics {
    public static let edgeInset: CGFloat = 16
    /// The last cell of the transcript: with the last row's own 6pt below
    /// it and the composer's 8pt above the box, 32pt between the two.
    public static let bottomGap: CGFloat = 18
    /// A thread is uncomfortable to read across a large display: the
    /// messages and the composer stop here and centre in a wider column.
    public static let maxContentWidth: CGFloat = 720
    /// A picture's corner, in the transcript and in the viewer.
    public static let imageCorner: CGFloat = 8
    /// The longest side a picture takes in the transcript.
    public static let thumbnail: CGFloat = 220

    /// The size a picture of `pixels` is drawn at under `maxEdge`: its own
    /// shape, scaled to fit, never enlarged — and never thinner than
    /// legible, however long a strip it is. The same rule sizes a reserved
    /// frame and the picture that later fills it, so nothing moves.
    public static func fitted(_ pixels: CGSize, maxEdge: CGFloat) -> CGSize? {
        guard maxEdge > 0, pixels.width > 0, pixels.height > 0 else { return nil }
        let scale = min(maxEdge / pixels.width, maxEdge / pixels.height, 1)
        let floor = min(maxEdge, 96)
        let longest = max(pixels.width, pixels.height)
        let width = max(pixels.width * scale, floor * pixels.width / longest)
        let height = max(pixels.height * scale, floor * pixels.height / longest)
        return CGSize(width: width, height: height)
    }
}

/// How the transcript shows an image URL. The default is `AsyncImage`
/// (remote / blob URLs on the web); an app whose images are local files
/// installs its own loader (the iOS Playground decodes them from disk —
/// `AsyncImage` over `file://` URLs is unreliable there).
public enum TranscriptImages {
    /// Draw the picture behind a reference, no larger than `maxEdge` on
    /// its longest side (0 for as large as it likes). The app returns it
    /// already at its own proportions: a box the size of the largest
    /// allowed picture would leave a tall screenshot floating in the
    /// middle of it, and the rounded corner clipping empty space.
    nonisolated(unsafe) public static var render: ((String, CGFloat) -> AnyView)?
    #if canImport(AppKit) || canImport(UIKit)
    /// The bytes behind a reference, for a viewer that wants to hand the
    /// picture to a share sheet (and so to Save Image). Apple only: the
    /// portable SwiftUI has no Foundation to put them in and nowhere to
    /// share them to.
    nonisolated(unsafe) public static var data: ((String) async -> Data?)?
    #endif
}

/// Thumbnails of a message's images (screenshots, attached mocks), on
/// the side its message is on: yours right, the agent's left. Tap one to
/// see it whole.
public struct ImageStrip: View {
    let urls: [String]
    let sizes: [CGSize?]
    let alignment: HorizontalAlignment

    public init(urls: [String], sizes: [CGSize?] = [], alignment: HorizontalAlignment = .leading) {
        self.urls = urls
        self.sizes = sizes
        self.alignment = alignment
    }

    /// The frame a picture takes before it has arrived, when its size is
    /// known: the row is its final shape from the start.
    private func reserved(_ index: Int) -> CGSize? {
        guard index < sizes.count, let pixels = sizes[index] else { return nil }
        return TranscriptMetrics.fitted(pixels, maxEdge: TranscriptMetrics.thumbnail)
    }

    public var body: some View {
        if !urls.isEmpty {
            HStack(spacing: 6) {
                if alignment == .trailing { Spacer(minLength: 0) }
                ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                    Button {
                        // Not held here: a transcript row is rebuilt on
                        // every delta that arrives, and state inside one
                        // goes with it — which is why the viewer opened
                        // onto nothing.
                        TranscriptImageOpen.shared.url = url
                    } label: {
                        TranscriptImage(url: url, maxEdge: TranscriptMetrics.thumbnail)
                            .frame(width: reserved(index)?.width, height: reserved(index)?.height)
                            .clipShape(RoundedRectangle(cornerRadius: TranscriptMetrics.imageCorner))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open the picture")
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            // The row has to be as wide as the message or the spacer has
            // nothing to push against and the pictures sit wherever they
            // happen to fall.
            .frame(maxWidth: .infinity)
        }
    }
}

/// Which picture is open, if any. Outside the view tree, because the row
/// that was tapped is rebuilt constantly and anything kept inside it
/// disappears between the tap and the sheet.
public final class TranscriptImageOpen: ObservableObject, @unchecked Sendable {
    public static let shared = TranscriptImageOpen()
    @Published public var url: String?
    private init() {}
}

/// One picture, however this app loads them.
struct TranscriptImage: View {
    let url: String
    /// The longest side it may take; 0 for as much room as there is.
    var maxEdge: CGFloat = 0

    var body: some View {
        if let render = TranscriptImages.render {
            render(url, maxEdge)
        } else {
            AsyncImage(url: URL(string: url)) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.gray.opacity(0.2).frame(width: 96, height: 96)
            }
        }
    }
}

/// How full an agent's context is: a ring that fills as the conversation
/// grows, amber past three quarters and red at the edge. Tapping it is the
/// app's business (a menu with the numbers, say).
public struct ContextRing: View {
    let used: Int
    let limit: Int
    let size: CGFloat

    public init(used: Int, limit: Int, size: CGFloat = 18) {
        self.used = used
        self.limit = limit
        self.size = size
    }

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(limit)))
    }

    /// Light grey while there is room, and only then a warning: the gauge
    /// is something to glance at, not something to be told about.
    private var tint: Color {
        fraction >= 0.9 ? .red : (fraction >= 0.75 ? .orange : Color(white: 0.55))
    }

    /// Thicker as the ring grows, so a gauge the size of a button does not
    /// read as a hairline: a ring the height of the composer's controls is
    /// 4pt thick.
    private var lineWidth: CGFloat { max(2, size / 9) }

    public var body: some View {
        // The stroke straddles the path, so the drawn circle is inset by
        // half of it: `size` is then the ring's outside diameter, which is
        // what lines it up with a button beside it.
        let inner = max(1, size - lineWidth)
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.28), lineWidth: lineWidth)
                .frame(width: inner, height: inner)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, lineWidth: lineWidth)
                .frame(width: inner, height: inner)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(ContextRing.summary(used: used, limit: limit))
    }

    /// "42,100 of 200,000 tokens (21%)".
    public static func summary(used: Int, limit: Int) -> String {
        let percent = limit > 0 ? Int((Double(used) / Double(limit) * 100).rounded()) : 0
        return "\(grouped(used)) of \(grouped(limit)) tokens (\(percent)%)"
    }

    /// Thousands separated, without Foundation (not every host has it).
    public static func grouped(_ value: Int) -> String {
        let digits = Array(String(max(0, value)))
        var out = ""
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out.append(",") }
            out.append(digit)
        }
        return out
    }
}

/// Runs after the current layout pass has been applied.
func afterLayout(_ action: @escaping @MainActor () -> Void) {
    #if canImport(Dispatch)
    DispatchQueue.main.async { action() }
    #else
    Task { @MainActor in
        await Task.yield()
        action()
    }
    #endif
}

#if canImport(UIKit) || canImport(AppKit)
/// A scroll view kept by its position: the content gets the way to scroll
/// to its bottom edge — the edge itself, not a row whose height may still
/// be an estimate.
struct EdgeScrolled<Content: View>: View {
    @State private var position = ScrollPosition(edge: .bottom)
    let content: (@escaping () -> Void) -> Content

    init(@ViewBuilder content: @escaping (@escaping () -> Void) -> Content) { self.content = content }

    var body: some View {
        content({ position.scrollTo(edge: .bottom) }).scrollPosition($position)
    }
}
#endif
