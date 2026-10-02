import SwiftUI

extension View {
    /// The remove glyph's white-on-dark palette (the two-colour
    /// `foregroundStyle` is Apple's SwiftUI only).
    func removeGlyphStyle() -> some View {
        foregroundStyle(.white, .black.opacity(0.6))
    }
}
