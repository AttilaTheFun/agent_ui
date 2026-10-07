// The agent's transcript: user/assistant bubbles, tool activity rows, the
// streaming reply, and an empty state — the same rows in both Playgrounds
// and in Visor. Each app maps its chat model to `TranscriptMessage`.

import SwiftUI
#if canImport(QuickLook)
import QuickLook
#endif

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
    /// Given when the thread goes back further than what is shown: called
    /// when the row standing for the earlier rows comes into view (and
    /// again while it stays in view after a page goes in), so the app
    /// ignores a call while a page is on its way.
    let loadEarlier: (() -> Void)?
    /// A message is being sent this moment: the composer gives up its
    /// lines as the message goes into the thread, and the list keeps its
    /// top still through both, then eases to its bottom — rather than
    /// dropping with the composer and coming back up.
    let sending: Bool
    /// How tall the composer below the thread is: when it grows or shrinks
    /// (lines typed, a draft sent), the thread keeps its bottom in view.
    let composerHeight: CGFloat

    public init(messages: [TranscriptMessage], busy: Bool = false, status: [ActivityItem] = [], activity: String? = nil,
                error: String? = nil, emptyTitle: String = "What should we build?", emptyBody: String, emptyFootnote: String? = nil,
                loadEarlier: (() -> Void)? = nil, sending: Bool = false, composerHeight: CGFloat = 0) {
        self.sending = sending
        self.composerHeight = composerHeight
        self.messages = messages
        self._shown = State(initialValue: messages)
        self._revealed = State(initialValue: !messages.isEmpty)
        self.busy = busy
        self.status = status
        self.activity = activity
        self.error = error
        self.emptyTitle = emptyTitle
        self.emptyBody = emptyBody
        self.emptyFootnote = emptyFootnote
        self.loadEarlier = loadEarlier
    }

    /// The picture and the run of tool calls open over the thread, if any.
    /// Kept here and lent to the rows through the environment: a row is
    /// rebuilt on every delta that arrives, and state inside one goes
    /// with it.
    /// The attachment a row asked to see whole: a picture, a video, a
    /// file. Set while its bytes are fetched (the tile shows that), then
    /// shown by the system's preview where there is one, else the viewer.
    @State private var openedImage: String?
    @State private var openedCalls: [TranscriptMessage]?
    #if canImport(QuickLook)
    /// The attachment as a file, for the system's preview (Quick Look).
    @State private var previewFile: URL?
    #endif

    static let bottom = "status"

    /// Rows are being put in at the end: the list keeps its top still.
    @State private var holdTop = false
    /// Just after a thread's rows are first shown: while the list is still
    /// measuring them, each change in its height takes it to the bottom
    /// again, so it lands on the last row however long the measuring takes
    /// (a Mac's list scrolls to a row before its height is known and stops
    /// short).
    @State private var settling = false

    /// The rows drawn: the app's, as of its last change.
    @State private var shown: [TranscriptMessage]
    /// The rows are drawn. Rows that come after the thread has opened (its
    /// first sync, with nothing cached) are laid out from the top and
    /// scrolled to their end a frame later, and the thread's top showed
    /// for that frame: they stay invisible until the list stands at its
    /// end. Rows the thread opens with are drawn at once, as before.
    @State private var revealed: Bool
    @State private var revealEnds: Task<Void, Never>?
    /// The row that asks for earlier rows is in view.
    @State private var earlierInView = false
    /// The row kept at the top while a page of earlier rows goes in above
    /// it: a list at its top would otherwise stay there and show the page's
    /// first row. Let go once the page has settled.
    @State private var keptAtTop: String?
    @State private var keptEnds: Task<Void, Never>?

    /// What ends the settling, and what lets go of the top after rows are
    /// put in: one of each at a time, so a second settling or a second
    /// arrival takes over from the first instead of being cut short by it.
    @State private var settlingEnds: Task<Void, Never>?
    @State private var arrivalEnds: Task<Void, Never>?

    /// Keeps the thread on its last row while the list lays out its first
    /// rows: every height change in the next moment scrolls again, and a
    /// last scroll when the moment is over.
    private func settle(_ toBottom: @escaping () -> Void) {
        settling = true
        settlingEnds?.cancel()
        settlingEnds = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            toBottom()
            // Drawn by now whatever the layout did.
            reveal(after: 0)
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            toBottom()
            settling = false
        }
    }

    /// Draws the rows once the scroll to their end has landed: a frame or
    /// two after the list laid them out (`after` nanoseconds).
    private func reveal(after delay: UInt64 = 34_000_000) {
        guard !revealed, revealEnds == nil else { return }
        revealEnds = Task { @MainActor in
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            guard !Task.isCancelled else { return }
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { revealed = true }
            revealEnds = nil
        }
    }

    /// Keeps `row` at the top while the page going in above it is laid out.
    private func keep(_ row: String) {
        keptAtTop = row
        keptEnds?.cancel()
        keptEnds = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            keptAtTop = nil
        }
    }

    /// Asks for the rows before the first shown while the row that stands
    /// for them is in view — not while the thread is settling on its last
    /// row, when the list may lay its top out on the way down. Asked again
    /// when the settling ends, and when a page has gone in and the row is
    /// still in view (a short page).
    private func askEarlier() {
        guard earlierInView, !settling, let loadEarlier else { return }
        loadEarlier()
    }

    /// Whether `new` is `old` with rows put in before its first.
    static func prepends(_ new: [TranscriptMessage], to old: [TranscriptMessage]) -> Bool {
        guard let first = old.first, let last = old.last, new.last?.id == last.id, new.first?.id != first.id else { return false }
        return new.contains { $0.id == first.id }
    }

    /// The first of `old`'s rows that is still a row of its own in `new`:
    /// a run of tool calls at the top of `old` may have joined one at the
    /// end of the rows put in before it.
    static func firstKept(of old: [TranscriptMessage], in new: [TranscriptMessage]) -> String? {
        let rows = Set(TranscriptBlock.blocks(new).map(\.id))
        return TranscriptBlock.blocks(Array(old.prefix(8))).map(\.id).first { rows.contains($0) }
    }

    /// Whether `new` is `old` with rows added after its last.
    static func appends(_ new: [TranscriptMessage], to old: [TranscriptMessage]) -> Bool {
        guard let last = old.last, new.last?.id != last.id else { return false }
        return new.contains { $0.id == last.id }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            let toBottom = { proxy.scrollTo(Self.bottom, anchor: .bottom) }
            List {
                Group {
                    if loadEarlier != nil, !shown.isEmpty {
                        // The rows before these: coming into view asks for
                        // them, and the row spins until they are in.
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .transcriptCell()
                            .onAppear {
                                earlierInView = true
                                askEarlier()
                            }
                            .onDisappear { earlierInView = false }
                    }
                    if shown.isEmpty { emptyState }
                    ForEach(TranscriptBlock.blocks(shown)) { block in
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
            // Invisible while rows laid out from the top are on their way
            // to their end; the empty state is always drawn.
            .opacity(shown.isEmpty || revealed ? 1 : 0)
            // A plain list's own edge is a hard band under the bar.
            .softTopEdge()
            .noMinimumRowHeight()
            // The bottom stays put as the list or its rows change size.
            .bottomAnchoredOnResize(!(holdTop || sending))
            .onChange(of: sending) { _, now in
                guard now else { return }
                // Whether or not a row goes in (a message that waits for
                // the turn to end does not): the room the composer gave up
                // is taken in one eased motion.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    withAnimation(.smooth(duration: 0.3)) { toBottom() }
                }
            }
            .onAppear {
                toBottom()
                if !shown.isEmpty { settle(toBottom) }
            }
            .onContentHeightChange {
                if settling {
                    toBottom()
                    // The first rows are laid out: drawn once the scroll
                    // to their end has landed.
                    if !shown.isEmpty { reveal() }
                } else if let keptAtTop {
                    // As the list lays out the page: before the frame that
                    // would show the page's top.
                    var still = Transaction()
                    still.disablesAnimations = true
                    withTransaction(still) { proxy.scrollTo(keptAtTop, anchor: .top) }
                }
            }
            .onChange(of: settling) { _, _ in askEarlier() }
            .onChange(of: shown.first?.id) { _, _ in askEarlier() }
            // The rows drawn are this view's copy of the app's, changed as
            // the app's change. Rows arriving at the end are put in below
            // what is seen — the list holding its top still for that one
            // change, rather than its bottom — and the thread then scrolls
            // up to them, so every row comes in from the bottom. (The
            // list's own insert animation fades a row in where it will sit
            // and slides the rows under it down.) Anything else (the rows
            // replaced whole, earlier ones loaded, a row's words) is not
            // animated.
            .onChange(of: messages) { _, new in
                // Rows after the last while the thread is still settling
                // after it opened are history catching up (the whole
                // transcript arriving after the cached rows), not a reply:
                // they go in with the thread kept at its bottom, not
                // brought in from below.
                let appended = Self.appends(new, to: shown) && !settling
                if appended {
                    holdTop = true
                    shown = new
                    // The scroll once the list has the rows and the box its
                    // new height (the words sent leave it in the same
                    // change): a scroll made before either has landed
                    // measures against the old and goes nowhere.
                    arrivalEnds?.cancel()
                    arrivalEnds = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        guard !Task.isCancelled else { return }
                        withAnimation(.smooth(duration: 0.3)) { toBottom() }
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard !Task.isCancelled else { return }
                        holdTop = false
                    }
                } else {
                    let first = shown.isEmpty
                    let moved = new.last?.id != shown.last?.id
                    // A page of earlier rows put in above while the top is
                    // in view: the row that was first stays where it was,
                    // rather than the list showing the page's own first.
                    if earlierInView, Self.prepends(new, to: shown), let kept = Self.firstKept(of: shown, in: new) {
                        keep(kept)
                    }
                    shown = new
                    // Once the layout pass that takes the rows has been
                    // applied.
                    if moved {
                        Task { @MainActor in
                            // Where the main actor is not a queue of its
                            // own, one more turn lets the layout land.
                            #if !canImport(Dispatch)
                            await Task.yield()
                            #endif
                            toBottom()
                        }
                    }
                    // The first rows of a thread opened before they had
                    // come: the list's first scroll measures rows it has
                    // only estimated and stops short, so it goes again as
                    // they are laid out.
                    if first, !new.isEmpty { settle(toBottom) }
                }
            }
            // The room the thread has changed — the keyboard coming or
            // going, the composer growing: the thread eases to the bottom
            // over about the time the keyboard takes, rather than jumping
            // there while the keyboard is still on its way.
            // While rows arrive, their own scroll takes the thread to the
            // bottom: a second scroll in the middle of it (the composer
            // shrinking as the words sent leave it) fought it.
            .onVisibleHeightChange { if !holdTop && !sending { withAnimation(.smooth(duration: 0.35)) { toBottom() } } }
            // On a Mac the composer bar's growth reaches the list as an
            // inset its scroll geometry does not report, so the change
            // above never fired and the last rows went under the box: the
            // composer's own height is watched instead, and the thread
            // scrolled once the new inset has landed — at once, as the box
            // pushes it, not eased.
            .onComposerHeightChange(composerHeight) {
                guard !holdTop && !sending else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    toBottom()
                }
            }
            .environment(\.openedTranscriptImage, $openedImage)
            .environment(\.openedToolCalls, $openedCalls)
            #if canImport(QuickLook)
            // The system's preview: pictures zoom, videos play, documents
            // open, with its own share. The attachment's bytes are fetched
            // first (a picture's are at hand; a video's take a moment, the
            // tile spinning meanwhile), then handed over as a file.
            .quickLookPreview($previewFile)
            .onChange(of: openedImage) { _, reference in
                guard let reference else { return }
                Task { @MainActor in
                    let file = await TranscriptFiles.local(for: reference)
                    guard openedImage == reference else { return }
                    openedImage = nil
                    previewFile = file
                }
            }
            #else
            .sheet(isPresented: Binding(get: { openedImage != nil },
                                        set: { if !$0 { openedImage = nil } })) {
                if let url = openedImage { ImageViewer(url: url) }
            }
            #endif
            .sheet(isPresented: Binding(get: { openedCalls != nil },
                                        set: { if !$0 { openedCalls = nil } })) {
                if let run = openedCalls { ToolCallsSheet(run: run) }
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
