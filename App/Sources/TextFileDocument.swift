import SwiftUI
import UniformTypeIdentifiers

/// A plain-text `FileDocument` for one-shot exports (diagnostics, etc.) —
/// unlike `CaptureFilePlaceholder`, this one's content is real and is
/// written by `fileExporter` directly, since there's no need to keep the
/// file open for streaming appends afterward.
struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
