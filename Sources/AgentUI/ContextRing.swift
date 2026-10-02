import SwiftUI

/// How full an agent's context is: a ring that fills as the conversation
/// grows, amber past three quarters and red at the edge. Tapping it is the
/// app's business (a menu with the numbers, say).
public struct ContextRing: View {
    let used: Int
    let limit: Int
    let size: CGFloat

    public init(used: Int, limit: Int, size: CGFloat = 18) {
        self.used = used
        self.limit = limit
        self.size = size
    }

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(limit)))
    }

    /// Light grey while there is room, and only then a warning: the gauge
    /// is something to glance at, not something to be told about.
    private var tint: Color {
        fraction >= 0.9 ? .red : (fraction >= 0.75 ? .orange : Color(white: 0.55))
    }

    /// Thicker as the ring grows, so a gauge the size of a button does not
    /// read as a hairline: a ring the height of the composer's controls is
    /// 4pt thick.
    private var lineWidth: CGFloat { max(2, size / 9) }

    public var body: some View {
        // The stroke straddles the path, so the drawn circle is inset by
        // half of it: `size` is then the ring's outside diameter, which is
        // what lines it up with a button beside it.
        let inner = max(1, size - lineWidth)
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.28), lineWidth: lineWidth)
                .frame(width: inner, height: inner)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, lineWidth: lineWidth)
                .frame(width: inner, height: inner)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(ContextRing.summary(used: used, limit: limit))
    }

    /// "42,100 of 200,000 tokens (21%)".
    public static func summary(used: Int, limit: Int) -> String {
        let percent = limit > 0 ? Int((Double(used) / Double(limit) * 100).rounded()) : 0
        return "\(grouped(used)) of \(grouped(limit)) tokens (\(percent)%)"
    }

    /// Thousands separated, without Foundation (not every host has it).
    public static func grouped(_ value: Int) -> String {
        let digits = Array(String(max(0, value)))
        var out = ""
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { out.append(",") }
            out.append(digit)
        }
        return out
    }
}
