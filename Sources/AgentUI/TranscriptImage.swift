import SwiftUI

/// One picture, however this app loads them.
struct TranscriptImage: View {
    let url: String
    /// The longest side it may take; 0 for as much room as there is.
    var maxEdge: CGFloat = 0

    var body: some View {
        if let render = TranscriptImages.render {
            render(url, maxEdge)
        } else {
            AsyncImage(url: URL(string: url)) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.gray.opacity(0.2).frame(width: 96, height: 96)
            }
        }
    }
}
