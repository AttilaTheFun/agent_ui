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
    /// ignores a call while a page is on its way. Held, not a closure, so
    /// the view compares equal across its parent's passes (AgentView keeps
    /// one; the public initialiser makes one each time, as before).
    let loadEarlier: ViewAction?
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
        self.init(messages: messages, busy: busy, status: status, activity: activity, error: error, emptyTitle: emptyTitle,
                  emptyBody: emptyBody, emptyFootnote: emptyFootnote, earlier: loadEarlier.map { ViewAction(run: $0) },
                  sending: sending, composerHeight: composerHeight)
    }

    /// With the call for earlier rows held by the caller, kept across its
    /// passes.
    init(messages: [TranscriptMessage], busy: Bool, status: [ActivityItem], activity: String?, error: String?,
         emptyTitle: String, emptyBody: String, emptyFootnote: String?, earlier loadEarlier: ViewAction?,
         sending: Bool, composerHeight: CGFloat) {
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
    /// The row standing for earlier rows: one height whether it spins or
    /// not, as little as a small spinner needs (it is there in every thread).
    static let earlierRowHeight: CGFloat = 24

    /// Rows are being put in at the end: the list keeps its top still.
    @State private var holdTop = false
    /// What the thread keeps for its choreography that nothing draws.
    @State private var stage = TranscriptChoreography()

    /// The rows drawn: the app's, as of its last change.
    @State private var shown: [TranscriptMessage]
    /// The rows are drawn. Rows that come after the thread has opened (its
    /// first sync, with nothing cached) are laid out from the top and
    /// scrolled to their end a frame later, and the thread's top showed
    /// for that frame: they stay invisible until the list stands at its
    /// end. Rows the thread opens with are drawn at once, as before.
    @State private var revealed: Bool
    /// The empty state last shown ("Loading…"), kept on screen while the
    /// first rows are hidden, so opening is one change — from it to the
    /// thread at its end — rather than a blank between the two (the app
    /// changes the empty state's words in the same update the rows come).
    @State private var heldEmpty: (title: String, body: String)?

    /// The thread follows its end: rows that come in are scrolled to, and
    /// the end stays in view as the keyboard or the composer change. Not
    /// once the user has scrolled up to read: what they read stays where
    /// it is and a pill says how many rows came in below. Following again
    /// as soon as the end is in view, by their scroll or the pill's.
    @State private var following = true
    /// Rows that came in below while not following, for the pill (0: none).
    @State private var unseen = 0
    /// How long the pill stays after the last rows it counts came in
    /// (`EnvironmentValues.newRowsPillSeconds`).
    @Environment(\.newRowsPillSeconds) private var pillSeconds
    /// How near the end counts as at it: the status row, the last, in view.
    static let endSlack: CGFloat = 60


    /// Keeps the thread on its last row while the list lays out its first
    /// rows: every height change in the next moment scrolls again, and a
    /// last scroll when the moment is over.
    private func settle(_ toBottom: @escaping () -> Void) {
        stage.settling = true
        stage.settlingEnds?.cancel()
        stage.settlingEnds = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            toBottom()
            // Drawn by now whatever the layout did.
            reveal(after: 0)
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            toBottom()
            stage.settling = false
            // Asked for now that the thread has stood still on its end.
            askEarlier()
        }
    }

    /// Draws the rows once the scroll to their end has landed: a frame or
    /// two after the list laid them out (`after` nanoseconds).
    private func reveal(after delay: UInt64 = 34_000_000) {
        guard !revealed, stage.revealEnds == nil else { return }
        stage.revealEnds = Task { @MainActor in
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            guard !Task.isCancelled else { return }
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { revealed = true }
            stage.revealEnds = nil
        }
    }

    /// Keeps `row` at the top while the page going in above it is laid out.
    private func keep(_ row: String) {
        stage.keptAtTop = row
        stage.keptEnds?.cancel()
        stage.keptEnds = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            stage.keptAtTop = nil
        }
    }

    /// Asks for the rows before the first shown while the row that stands
    /// for them is in view — not while the thread is settling on its last
    /// row, when the list may lay its top out on the way down. Asked again
    /// when the settling ends, and when a page has gone in and the row is
    /// still in view (a short page).
    private func askEarlier() {
        guard stage.earlierInView, !stage.settling, let loadEarlier else { return }
        // A page still going in, or one asked for a moment ago: asked again
        // once it has settled, if the row is still in view then.
        let now = ContinuousClock.now
        let since = stage.earlierAsked.map { now - $0 } ?? .seconds(60)
        if stage.keptAtTop != nil || since < Self.earlierBreath {
            stage.earlierLater?.cancel()
            let wait = max(Self.earlierBreath - since, .milliseconds(150))
            stage.earlierLater = Task { @MainActor in
                try? await Task.sleep(for: wait)
                guard !Task.isCancelled else { return }
                askEarlier()
            }
            return
        }
        stage.earlierAsked = now
        loadEarlier.run()
    }

    /// The least time between two pages of earlier rows.
    static let earlierBreath: Duration = .milliseconds(600)

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

    /// How many rows, as the thread draws them (a run of tool calls is
    /// one), `new` has after the last of `old`'s: what the pill counts.
    /// Earlier rows put in above are not new, and rows that replace all
    /// the old are not counted.
    static func newRows(in new: [TranscriptMessage], after old: [TranscriptMessage]) -> Int {
        let had = Set(TranscriptBlock.blocks(old).map(\.id))
        let blocks = TranscriptBlock.blocks(new)
        guard let last = blocks.lastIndex(where: { had.contains($0.id) }) else { return 0 }
        return blocks.count - last - 1
    }

    /// Where the list stands against its end, for following it: its offset,
    /// and whether the end is in view.
    struct EndState: Equatable {
        var offset: CGFloat
        var atEnd: Bool
    }

    /// Rows came in below while the thread is read further up: counted on
    /// the pill, which goes a while after the last of them.
    private func showPill(adding count: Int) {
        guard count > 0 else { return }
        withAnimation(.smooth(duration: 0.25)) { unseen += count }
        stage.pillEnds?.cancel()
        stage.pillEnds = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(0, pillSeconds) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            hidePill()
        }
    }

    private func hidePill() {
        stage.pillEnds?.cancel()
        stage.pillEnds = nil
        guard unseen > 0 else { return }
        withAnimation(.smooth(duration: 0.25)) { unseen = 0 }
    }

    public var body: some View {
        // In steps, each a small expression: one long chain of modifiers
        // was more than some SwiftUIs' type checker would take in time.
        ScrollViewReader { proxy in
            let toBottom = { proxy.scrollTo(Self.bottom, anchor: .bottom) }
            presenting(room(arrivals(opening(following(framed(rows), toBottom: toBottom), proxy: proxy, toBottom: toBottom),
                                     toBottom: toBottom), toBottom: toBottom))
        }
    }

    /// The thread's rows: the one for earlier rows, the rows, the status row.
    private var rows: some View {
        List {
            Group {
                if !shown.isEmpty {
                    // The rows before these: coming into view asks for
                    // them, and the row spins until they are in. Always
                    // there, empty when there is nothing before, like
                    // the status row: put in when the app learns there
                    // are earlier rows (its first answer after a
                    // launch, often the one to a send), it moved every
                    // row under it down.
                    ZStack {
                        if loadEarlier != nil { ProgressView().controlSize(.small) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.earlierRowHeight)
                    .onAppear {
                        stage.earlierInView = true
                        askEarlier()
                    }
                    .onDisappear { stage.earlierInView = false }
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
    }

    /// Drawn once its first rows have landed, over the held empty state.
    private func framed(_ list: some View) -> some View {
        list
        // Invisible while rows laid out from the top are on their way
        // to their end; the empty state is always drawn, and stays
        // over the hidden rows until they are shown.
        .opacity(shown.isEmpty || revealed ? 1 : 0)
        .overlay(alignment: .top) { heldEmptyList }
        .onChange(of: emptyWords, initial: true) { _, _ in
            // Only while the thread is empty: the words that change with
            // the rows' coming are not the ones that were on screen.
            if messages.isEmpty, heldEmpty?.title != emptyTitle || heldEmpty?.body != emptyBody {
                heldEmpty = (emptyTitle, emptyBody)
            }
        }
        // A plain list's own edge is a hard band under the bar.
        .softTopEdge()
        .noMinimumRowHeight()
    }

    /// Following the end, and the pill while it is not followed.
    private func following(_ content: some View, toBottom: @escaping () -> Void) -> some View {
        content
        // The bottom stays put as the list or its rows change size —
        // while following the end; read further up, what is read does.
        .bottomAnchoredOnResize(following && !(holdTop || sending))
        // Following the end, or not: the user going up stops it; the
        // end coming into view, however it does, starts it again.
        .onScrollGeometryChange(for: EndState.self) { geometry in
            let seen = geometry.contentOffset.y + geometry.containerSize.height - geometry.contentInsets.bottom
            return EndState(offset: geometry.contentOffset.y, atEnd: geometry.contentSize.height - seen <= Self.endSlack)
        } action: { old, new in
            if new.atEnd {
                if !following { following = true }
                hidePill()
            } else if new.offset < old.offset - 1, following {
                following = false
            }
        }
        .overlay(alignment: .bottom) {
            if unseen > 0 {
                NewRowsPill(count: unseen) {
                    withAnimation(.smooth(duration: 0.35)) { toBottom() }
                    hidePill()
                }
                .padding(.bottom, 10)
                .transition(.opacity)
            }
        }
    }

    /// Opening, a send, and the list measuring its rows.
    private func opening(_ content: some View, proxy: ScrollViewProxy, toBottom: @escaping () -> Void) -> some View {
        content
        .onChange(of: sending) { _, now in
            guard now else { return }
            // What the user sends, they go down to, wherever they were.
            if !following { following = true }
            hidePill()
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
            if stage.settling {
                toBottom()
                // The first rows are laid out: drawn once the scroll
                // to their end has landed.
                if !shown.isEmpty { reveal() }
            } else if let keptAtTop = stage.keptAtTop {
                // As the list lays out the page: before the frame that
                // would show the page's top.
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) { proxy.scrollTo(keptAtTop, anchor: .top) }
            }
        }
        // Earlier rows learned of while their row is already in view.
        .onChange(of: loadEarlier != nil) { _, _ in askEarlier() }
        .onChange(of: shown.first?.id) { _, _ in askEarlier() }
    }

        // The rows drawn are this view's copy of the app's, changed as
        // the app's change. Rows arriving at the end are put in below
        // what is seen — the list holding its top still for that one
        // change, rather than its bottom — and the thread then scrolls
        // up to them, so every row comes in from the bottom. (The
        // list's own insert animation fades a row in where it will sit
        // and slides the rows under it down.) Anything else (the rows
        // replaced whole, earlier ones loaded, a row's words) is not
        // animated.
    private func arrivals(_ content: some View, toBottom: @escaping () -> Void) -> some View {
        content.onChange(of: messages) { _, new in took(new, toBottom: toBottom) }
    }

    private func took(_ new: [TranscriptMessage], toBottom: @escaping () -> Void) {
        // Rows after the last while the thread is still settling
        // after it opened are history catching up (the whole
        // transcript arriving after the cached rows), not a reply:
        // they go in with the thread kept at its bottom, not
        // brought in from below.
        let appended = Self.appends(new, to: shown) && !stage.settling
        if !following, !stage.settling {
            // Read further up: the rows go in below, what is read
            // stays still (the list holds its top), and the pill
            // counts them.
            let added = Self.newRows(in: new, after: shown)
            if stage.earlierInView, Self.prepends(new, to: shown), let kept = Self.firstKept(of: shown, in: new) {
                keep(kept)
            }
            shown = new
            showPill(adding: added)
        } else if appended {
            holdTop = true
            shown = new
            // The scroll once the list has the rows and the box its
            // new height (the words sent leave it in the same
            // change): a scroll made before either has landed
            // measures against the old and goes nowhere.
            stage.arrivalEnds?.cancel()
            stage.arrivalEnds = Task { @MainActor in
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
            if stage.earlierInView, Self.prepends(new, to: shown), let kept = Self.firstKept(of: shown, in: new) {
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

    /// The room the thread has changed.
    private func room(_ content: some View, toBottom: @escaping () -> Void) -> some View {
        content
        // The room the thread has changed — the keyboard coming or
        // going, the composer growing: the thread eases to the bottom
        // over about the time the keyboard takes, rather than jumping
        // there while the keyboard is still on its way.
        // While rows arrive, their own scroll takes the thread to the
        // bottom: a second scroll in the middle of it (the composer
        // shrinking as the words sent leave it) fought it. Only while
        // following: read further up, the thread stays where it is.
        .onVisibleHeightChange { if following && !holdTop && !sending { withAnimation(.smooth(duration: 0.35)) { toBottom() } } }
        // On a Mac the composer bar's growth reaches the list as an
        // inset its scroll geometry does not report, so the change
        // above never fired and the last rows went under the box: the
        // composer's own height is watched instead, and the thread
        // scrolled once the new inset has landed — at once, as the box
        // pushes it, not eased.
        .onComposerHeightChange(composerHeight) {
            guard following && !holdTop && !sending else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 30_000_000)
                toBottom()
            }
        }
    }

    /// What opens over the thread: an attachment, a run of tool calls.
    private func presenting(_ content: some View) -> some View {
        content
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

    private var emptyState: some View { emptyState(title: emptyTitle, body: emptyBody) }

    private var emptyWords: String { emptyTitle + "\n" + emptyBody }

    /// Over the hidden first rows: the same list with the same row as the
    /// empty state just shown, so it lines up exactly.
    @ViewBuilder private var heldEmptyList: some View {
        if !shown.isEmpty, !revealed, let heldEmpty {
            List {
                emptyState(title: heldEmpty.title, body: heldEmpty.body)
                    .transcriptCell()
                    .listRowSeparator(.hidden)
                    .plainListRow()
            }
            .listStyle(.plain)
            .noMinimumRowHeight()
            .scrollDisabled(true)
            .allowsHitTesting(false)
        }
    }

    private func emptyState(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold())
            Text(body).foregroundColor(.secondary)
            if let emptyFootnote {
                Text(emptyFootnote).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
