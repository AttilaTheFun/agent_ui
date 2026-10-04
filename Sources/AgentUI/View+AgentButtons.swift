import SwiftUI

extension View {
    /// The composer's round action button (send, stop). Drawn rather than
    /// styled: a system button's circle sits inside the frame it is given
    /// by an amount only it knows, which left the send button smaller than
    /// the gauge beside it and shy of the corner. A filled circle of our
    /// own is exactly `controlHeight` across and exactly where it is put.
    public func agentCircleButton(tint: Color = AgentComposerMetrics.sendTint) -> some View {
        buttonStyle(.plain)
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(width: AgentComposerMetrics.controlHeight, height: AgentComposerMetrics.controlHeight)
            .background(Circle().fill(tint))
    }

    /// A round button's label, taking taps in the room around the circle
    /// it is drawn in (`controlsRoom`, plus `gap` before it): a button is
    /// hit only within its own frame, so the label is the circle and that
    /// room, transparent.
    func agentCircleTarget(tint: Color = AgentComposerMetrics.sendTint) -> some View {
        let room = AgentComposerMetrics.controlsRoom
        return font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(width: AgentComposerMetrics.controlHeight, height: AgentComposerMetrics.controlHeight)
            .background(Circle().fill(tint))
            .padding(EdgeInsets(top: room.top, leading: AgentComposerMetrics.gap, bottom: room.bottom, trailing: room.trailing))
            .contentShape(Rectangle())
    }

    /// A composer pill (the model, the effort, a mode): a solid tinted
    /// capsule, which reads against the glass box where glass-on-glass all
    /// but disappears.
    public func agentPillButton() -> some View {
        buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            // The row's one height, so a capsule and the round button
            // beside it line up top and bottom.
            .frame(height: AgentComposerMetrics.controlHeight)
            .background(Capsule().fill(Color.primary.opacity(0.1)))
    }

    /// A composer's small round control (attach): a solid tinted circle.
    public func agentSoftCircleButton() -> some View {
        buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .frame(width: AgentComposerMetrics.controlHeight, height: AgentComposerMetrics.controlHeight)
            .background(Circle().fill(Color.primary.opacity(0.1)))
    }
}
