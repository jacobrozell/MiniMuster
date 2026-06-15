import SwiftUI
import UniformTypeIdentifiers

/// Minimal text `FileDocument` for `.fileExporter` (CSV / JSON downloads).
struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json, .plainText] }

    var text: String
    var contentType: UTType

    init(text: String, contentType: UTType = .plainText) {
        self.text = text
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(data: data, encoding: .utf8) ?? ""
        contentType = .plainText
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

extension Date {
    /// `YYYY-MM-DD` stamp for export filenames. Mirrors the web `stamp()`.
    var fileStamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}
