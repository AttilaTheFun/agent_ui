// A picture on its own: the whole screen, pinch to zoom, drag to move
// what you have zoomed into, double tap to go back, and done. On Apple's
// SwiftUI the bar also has share, which is where saving it lives on a
// phone: it needs the picture as a file, and a share sheet, which the
// portable SwiftUI has neither of. The gestures are the same everywhere.

import SwiftUI
#if canImport(AppKit) || canImport(UIKit)
import Foundation
#endif

public struct ImageViewer: View {
    let url: String
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var pinching: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragging: CGSize = .zero
    #if canImport(AppKit) || canImport(UIKit)
    /// The bytes, written to a file so the share sheet offers Save Image
    /// rather than a link to nowhere.
    @State private var file: URL?
    #endif

    public init(url: String) { self.url = url }

    private var scale: CGFloat { max(1, min(zoom * pinching, 8)) }

    public var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    #if canImport(AppKit) || canImport(UIKit)
                    Color.black.opacity(0.92).ignoresSafeArea()
                    #else
                    Color.black.opacity(0.92)
                    #endif
                    // As large as the room, at its own proportions: given
                    // the whole frame (no longest side), the app's picture
                    // fits itself to it.
                    TranscriptImage(url: url, maxEdge: 0)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(x: offset.width + dragging.width, y: offset.height + dragging.height)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                // Anywhere in the room, not only on the picture where it
                // sat before it was zoomed.
                .contentShape(Rectangle())
                // Pinch and drag together, not one after the other: a
                // drag that began with the first finger no longer keeps
                // the second from zooming.
                .gesture(zoomGesture.simultaneously(with: panGesture))
                // Back to where it started, without hunting for it.
                .onTapGesture(count: 2) {
                    zoom = scale > 1 ? 1 : 2
                    offset = .zero
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                #if canImport(AppKit) || canImport(UIKit)
                ToolbarItem(placement: .primaryAction) {
                    if let file {
                        // A file, not a string: that is what puts Save
                        // Image in the sheet beside the apps.
                        ShareLink(item: file) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Share")
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                #endif
            }
        }
        // A sheet on the Mac takes the size of what is in it, and what is
        // in it here is a picture asking how much room there is: left to
        // themselves the two grow into each other and the bar runs off
        // the end. A plain sheet-sized window settles it; a phone's sheet
        // is the screen and needs no telling.
        #if os(macOS)
        .frame(width: 760, height: 600)
        #endif
        #if canImport(AppKit) || canImport(UIKit)
        .task { await fetch() }
        #endif
    }

    #if canImport(AppKit) || canImport(UIKit)
    /// Writes the picture beside the temporary files so it can be shared
    /// as a file. Named after the reference, so opening the same picture
    /// twice does not leave two.
    private func fetch() async {
        guard file == nil, let load = TranscriptImages.data else { return }
        guard let data = await load(url) else { return }
        let name = String(url.split(separator: "/").last ?? "image.png")
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        guard (try? data.write(to: destination, options: .atomic)) != nil else { return }
        file = destination
    }
    #endif

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { pinching = $0.magnification }
            .onEnded { _ in
                zoom = scale
                pinching = 1
                if zoom <= 1 { offset = .zero }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in if scale > 1 { dragging = value.translation } }
            .onEnded { value in
                guard scale > 1 else { dragging = .zero; return }
                offset.width += value.translation.width
                offset.height += value.translation.height
                dragging = .zero
            }
    }
}
