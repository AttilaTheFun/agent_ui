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

/// The transcript: the record's messages, and under them one status row
/// that is always there. The rows change only when the record does; what
/// the turn is doing changes the status row's words, never its height.
/// The status row is what the thread scrolls to: on opening, when a
/// message arrives, and with the keyboard.
public struct TranscriptView: View {
    let messages: [TranscriptMessage]
    /// The agent is working: the status row shows its spinner.
    let busy: Bool
    /// What the turn is doing now (tool calls, subagents, the task list).
    let status: [ActivityItem]
    /// A label for the status row when nothing in `status` is running
    /// ("Thinking…", or the road to the computer while it is down).
    let activity: String?
    /// The last failure, in the status row while the agent is idle.
    let error: String?
    let emptyTitle: String
    let emptyBody: String
    let emptyFootnote: String?
    /// Given when the thread goes back further than what is shown.
    let loadEarlier: (() -> Void)?
    /// How much of the bottom the composer covers; the thread is scrolled
    /// to its bottom again when this changes.
    let bottomInset: CGFloat

    public init(messages: [TranscriptMessage], busy: Bool = false, status: [ActivityItem] = [], activity: String? = nil,
                error: String? = nil, emptyTitle: String = "What should we build?", emptyBody: String, emptyFootnote: String? = nil,
                loadEarlier: (() -> Void)? = nil, bottomInset: CGFloat = 0) {
        self.messages = messages
        self.busy = busy
        self.status = status
        self.activity = activity
        self.error = error
        self.emptyTitle = emptyTitle
        self.emptyBody = emptyBody
        self.emptyFootnote = emptyFootnote
        self.loadEarlier = loadEarlier
        self.bottomInset = bottomInset
    }

    @ObservedObject private var opened = TranscriptImageOpen.shared
    @ObservedObject private var openedCalls = ToolCallsOpen.shared

    static let bottom = "status"

    public var body: some View {
        ScrollViewReader { proxy in
            let toBottom = { proxy.scrollTo(Self.bottom, anchor: .bottom) }
            List {
                Group {
                    if let loadEarlier, !messages.isEmpty {
                        Button(action: loadEarlier) {
                            Text("Load earlier messages").font(.footnote).foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .transcriptCell()
                    }
                    if messages.isEmpty { emptyState }
                    ForEach(TranscriptBlock.blocks(messages)) { block in
                        switch block {
                        case .message(let message): TranscriptRow(message: message).transcriptCell()
                        case .calls(let run): ToolCallsRow(run: run).transcriptCell()
                        }
                    }
                    StatusRow(busy: busy, status: status, activity: activity, error: error)
                        .transcriptCell()
                        .id(Self.bottom)
                }
                .listRowSeparator(.hidden)
                .plainListRow()
            }
            .listStyle(.plain)
            .noMinimumRowHeight()
            // The bottom stays put as the list or its rows change size.
            .bottomAnchoredOnResize()
            .onAppear(perform: toBottom)
            // A message arrived: once it has been laid out, the thread is
            // taken to the bottom.
            .onChange(of: messages.count) { _ in afterLayout { withAnimation { toBottom() } } }
            .onChange(of: bottomInset) { _ in afterLayout(toBottom) }
            // The keyboard coming or going: the thread moves with it.
            .keyboardTracking(toBottom)
            .sheet(isPresented: Binding(get: { opened.url != nil },
                                        set: { if !$0 { opened.url = nil } })) {
                if let url = opened.url { ImageViewer(url: url) }
            }
            .sheet(isPresented: Binding(get: { openedCalls.run != nil },
                                        set: { if !$0 { openedCalls.run = nil } })) {
                if let run = openedCalls.run { ToolCallsSheet(run: run) }
            }
        }
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

/// The transcript's last row, always there and always one line tall: a
/// spinner and what the agent is doing while it works — the latest tool
/// running, else the task under way, else the label ("Thinking…") — and
/// the last failure while it is idle. Hidden, not removed, when there is
/// nothing to say, so the thread never changes height for it.
struct StatusRow: View {
    let busy: Bool
    let status: [ActivityItem]
    let activity: String?
    let error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let line {
                    ProgressView().controlSize(.small)
                    if let symbol = line.symbol {
                        Image(systemName: symbol).foregroundColor(.secondary).font(.footnote)
                    }
                    Text(line.label).font(.footnote).foregroundColor(.secondary)
                } else if let error {
                    Text(error).font(.footnote).foregroundColor(.red)
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .frame(height: 20)
            .padding(.horizontal, TranscriptMetrics.edgeInset)
            Color.clear.frame(height: TranscriptMetrics.bottomGap)
        }
    }

    private var line: (label: String, symbol: String?)? {
        if let item = status.last(where: { $0.running && $0.kind != .tasks }) {
            return (item.label, Self.symbol(for: item.kind))
        }
        guard busy || activity != nil else { return nil }
        if let tasks = status.last(where: { $0.kind == .tasks })?.tasks,
           let index = tasks.firstIndex(where: { $0.state == .active }) {
            return ("\(tasks[index].title) (\(index + 1) of \(tasks.count))", Self.symbol(for: .tasks))
        }
        return (activity ?? "Thinking…", nil)
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

/// What the transcript draws in one slot: a message, or a run of tool
/// calls folded into one row. A run is consecutive messages that are only
/// tool calls and their results — an assistant row with activities and no
/// words, a tool row with no picture — and is folded into one row however
/// many calls it holds, so the row keeps one identity as the run grows.
public enum TranscriptBlock: Identifiable {
    case message(TranscriptMessage)
    case calls([TranscriptMessage])

    public var id: String {
        switch self {
        case .message(let message): message.id
        case .calls(let run): "calls-" + (run.first?.id ?? "")
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
            // Nothing to act on until the words have stopped arriving.
            if !streaming, !text.isEmpty { MessageActions(text: text) }
        }
        .padding(.horizontal, TranscriptMetrics.edgeInset)
        .opacity(streaming ? 0.85 : 1)
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

    /// The bottom stays put when the list or its content changes size.
    /// The portable SwiftUI keeps the offset.
    @ViewBuilder func bottomAnchoredOnResize() -> some View {
        #if canImport(UIKit) || canImport(AppKit)
        self.defaultScrollAnchor(.bottom, for: .sizeChanges)
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
