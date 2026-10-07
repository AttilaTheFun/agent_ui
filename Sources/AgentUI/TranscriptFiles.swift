import SwiftUI
#if canImport(AppKit) || canImport(UIKit)
import Foundation

/// An attachment's bytes as a file of its own, for what wants a file: the
/// system's preview, a share sheet. Written beside the temporary files
/// under the attachment's own name, so opening it twice leaves one.
@MainActor
enum TranscriptFiles {
    /// The file behind a transcript reference (`TranscriptImages.data`),
    /// or nil when the app has no bytes for it.
    static func local(for reference: String) async -> URL? {
        guard let load = TranscriptImages.data, let data = await load(reference) else { return nil }
        let name = String(reference.split(separator: "/").last ?? "attachment")
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(name)
        guard (try? data.write(to: destination, options: .atomic)) != nil else { return nil }
        return destination
    }
}
#endif
