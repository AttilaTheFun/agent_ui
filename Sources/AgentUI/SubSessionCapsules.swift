import SwiftUI

/// The conversations open from one in a list of them: a capsule each,
/// in a line that scrolls sideways when they do not fit. Tapping one
/// opens it.
public struct SubSessionCapsules: View {
    let items: [SubSession]
    let open: (SubSession) -> Void

    public init(_ items: [SubSession], open: @escaping (SubSession) -> Void) {
        self.items = items
        self.open = open
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    Button { open(item) } label: { capsule(item) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.kind.label): \(item.title)")
                }
            }
        }
    }

    private func capsule(_ item: SubSession) -> some View {
        HStack(spacing: 4) {
            if item.working {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: item.kind.symbol).font(.caption2)
            }
            Text(item.title).font(.caption).lineLimit(1)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: 200)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .contentShape(Capsule())
    }
}
