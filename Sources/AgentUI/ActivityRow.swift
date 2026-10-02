import SwiftUI

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
