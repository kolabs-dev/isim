// isim Contacts (issue #420): change history — the address book numbers its changes (adds, updates, deletes, groups and
// their members) with the save request's transaction author, in $ISIM_DATA/Library/AddressBook/history.json; a history
// token is the last number an app saw. Apple's API reads it from Objective-C only (enumeratorForChangeHistoryFetchRequest:
// error: is unavailable in Swift); isim's Contacts.framework has that method over _isim_ members here. Also
// CNContactsUserDefaults.
import Foundation

struct _CNChange: Codable {
    var seq: Int
    var kind: String            // addContact updateContact deleteContact addGroup updateGroup deleteGroup addMember removeMember
    var id: String              // the contact or group
    var group: String? = nil    // for members
    var author: String? = nil
}

enum _CNHistory {
    /// how many changes are kept: a token older than that gets a drop-everything event
    static let keep = 500
    static var path: String { (_Privacy.deviceDir("Library/AddressBook") as NSString).appendingPathComponent("history.json") }
    static func load() -> [_CNChange] { _Privacy.readJSON([_CNChange].self, path) ?? [] }
    static func last(_ log: [_CNChange]) -> Int { log.last?.seq ?? 0 }
    static func token(_ seq: Int) -> Data { Data("isim-contacts-history:\(seq)".utf8) }
    static func seq(_ token: Data?) -> Int? {
        guard let t = token, let s = String(data: t, encoding: .utf8), s.hasPrefix("isim-contacts-history:") else { return nil }
        return Int(s.dropFirst("isim-contacts-history:".count))
    }
    static func record(_ changes: [(String, String, String?)], author: String?) {
        guard !changes.isEmpty else { return }
        var log = load()
        var n = last(log)
        for (kind, id, group) in changes { n += 1; log.append(_CNChange(seq: n, kind: kind, id: id, group: group, author: author)) }
        if log.count > keep { log.removeFirst(log.count - keep) }
        _Privacy.writeJSON(log, path)
    }
}

@objc(CNChangeHistoryFetchRequest) open class CNChangeHistoryFetchRequest: CNFetchRequest, NSSecureCoding, @unchecked Sendable {
    @objc open var startingToken: Data?
    open var additionalContactKeyDescriptors: [CNKeyDescriptor]?
    @objc open var shouldUnifyResults = true
    @objc open var mutableObjects = false
    @objc open var includeGroupChanges = false
    @objc open var excludedTransactionAuthors: [String]?
    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(startingToken, forKey: "startingToken"); coder.encode(includeGroupChanges, forKey: "includeGroupChanges")
        coder.encode(mutableObjects, forKey: "mutableObjects"); coder.encode(excludedTransactionAuthors, forKey: "excludedTransactionAuthors")
    }
    public required init?(coder: NSCoder) {
        startingToken = coder.decodeObject(forKey: "startingToken") as? Data
        includeGroupChanges = coder.decodeBool(forKey: "includeGroupChanges"); mutableObjects = coder.decodeBool(forKey: "mutableObjects")
        excludedTransactionAuthors = coder.decodeObject(forKey: "excludedTransactionAuthors") as? [String]
        super.init()
    }
    @objc(additionalContactKeyDescriptors) var _objc_additional: [NSString]? {
        get { additionalContactKeyDescriptors.map { _cnKeyStrings($0).sorted().map { $0 as NSString } } }
        set { additionalContactKeyDescriptors = newValue?.map { $0 as String as CNKeyDescriptor } }
    }
}

/// the result of a fetch, with the history token it was read at (Apple's CNFetchResult; Objective-C apps get
/// Contacts.framework's class of the same name, since a Swift generic class cannot be one)
open class CNFetchResult<ValueType: AnyObject>: NSObject, @unchecked Sendable {
    open private(set) var value: ValueType
    open private(set) var currentHistoryToken: Data
    init(value: ValueType, currentHistoryToken: Data) { self.value = value; self.currentHistoryToken = currentHistoryToken }
}

@objc(CNChangeHistoryEventVisitor) public protocol CNChangeHistoryEventVisitor: NSObjectProtocol {
    @objc(visitDropEverythingEvent:) func visit(_ event: CNChangeHistoryDropEverythingEvent)
    @objc(visitAddContactEvent:) func visit(_ event: CNChangeHistoryAddContactEvent)
    @objc(visitUpdateContactEvent:) func visit(_ event: CNChangeHistoryUpdateContactEvent)
    @objc(visitDeleteContactEvent:) func visit(_ event: CNChangeHistoryDeleteContactEvent)
    @objc(visitAddGroupEvent:) optional func visit(_ event: CNChangeHistoryAddGroupEvent)
    @objc(visitUpdateGroupEvent:) optional func visit(_ event: CNChangeHistoryUpdateGroupEvent)
    @objc(visitDeleteGroupEvent:) optional func visit(_ event: CNChangeHistoryDeleteGroupEvent)
    @objc(visitAddMemberToGroupEvent:) optional func visitAddMember(_ event: CNChangeHistoryAddMemberToGroupEvent)
    @objc(visitRemoveMemberFromGroupEvent:) optional func visitRemoveMember(_ event: CNChangeHistoryRemoveMemberFromGroupEvent)
    @objc(visitAddSubgroupToGroupEvent:) optional func visitAddSubgroup(_ event: CNChangeHistoryAddSubgroupToGroupEvent)
    @objc(visitRemoveSubgroupFromGroupEvent:) optional func visitRemoveSubgroup(_ event: CNChangeHistoryRemoveSubgroupFromGroupEvent)
}

@objc(CNChangeHistoryEvent) open class CNChangeHistoryEvent: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) { super.init() }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    @objc(acceptEventVisitor:) open func accept(_ visitor: CNChangeHistoryEventVisitor) {}
}
@objc(CNChangeHistoryDropEverythingEvent) open class CNChangeHistoryDropEverythingEvent: CNChangeHistoryEvent, @unchecked Sendable {
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visit(self) }
}
@objc(CNChangeHistoryAddContactEvent) open class CNChangeHistoryAddContactEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var contact: CNContact = CNContact()
    @objc open private(set) var containerIdentifier: String?
    init(_ c: CNContact, _ container: String?) { contact = c; containerIdentifier = container; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visit(self) }
}
@objc(CNChangeHistoryUpdateContactEvent) open class CNChangeHistoryUpdateContactEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var contact: CNContact = CNContact()
    init(_ c: CNContact) { contact = c; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visit(self) }
}
@objc(CNChangeHistoryDeleteContactEvent) open class CNChangeHistoryDeleteContactEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var contactIdentifier: String = ""
    init(_ id: String) { contactIdentifier = id; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visit(self) }
}
@objc(CNChangeHistoryAddGroupEvent) open class CNChangeHistoryAddGroupEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var group: CNGroup = CNGroup()
    @objc open private(set) var containerIdentifier: String = "isim-local"
    init(_ g: CNGroup) { group = g; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visit?(self) }
}
@objc(CNChangeHistoryUpdateGroupEvent) open class CNChangeHistoryUpdateGroupEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var group: CNGroup = CNGroup()
    init(_ g: CNGroup) { group = g; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visit?(self) }
}
@objc(CNChangeHistoryDeleteGroupEvent) open class CNChangeHistoryDeleteGroupEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var groupIdentifier: String = ""
    init(_ id: String) { groupIdentifier = id; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visit?(self) }
}
@objc(CNChangeHistoryAddMemberToGroupEvent) open class CNChangeHistoryAddMemberToGroupEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var member: CNContact = CNContact()
    @objc open private(set) var group: CNGroup = CNGroup()
    init(_ m: CNContact, _ g: CNGroup) { member = m; group = g; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visitAddMember?(self) }
}
@objc(CNChangeHistoryRemoveMemberFromGroupEvent) open class CNChangeHistoryRemoveMemberFromGroupEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var member: CNContact = CNContact()
    @objc open private(set) var group: CNGroup = CNGroup()
    init(_ m: CNContact, _ g: CNGroup) { member = m; group = g; super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visitRemoveMember?(self) }
}
/// isim's address book has no subgroups: these events are never produced
@objc(CNChangeHistoryAddSubgroupToGroupEvent) open class CNChangeHistoryAddSubgroupToGroupEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var subgroup: CNGroup = CNGroup()
    @objc open private(set) var group: CNGroup = CNGroup()
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visitAddSubgroup?(self) }
}
@objc(CNChangeHistoryRemoveSubgroupFromGroupEvent) open class CNChangeHistoryRemoveSubgroupFromGroupEvent: CNChangeHistoryEvent, @unchecked Sendable {
    @objc open private(set) var subgroup: CNGroup = CNGroup()
    @objc open private(set) var group: CNGroup = CNGroup()
    open override func accept(_ visitor: CNChangeHistoryEventVisitor) { visitor.visitRemoveSubgroup?(self) }
}

extension CNContactStore {
    /// the events since the request's token (adapted: the device's change log; an unknown or too old token, or none,
    /// starts again with a drop-everything event and every contact the app may read)
    func _historyEvents(_ r: CNChangeHistoryFetchRequest) throws -> ([CNChangeHistoryEvent], Data) {
        let readable = try self.readable()
        let book = _CNDB.load()
        let log = _CNHistory.load()
        let now = _CNHistory.token(_CNHistory.last(log))
        let visible = Dictionary(readable.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func contact(_ id: String) -> CNContact? { visible[id].map { r.mutableObjects ? CNMutableContact($0, keys: nil) : CNContact($0, keys: nil) } }
        func group(_ id: String) -> CNGroup { CNGroup(identifier: id, name: book.groups[id] ?? "") }
        let first = log.first?.seq ?? 1
        guard let from = _CNHistory.seq(r.startingToken), from + 1 >= first || log.isEmpty else {
            var events: [CNChangeHistoryEvent] = [CNChangeHistoryDropEverythingEvent()]
            events += readable.compactMap { contact($0.id) }.map { CNChangeHistoryAddContactEvent($0, "isim-local") }
            if r.includeGroupChanges { events += book.groups.keys.sorted().map { CNChangeHistoryAddGroupEvent(group($0)) } }
            return (events, now)
        }
        let excluded = Set(r.excludedTransactionAuthors ?? [])
        var events: [CNChangeHistoryEvent] = []
        for c in log where c.seq > from && !(c.author.map(excluded.contains) ?? false) {
            switch c.kind {
            case "addContact": if let k = contact(c.id) { events.append(CNChangeHistoryAddContactEvent(k, "isim-local")) }
            case "updateContact": if let k = contact(c.id) { events.append(CNChangeHistoryUpdateContactEvent(k)) }
            case "deleteContact": events.append(CNChangeHistoryDeleteContactEvent(c.id))
            case "addGroup" where r.includeGroupChanges: events.append(CNChangeHistoryAddGroupEvent(group(c.id)))
            case "updateGroup" where r.includeGroupChanges: events.append(CNChangeHistoryUpdateGroupEvent(group(c.id)))
            case "deleteGroup" where r.includeGroupChanges: events.append(CNChangeHistoryDeleteGroupEvent(c.id))
            case "addMember" where r.includeGroupChanges:
                if let k = contact(c.id), let g = c.group { events.append(CNChangeHistoryAddMemberToGroupEvent(k, group(g))) }
            case "removeMember" where r.includeGroupChanges:
                if let k = contact(c.id), let g = c.group { events.append(CNChangeHistoryRemoveMemberFromGroupEvent(k, group(g))) }
            default: break
            }
        }
        return (events, now)
    }
    /// for Contacts.framework's enumeratorForChangeHistoryFetchRequest:error: (the events, the token)
    @objc(_isim_changeHistoryEvents:error:) func _isim_changeHistoryEvents(_ r: CNChangeHistoryFetchRequest) throws -> [Any] {
        let (e, t) = try _historyEvents(r)
        return [e, t]
    }
}

/// the person's Contacts settings: the sort order and the country (adapted: Settings > Contacts' Sort Order is
/// "Last, First" on isim; the country is the device's region)
@objc(CNContactsUserDefaults) open class CNContactsUserDefaults: NSObject, @unchecked Sendable {
    @objc(sharedDefaults) open class func shared() -> Self { Self() }
    public required override init() { super.init() }
    @objc open var sortOrder: CNContactSortOrder { .familyName }
    @objc open var countryCode: String { (Locale.current.region?.identifier ?? "US").lowercased() }
}
