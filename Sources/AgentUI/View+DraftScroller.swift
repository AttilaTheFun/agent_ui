import SwiftUI

extension View {
    /// The draft's lines: up to ten in the field, which then scrolls its
    /// own text; on a Mac, all of them, in `draftScroller`'s scroll view.
    @ViewBuilder func draftLineLimit() -> some View {
        #if os(macOS)
        lineLimit(1...)
        #else
        lineLimit(1...10)
        #endif
    }

    /// On a Mac, the draft in a scroll view of its own, ten lines tall at
    /// most, kept at its end while the caret is there. AppKit's field,
    /// left to scroll itself past ten lines, scrolls to the caret only as
    /// it is typed into, and before it has grown by a new line: after a
    /// Shift-Return the new empty last line stayed out of sight, and
    /// could not be scrolled to, until something was typed on it. Grown
    /// to its full height here, the field has nothing to scroll; this
    /// scroll view shows the end of the draft as it changes. Elsewhere
    /// the field scrolls itself.
    @ViewBuilder func draftScroller(draft: String, selection: DraftSelection?) -> some View {
        #if os(macOS)
        modifier(DraftScroller(draft: draft, atEnd: DraftScroller.caretAtEnd(selection, in: draft)))
        #else
        self
        #endif
    }
}

#if os(macOS)
/// The Mac's draft scroll view (`draftScroller`).
private struct DraftScroller: ViewModifier {
    let draft: String
    let atEnd: Bool
    @State private var height: CGFloat = 0
    @State private var line: CGFloat = 0
    private static let end = "draft-end"

    static func caretAtEnd(_ selection: DraftSelection?, in text: String) -> Bool {
        guard let selection else { return true }
        if case .selection(let range) = selection.indices { return range.upperBound == text.endIndex }
        return false
    }

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    content
                        .background(GeometryReader { geometry in
                            Color.clear.onChange(of: geometry.size.height, initial: true) { _, new in height = new }
                        })
                    Color.clear.frame(height: 0).id(Self.end)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // As tall as the draft, up to ten of its lines.
            .frame(height: height > 0 && line > 0 ? min(height, line * 10) : nil)
            .background(
                // One line of the draft's font, measured, for the ten.
                Text("M").hidden().background(GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.size.height, initial: true) { _, new in line = new }
                })
            )
            .onChange(of: draft) {
                guard atEnd else { return }
                // Once the field has its new height.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    proxy.scrollTo(Self.end, anchor: .bottom)
                }
            }
        }
    }
}
#endif
