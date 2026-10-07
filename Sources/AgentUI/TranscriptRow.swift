import SwiftUI

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
                            .selectableText()
                    }
                }
            }
            .padding(.horizontal, TranscriptMetrics.edgeInset)
        case .assistant:
            VStack(alignment: .leading, spacing: 6) {
                if !message.text.isEmpty { AssistantBubble(text: message.text) }
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
        case "goal", "goal-met":
            GoalRow(text: message.text, met: message.toolName == "goal-met")
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
