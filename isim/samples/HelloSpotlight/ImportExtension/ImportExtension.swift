// HelloSpotlight's Spotlight import extension (com.apple.spotlight.import): Spotlight runs it for the .spnote documents
// in the app's Documents. The first line is the title, the rest the description, #words the keywords.
import Foundation
import CoreSpotlight

final class NoteImporter: CSImportExtension {
    override func update(_ attributes: CSSearchableItemAttributeSet, forFileAt contentURL: URL) throws {
        let text = try String(contentsOf: contentURL, encoding: .utf8)
        let lines = text.split(separator: "\n").map(String.init)
        attributes.title = lines.first
        attributes.contentDescription = lines.dropFirst().joined(separator: " ")
        attributes.keywords = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).filter { $0.hasPrefix("#") }.map { String($0.dropFirst()) }
        NSLog("spi imported %@: %@", contentURL.lastPathComponent, attributes.title ?? "-")
    }
}
