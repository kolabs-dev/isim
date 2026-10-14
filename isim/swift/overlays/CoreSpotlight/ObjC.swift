// isim CoreSpotlight for Objective-C (sdk-src/Frameworks/CoreSpotlight): the classes carry Apple's Objective-C names and
// these members Apple's selectors.
import Foundation

extension CSSearchableItemAttributeSet {
    @objc(initWithItemContentType:) convenience init(_objcItemContentType type: String) { self.init(itemContentType: type) }
    @objc(contentType) var _objc_contentType: String { contentType }
    @objc(title) var _objc_title: String? { get { title } set { title = newValue } }
    @objc(displayName) var _objc_displayName: String? { get { displayName } set { displayName = newValue } }
    @objc(contentDescription) var _objc_contentDescription: String? { get { contentDescription } set { contentDescription = newValue } }
    @objc(keywords) var _objc_keywords: [String]? { get { keywords } set { keywords = newValue } }
    @objc(thumbnailData) var _objc_thumbnailData: Data? { get { thumbnailData } set { thumbnailData = newValue } }
    @objc(thumbnailURL) var _objc_thumbnailURL: URL? { get { thumbnailURL } set { thumbnailURL = newValue } }
    @objc(contentURL) var _objc_contentURL: URL? { get { contentURL } set { contentURL = newValue } }
    @objc(URL) var _objc_url: URL? { get { url } set { url = newValue } }
    @objc(identifier) var _objc_identifier: String? { get { identifier } set { identifier = newValue } }
    @objc(relatedUniqueIdentifier) var _objc_relatedUniqueIdentifier: String? { get { relatedUniqueIdentifier } set { relatedUniqueIdentifier = newValue } }
    @objc(phoneNumbers) var _objc_phoneNumbers: [String]? { get { phoneNumbers } set { phoneNumbers = newValue } }
    @objc(emailAddresses) var _objc_emailAddresses: [String]? { get { emailAddresses } set { emailAddresses = newValue } }
    @objc(startDate) var _objc_startDate: Date? { get { startDate } set { startDate = newValue } }
    @objc(endDate) var _objc_endDate: Date? { get { endDate } set { endDate = newValue } }
    @objc(rating) var _objc_rating: NSNumber? { get { rating } set { rating = newValue } }
}

extension CSSearchableItem {
    @objc(initWithUniqueIdentifier:domainIdentifier:attributeSet:)
    convenience init(_objcUniqueIdentifier id: String?, domainIdentifier: String?, attributeSet: CSSearchableItemAttributeSet) {
        self.init(uniqueIdentifier: id, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
    @objc(uniqueIdentifier) var _objc_uniqueIdentifier: String { get { uniqueIdentifier } set { uniqueIdentifier = newValue } }
    @objc(domainIdentifier) var _objc_domainIdentifier: String? { get { domainIdentifier } set { domainIdentifier = newValue } }
    @objc(attributeSet) var _objc_attributeSet: CSSearchableItemAttributeSet { get { attributeSet } set { attributeSet = newValue } }
    @objc(expirationDate) var _objc_expirationDate: Date? { get { expirationDate } set { expirationDate = newValue } }
}

extension CSSearchableIndex {
    @objc(defaultSearchableIndex) class var _objc_default: CSSearchableIndex { self.default() }
    @objc(isIndexingAvailable) class func _objc_isIndexingAvailable() -> Bool { isIndexingAvailable() }
    @objc(initWithName:) convenience init(_objcName name: String) { self.init(name: name) }
    @objc(indexSearchableItems:completionHandler:)
    func _objc_index(_ items: [CSSearchableItem], completionHandler: (@convention(block) (NSError?) -> Void)?) {
        indexSearchableItems(items) { e in completionHandler?(e as NSError?) }
    }
    @objc(deleteSearchableItemsWithIdentifiers:completionHandler:)
    func _objc_delete(_ identifiers: [String], completionHandler: (@convention(block) (NSError?) -> Void)?) {
        deleteSearchableItems(withIdentifiers: identifiers) { e in completionHandler?(e as NSError?) }
    }
    @objc(deleteSearchableItemsWithDomainIdentifiers:completionHandler:)
    func _objc_deleteDomains(_ domains: [String], completionHandler: (@convention(block) (NSError?) -> Void)?) {
        deleteSearchableItems(withDomainIdentifiers: domains) { e in completionHandler?(e as NSError?) }
    }
    @objc(deleteAllSearchableItemsWithCompletionHandler:)
    func _objc_deleteAll(_ completionHandler: (@convention(block) (NSError?) -> Void)?) {
        deleteAllSearchableItems { e in completionHandler?(e as NSError?) }
    }
}

extension CSSearchQuery {
    @objc(initWithQueryString:attributes:) convenience init(_objcQueryString q: String, attributes: [String]?) {
        self.init(queryString: q, attributes: attributes)
    }
    @objc(foundItemsHandler) var _objc_foundItemsHandler: (@convention(block) ([CSSearchableItem]) -> Void)? {
        get { foundItemsHandler.map { h in { h($0) } } }
        set { foundItemsHandler = newValue.map { h in { h($0) } } }
    }
    @objc(completionHandler) var _objc_completionHandler: (@convention(block) (NSError?) -> Void)? {
        get { completionHandler.map { h in { h($0) } } }
        set { completionHandler = newValue.map { h in { h($0 as NSError?) } } }
    }
    @objc(start) func _objc_start() { start() }
    @objc(cancel) func _objc_cancel() { cancel() }
}
