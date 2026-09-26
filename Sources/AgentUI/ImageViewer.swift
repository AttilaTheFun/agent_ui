// A picture on its own: the whole screen, pinch to zoom, drag to move
// what you have zoomed into, and two things in the bar — done, and
// share, which is where saving it lives on a phone.
//
// Apple's SwiftUI has gestures, files and a share sheet. The portable
// one has none of the three, so there it is the picture and a way out.

import SwiftUI
#if canImport(AppKit) || canImport(UIKit)
import Foundation
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

public struct ImageViewer: View {
    let url: String
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var pinching: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragging: CGSize = .zero
    /// The bytes, written to a file so the share sheet offers Save Image
    /// rather than a link to nowhere.
    @State private var file: URL?
    #if canImport(UIKit)
    /// The picture itself, for UIKit's zooming scroll view.
    @State private var image: UIImage?
    #endif

    public init(url: String) { self.url = url }

    private var scale: CGFloat { max(1, min(zoom * pinching, 8)) }

    public var body: some View {
        NavigationStack {
            GeometryReader { geo in
              ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                #if canImport(UIKit)
                // On a phone, UIKit's own zooming scroll view: pinch, pan
                // and double tap as the Photos app has them, at the
                // display's pace, the picture drawn once.
                if let image {
                    ZoomingImage(image: image)
                } else {
                    TranscriptImage(url: url, maxEdge: min(geo.size.width, geo.size.height))
                }
                #else
                // Told how much room there is, so the app hands back a
                // picture of a definite size: a view happy at any size
                // gets none at all inside a stack that has none either.
                TranscriptImage(url: url, maxEdge: min(geo.size.width, geo.size.height))
                    .scaleEffect(scale)
                    .offset(x: offset.width + dragging.width, y: offset.height + dragging.height)
                    .gesture(zoomGesture)
                    .gesture(panGesture)
                    // Back to where it started, without hunting for it.
                    .onTapGesture(count: 2) {
                        zoom = scale > 1 ? 1 : 2
                        offset = .zero
                    }
                #endif
              }
              .frame(width: geo.size.width, height: geo.size.height)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
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
        .task { await fetch() }
    }

    /// Writes the picture beside the temporary files so it can be shared
    /// as a file. Named after the reference, so opening the same picture
    /// twice does not leave two.
    private func fetch() async {
        guard file == nil, let load = TranscriptImages.data else { return }
        guard let data = await load(url) else { return }
        let name = String(url.split(separator: "/").last ?? "image.png")
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        #if canImport(UIKit)
        image = UIImage(data: data)
        #endif
        guard (try? data.write(to: destination, options: .atomic)) != nil else { return }
        file = destination
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { pinching = $0 }
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

#if canImport(UIKit)
/// A picture in a UIScrollView that zooms it: fitted to the screen at
/// first, up to 8× by pinching, panned when zoomed, double tap to go to
/// 2× where tapped and back.
struct ZoomingImage: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = FittingScrollView()
        scroll.coordinator = context.coordinator
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 8
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .clear
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        scroll.addSubview(view)
        context.coordinator.imageView = view
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(tap)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.fit(in: scroll)
    }

    /// Fits the picture to itself whenever it is laid out at a new size.
    final class FittingScrollView: UIScrollView {
        weak var coordinator: Coordinator?
        override func layoutSubviews() {
            super.layoutSubviews()
            coordinator?.fit(in: self)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        private var fittedSize: CGSize = .zero

        /// The picture at the scroll view's size, while not zoomed.
        func fit(in scroll: UIScrollView) {
            guard let imageView, scroll.bounds.size != fittedSize, scroll.zoomScale == 1 else { return }
            fittedSize = scroll.bounds.size
            imageView.frame = CGRect(origin: .zero, size: scroll.bounds.size)
            scroll.contentSize = scroll.bounds.size
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTap(_ tap: UITapGestureRecognizer) {
            guard let scroll = tap.view as? UIScrollView, let imageView else { return }
            if scroll.zoomScale > 1 {
                scroll.setZoomScale(1, animated: true)
            } else {
                let point = tap.location(in: imageView)
                let size = CGSize(width: scroll.bounds.width / 2, height: scroll.bounds.height / 2)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                       width: size.width, height: size.height), animated: true)
            }
        }
    }
}
#endif

#else

/// Without gestures or a share sheet: the picture, and a way back.
public struct ImageViewer: View {
    let url: String
    @Environment(\.dismiss) private var dismiss

    public init(url: String) { self.url = url }

    public var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.92)
                    TranscriptImage(url: url, maxEdge: min(geo.size.width, geo.size.height))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

#endif
