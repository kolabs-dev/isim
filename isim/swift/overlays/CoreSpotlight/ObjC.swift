// isim CoreSpotlight for Objective-C (sdk-src/Frameworks/CoreSpotlight): the classes carry Apple's Objective-C names and
// these members Apple's selectors.
import Foundation
import UniformTypeIdentifiers

extension CSSearchableItemAttributeSet {
    @objc(initWithItemContentType:) convenience init(_objcItemContentType type: String) { self.init(itemContentType: type) }
    @objc(initWithContentType:) convenience init(_objcContentType type: UTTypeReference) { self.init(itemContentType: type.description) }
    @objc(sharedItemContentType) var _objc_sharedItemContentType: UTTypeReference? {
        get { (_values["sharedItemContentType"] as? String).flatMap { UTTypeReference.type(withIdentifier: $0) } }
        set { _values["sharedItemContentType"] = newValue?.description }
    }
    @objc(setValue:forCustomKey:) func _objc_setValue(_ v: AnyObject?, forCustomKey key: CSCustomAttributeKey) { setValue(v as? any NSSecureCoding, forCustomKey: key) }
    @objc(valueForCustomKey:) func _objc_value(forCustomKey key: CSCustomAttributeKey) -> AnyObject? { value(forCustomKey: key) as AnyObject? }
}

extension CSPerson {
    @objc(initWithDisplayName:handles:handleIdentifier:) convenience init(_objcDisplayName d: String?, handles: [String], handleIdentifier: String) {
        self.init(displayName: d, handles: handles, handleIdentifier: handleIdentifier)
    }
    @objc(displayName) var _objc_displayName: String? { displayName }
    @objc(handles) var _objc_handles: [String] { handles }
    @objc(handleIdentifier) var _objc_handleIdentifier: String { handleIdentifier }
    @objc(contactIdentifier) var _objc_contactIdentifier: String? { get { contactIdentifier } set { contactIdentifier = newValue } }
}

extension CSCustomAttributeKey {
    @objc(initWithKeyName:) convenience init?(_objcKeyName k: String) { self.init(keyName: k) }
    @objc(initWithKeyName:searchable:searchableByDefault:unique:multiValued:)
    convenience init?(_objcKeyName k: String, searchable: Bool, searchableByDefault: Bool, unique: Bool, multiValued: Bool) {
        self.init(keyName: k, searchable: searchable, searchableByDefault: searchableByDefault, unique: unique, multiValued: multiValued)
    }
    @objc(keyName) var _objc_keyName: String { keyName }
    @objc(isSearchable) var _objc_isSearchable: Bool { isSearchable }
    @objc(isSearchableByDefault) var _objc_isSearchableByDefault: Bool { isSearchableByDefault }
    @objc(isUnique) var _objc_isUnique: Bool { isUnique }
    @objc(isMultiValued) var _objc_isMultiValued: Bool { isMultiValued }
}

extension CSLocalizedString {
    @objc(initWithLocalizedStrings:) convenience init(_objcLocalizedStrings d: NSDictionary) { self.init(localizedStrings: d as? [AnyHashable: Any] ?? [:]) }
    @objc(localizedString) func _objc_localizedString() -> String { localizedString() }
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
    @objc(updateListenerOptions) var _objc_updateListenerOptions: UInt { get { _updateListenerOptions } set { _updateListenerOptions = newValue } }
}

extension CSSearchableIndex {
    @objc(defaultSearchableIndex) class var _objc_default: CSSearchableIndex { CSSearchableIndex.default() }
    @objc(initWithName:protectionClass:) convenience init(_objcName name: String, protectionClass: String?) {
        self.init(name: name, protectionClass: protectionClass.map { FileProtectionType(rawValue: $0) })
    }
    @objc(indexDelegate) var _objc_indexDelegate: (any CSSearchableIndexDelegate)? { get { indexDelegate } set { indexDelegate = newValue } }
    @objc(beginIndexBatch) func _objc_beginBatch() { beginBatch() }
    @objc(endIndexBatchWithClientState:completionHandler:)
    func _objc_endBatch(_ state: Data, completionHandler: (@convention(block) (NSError?) -> Void)?) {
        endBatch(withClientState: state) { e in completionHandler?(e as NSError?) }
    }
    @objc(endIndexBatchWithExpectedClientState:newClientState:completionHandler:)
    func _objc_endBatch(expected: Data?, new: Data, completionHandler: (@convention(block) (NSError?) -> Void)?) {
        endIndexBatch(expectedClientState: expected, newClientState: new) { e in completionHandler?(e as NSError?) }
    }
    @objc(fetchLastClientStateWithCompletionHandler:)
    func _objc_fetchLastClientState(_ completionHandler: @escaping @convention(block) (Data?, NSError?) -> Void) {
        fetchLastClientState { d, e in completionHandler(d, e as NSError?) }
    }
    @objc(fetchDataForBundleIdentifier:itemIdentifier:contentType:completionHandler:)
    func _objc_fetchData(_ bundle: String, itemIdentifier: String, contentType: UTTypeReference, completionHandler: @escaping @convention(block) (Data?, NSError?) -> Void) {
        guard let t = UTType(contentType.description) else { completionHandler(nil, CSIndexError(.invalidItemError) as NSError); return }
        fetchData(forBundleIdentifier: bundle, itemIdentifier: itemIdentifier, contentType: t) { completionHandler($0, $1 as NSError?) }
    }
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

extension CSSearchQueryContext {
    @objc(fetchAttributes) var _objc_fetchAttributes: [String] { get { fetchAttributes } set { fetchAttributes = newValue } }
    @objc(filterQueries) var _objc_filterQueries: [String] { get { filterQueries } set { filterQueries = newValue } }
    @objc(keyboardLanguage) var _objc_keyboardLanguage: String? { get { keyboardLanguage } set { keyboardLanguage = newValue } }
    @objc(sourceOptions) var _objc_sourceOptions: UInt { get { sourceOptions.rawValue } set { sourceOptions = SourceOptions(rawValue: newValue) } }
}

extension CSSearchQuery {
    @objc(initWithQueryString:attributes:) convenience init(_objcQueryString q: String, attributes: [String]?) {
        let c = CSSearchQueryContext(); c.fetchAttributes = attributes ?? []
        self.init(queryString: q, queryContext: c)
    }
    @objc(initWithQueryString:queryContext:) convenience init(_objcQueryString q: String, queryContext: CSSearchQueryContext?) {
        self.init(queryString: q, queryContext: queryContext)
    }
    @objc(foundItemsHandler) var _objc_foundItemsHandler: (@convention(block) ([CSSearchableItem]) -> Void)? {
        get { foundItemsHandler.map { h in { h($0) } } }
        set { foundItemsHandler = newValue.map { h in { h($0) } } }
    }
    @objc(completionHandler) var _objc_completionHandler: (@convention(block) (NSError?) -> Void)? {
        get { completionHandler.map { h in { h($0) } } }
        set { completionHandler = newValue.map { h in { h($0 as NSError?) } } }
    }
    @objc(foundItemCount) var _objc_foundItemCount: Int { foundItemCount }
    @objc(isCancelled) var _objc_isCancelled: Bool { isCancelled }
    @objc(protectionClasses) var _objc_protectionClasses: [String] {
        get { protectionClasses.map(\.rawValue) }
        set { protectionClasses = newValue.map { FileProtectionType(rawValue: $0) } }
    }
    @objc(start) func _objc_start() { start() }
    @objc(cancel) func _objc_cancel() { cancel() }
}

@available(iOS 18.0, *)
extension CSUserQueryContext {
    @objc(userQueryContext) class func _objc_userQueryContext() -> CSUserQueryContext { CSUserQueryContext() }
    @objc(userQueryContextWithCurrentSuggestion:) class func _objc_userQueryContext(currentSuggestion s: CSSuggestion?) -> CSUserQueryContext { CSUserQueryContext(currentSuggestion: s) }
    @objc(maxResultCount) var _objc_maxResultCount: Int { get { maxResultCount } set { maxResultCount = newValue } }
    @objc(maxSuggestionCount) var _objc_maxSuggestionCount: Int { get { maxSuggestionCount } set { maxSuggestionCount = newValue } }
    @objc(enableRankedResults) var _objc_enableRankedResults: Bool { get { enableRankedResults } set { enableRankedResults = newValue } }
    @objc(maxRankedResultCount) var _objc_maxRankedResultCount: Int { get { maxRankedResultCount } set { maxRankedResultCount = newValue } }
    @objc(disableSemanticSearch) var _objc_disableSemanticSearch: Bool { get { disableSemanticSearch } set { disableSemanticSearch = newValue } }
}

@available(iOS 18.0, *)
extension CSSuggestion {
    @objc(localizedAttributedSuggestion) var _objc_localizedAttributedSuggestion: NSAttributedString { NSAttributedString(string: _text) }
    @objc(suggestionKind) var _objc_suggestionKind: Int { suggestionKind.rawValue }
    @objc(compare:) func _objc_compare(_ other: CSSuggestion) -> ComparisonResult { compare(other) }
}

@available(iOS 18.0, *)
extension CSUserQuery {
    @objc(initWithUserQueryString:userQueryContext:) convenience init(_objcUserQueryString q: String?, userQueryContext: CSUserQueryContext?) {
        self.init(userQueryString: q, userQueryContext: userQueryContext)
    }
    @objc(foundSuggestionsHandler) var _objc_foundSuggestionsHandler: (@convention(block) ([CSSuggestion]) -> Void)? {
        get { foundSuggestionsHandler.map { h in { h($0) } } }
        set { foundSuggestionsHandler = newValue.map { h in { h($0) } } }
    }
    @objc(foundSuggestionCount) var _objc_foundSuggestionCount: Int { foundSuggestionCount }
    @objc(prepare) class func _objc_prepare() { prepare() }
    @objc(userEngagedWithItem:visibleItems:userInteractionType:)
    func _objc_userEngaged(_ item: CSSearchableItem, visibleItems: [CSSearchableItem], userInteractionType: Int) {
        userEngaged(Item(item: item), visibleItems: visibleItems.map { Item(item: $0) }, interaction: UserInteractionKind(rawValue: userInteractionType) ?? .select)
    }
    @objc(userEngagedWithSuggestion:visibleSuggestions:userInteractionType:)
    func _objc_userEngaged(_ s: CSSuggestion, visibleSuggestions: [CSSuggestion], userInteractionType: Int) {
        userEngaged(Suggestion(suggestion: s), visibleSuggestions: visibleSuggestions.map { Suggestion(suggestion: $0) }, interaction: UserInteractionKind(rawValue: userInteractionType) ?? .select)
    }
}
