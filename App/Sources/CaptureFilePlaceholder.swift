import SwiftUI
import UniformTypeIdentifiers

/// An empty placeholder document, just so `fileExporter` can drive the
/// standard macOS save panel for picking a capture destination. Its
/// content is never read — `ConnectionViewModel.startCapture(to:)` opens
/// the resulting URL itself and appends to it as data arrives, rather
/// than buffering the whole capture in memory as a `FileDocument` would.
struct CaptureFilePlaceholder: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    init() {}
    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
