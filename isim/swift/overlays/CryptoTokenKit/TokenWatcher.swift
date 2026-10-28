// isim CryptoTokenKit: TKTokenWatcher (adapted). isim has no token driver extensions yet: a virtual card whose readers.json
// entry names a "token" (a token driver's class ID) is that driver's token while it is inserted, with the ID
// "<driver>:<card serial>"; inserting and removing it calls the insertion and removal handlers.
import Foundation

@objc(TKTokenWatcher) open class TKTokenWatcher: NSObject, @unchecked Sendable {
    @objc(TKTokenWatcherTokenInfo) open class TokenInfo: NSObject, @unchecked Sendable {
        @objc public let tokenID: String
        @objc public let slotName: String?
        @objc public let driverName: String?
        init(tokenID: String, slotName: String?, driverName: String?) { self.tokenID = tokenID; self.slotName = slotName; self.driverName = driverName }
    }
    private var tokens: [String: TokenInfo] = [:]
    private var insertion: (@Sendable (String) -> Void)?
    private var removal: [String: @Sendable (String) -> Void] = [:]
    private var watch: UUID?

    public override init() {
        super.init()
        tokens = TKTokenWatcher.current()
        watch = _TKReaders.shared.observe { [weak self] in self?.changed() }
    }
    @objc(initWithInsertionHandler:) public convenience init(insertionHandler: @escaping @Sendable (String) -> Void) {
        self.init()
        setInsertionHandler(insertionHandler)
    }
    deinit { if let watch { _TKReaders.shared.stopObserving(watch) } }

    static func current() -> [String: TokenInfo] {
        var out: [String: TokenInfo] = [:]
        for r in _TKReaders.shared.readers {
            guard let card = _TKReaders.shared.card(r.name), let driver = card.token else { continue }
            let id = "\(driver):\(card.serial)"
            out[id] = TokenInfo(tokenID: id, slotName: r.name, driverName: driver)
        }
        return out
    }
    private func changed() {
        let now = TKTokenWatcher.current()
        let gone = tokens.keys.filter { now[$0] == nil }, added = now.keys.filter { tokens[$0] == nil }.sorted()
        willChangeValue(forKey: "tokenIDs"); tokens = now; didChangeValue(forKey: "tokenIDs")
        for id in gone { if let h = removal.removeValue(forKey: id) { h(id) } }
        if let h = insertion { for id in added { h(id) } }
    }
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool { key == "tokenIDs" ? false : super.automaticallyNotifiesObservers(forKey: key) }

    @objc open dynamic var tokenIDs: [String] { tokens.keys.sorted() }
    /// the handler gets each token inserted from now on, and first the ones already present
    @objc open func setInsertionHandler(_ insertionHandler: @escaping @Sendable (String) -> Void) {
        insertion = insertionHandler
        for id in tokenIDs { insertionHandler(id) }
    }
    /// the handler is called once, when the token is removed (at once if it is already gone)
    @objc(addRemovalHandler:forTokenID:) open func addRemovalHandler(_ removalHandler: @escaping @Sendable (String) -> Void, forTokenID tokenID: String) {
        guard tokens[tokenID] != nil else { removalHandler(tokenID); return }
        removal[tokenID] = removalHandler
    }
    @objc(tokenInfoForTokenID:) open func tokenInfo(forTokenID tokenID: String) -> TokenInfo? { tokens[tokenID] }
}
