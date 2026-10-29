import SwiftUI

/// The conversations open from this one, a row each just above the
/// composer, until each is ended: they stay in reach however far the
/// thread scrolls. Tapping a row opens it; its ✕ ends it.
struct SubSessionRows: View {
    let items: [SubSession]
    let open: (SubSession) -> Void
    /// Nil: the rows have no ✕ (the app ends them some other way).
    let end: ((SubSession) -> Void)?

    var body: some View {
        VStack(spacing: AgentComposerMetrics.gap) {
            ForEach(items) { item in
                // The composer's own box: a row is part of it.
                AgentGlassBox { row(item) }
            }
        }
    }

    private func row(_ item: SubSession) -> some View {
        HStack(spacing: 0) {
            Button { open(item) } label: {
                HStack(spacing: AgentComposerMetrics.gap) {
                    Image(systemName: item.kind.symbol)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(item.detail ?? item.kind.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .lineLimit(1)
                    Spacer(minLength: AgentComposerMetrics.gap)
                    if item.working { ProgressView().controlSize(.small) }
                }
                .padding(.leading, AgentComposerMetrics.textInset)
                .padding(.vertical, AgentComposerMetrics.gap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.kind.label): \(item.title)")
            if let end {
                Button { end(item) } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: AgentComposerMetrics.controlHeight, height: AgentComposerMetrics.controlHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End \(item.kind.label.lowercased())")
            } else {
                Color.clear.frame(width: AgentComposerMetrics.textInset, height: 1)
            }
        }
    }
}
