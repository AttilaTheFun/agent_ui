import SwiftUI

/// A run of tool calls as one line — "Made 12 tool calls" — behind the
/// same chevron a single call has; tapping opens the sheet that lists them.
public struct ToolCallsRow: View {
    let run: [TranscriptMessage]
    @Environment(\.openedToolCalls) private var opened

    public init(run: [TranscriptMessage]) { self.run = run }

    public var body: some View {
        let count = TranscriptBlock.callCount(run)
        Button {
            opened.wrappedValue = run
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
