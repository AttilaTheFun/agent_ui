import SwiftUI

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
                                .selectableText()
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
