import MacTermXCore
import SwiftUI
import UniformTypeIdentifiers

/// A `FileDocument` wrapper so `fileExporter` can save a `SerialProfile`
/// as the same versioned JSON `ProfileStore` writes internally.
struct ProfileFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let profile: SerialProfile

    init(profile: SerialProfile) {
        self.profile = profile
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        profile = try JSONDecoder().decode(SerialProfile.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile)
        return FileWrapper(regularFileWithContents: data)
    }
}
