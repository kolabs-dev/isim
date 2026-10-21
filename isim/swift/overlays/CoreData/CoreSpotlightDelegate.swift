// NSCoreDataCoreSpotlightDelegate's members that use CoreSpotlight's types (isim's CoreSpotlight classes are its Swift
// overlay's): the Objective-C class implements them; subclasses override them here like on Apple's.
import Foundation
import CoreSpotlight

extension NSCoreDataCoreSpotlightDelegate {
    /// The attributes Spotlight indexes for an object: by default its attributes marked isIndexedBySpotlight (nil: none).
    @objc(attributeSetForObject:) open func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        _defaultAttributeSet(for: object) as? CSSearchableItemAttributeSet
    }
    @objc(searchableIndex:reindexAllSearchableItemsWithAcknowledgementHandler:)
    open func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        _reindexAll(acknowledgementHandler)
    }
    @objc(searchableIndex:reindexSearchableItemsWithIdentifiers:acknowledgementHandler:)
    open func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        _reindex(identifiers: identifiers, acknowledgementHandler)
    }
}
