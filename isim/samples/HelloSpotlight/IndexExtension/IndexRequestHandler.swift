// HelloSpotlight's Spotlight index extension (com.apple.spotlight.index): Spotlight runs it to reindex the notes while
// the app is not running.
import Foundation
import CoreSpotlight

final class IndexRequestHandler: CSIndexExtensionRequestHandler {
    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        NSLog("spx reindex all")
        CSSearchableIndex(name: "notes").indexSearchableItems(notes.map(searchableItem)) { _ in acknowledgementHandler() }
    }
    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        NSLog("spx reindex %@", identifiers.joined(separator: ","))
        CSSearchableIndex(name: "notes").indexSearchableItems(notes.filter { identifiers.contains($0.id) }.map(searchableItem)) { _ in acknowledgementHandler() }
    }
}
