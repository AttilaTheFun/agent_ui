import SwiftUI

/// A pill's label: a title with the up/down chevron of a picker.
public struct AgentPillLabel: View {
    let title: String

    public init(_ title: String) { self.title = title }

    public var body: some View {
        HStack(spacing: 4) {
            Text(title).lineLimit(1)
            Image(systemName: "chevron.up.chevron.down").font(.caption2)
        }
    }
}
