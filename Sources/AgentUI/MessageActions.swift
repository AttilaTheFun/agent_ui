import SwiftUI

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
