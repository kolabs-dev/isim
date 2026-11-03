// isim WebKit (issue #791): what a loaded web extension runs (iOS 18.4). Adapted: WebKitGTK has no browser-extension
// runtime, so isim provides one over its web views:
// - background content: a hidden WKWebView on the extension's base URL runs the manifest's background page, scripts or
//   service worker script (as a page); it loads with the context and on loadBackgroundContent(completionHandler:);
// - extension pages (background, action popups, pages the app shows with the context's webViewConfiguration) load
//   `webkit-extension://<uniqueIdentifier>/…` from the extension's files;
// - `browser.*` (and `chrome.*`) is a script that talks to the context through a script message handler with reply:
//   content scripts get runtime (id, getManifest, getURL, sendMessage, onMessage), storage and i18n; extension pages also
//   get runtime native messaging and the options page, tabs, windows, scripting, action, commands, menus and
//   permissions. Tabs and windows are the app's WKWebExtensionTab / WKWebExtensionWindow objects; tabs.create,
//   windows.create, permission prompts, action popups and native messaging go to the controller's delegate;
// - storage.local / .sync are kept as JSON in the app's Library/WebKit/WebExtensions (in memory for a non-persistent
//   controller), storage.session in memory; they are the extension's data records.
// Not on isim: declarativeNetRequest, webRequest, webNavigation, alarms, cookies, runtime.connect between extension
// parts, service worker APIs (importScripts, fetch events), web_accessible_resources in the app's own web views.
import UIKit

// MARK: - Permission and DataType bridge to NSString, like Apple's typed string enums

@available(iOS 18.4, *)
extension WKWebExtension.Permission: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSString { rawValue._bridgeToObjectiveC() }
    public static func _forceBridgeFromObjectiveC(_ x: NSString, result: inout WKWebExtension.Permission?) {
        result = WKWebExtension.Permission(String._unconditionallyBridgeFromObjectiveC(x))
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSString, result: inout WKWebExtension.Permission?) -> Bool {
        _forceBridgeFromObjectiveC(x, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSString?) -> WKWebExtension.Permission {
        WKWebExtension.Permission(String._unconditionallyBridgeFromObjectiveC(s))
    }
}
@available(iOS 18.4, *)
extension WKWebExtension.DataType: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSString { rawValue._bridgeToObjectiveC() }
    public static func _forceBridgeFromObjectiveC(_ x: NSString, result: inout WKWebExtension.DataType?) {
        result = WKWebExtension.DataType(String._unconditionallyBridgeFromObjectiveC(x))
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSString, result: inout WKWebExtension.DataType?) -> Bool {
        _forceBridgeFromObjectiveC(x, result: &result); return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSString?) -> WKWebExtension.DataType {
        WKWebExtension.DataType(String._unconditionallyBridgeFromObjectiveC(s))
    }
}

// MARK: - notifications

@available(iOS 18.4, *)
extension WKWebExtensionContext {
    nonisolated public static let errorsDidUpdateNotification = Notification.Name("WKWebExtensionContextErrorsDidUpdate")
    nonisolated public static let permissionsWereGrantedNotification = Notification.Name("WKWebExtensionContextPermissionsWereGranted")
    nonisolated public static let permissionsWereDeniedNotification = Notification.Name("WKWebExtensionContextPermissionsWereDenied")
    nonisolated public static let grantedPermissionsWereRemovedNotification = Notification.Name("WKWebExtensionContextGrantedPermissionsWereRemoved")
    nonisolated public static let deniedPermissionsWereRemovedNotification = Notification.Name("WKWebExtensionContextDeniedPermissionsWereRemoved")
    nonisolated public static let permissionMatchPatternsWereGrantedNotification = Notification.Name("WKWebExtensionContextPermissionMatchPatternsWereGranted")
    nonisolated public static let permissionMatchPatternsWereDeniedNotification = Notification.Name("WKWebExtensionContextPermissionMatchPatternsWereDenied")
    nonisolated public static let grantedPermissionMatchPatternsWereRemovedNotification = Notification.Name("WKWebExtensionContextGrantedPermissionMatchPatternsWereRemoved")
    nonisolated public static let deniedPermissionMatchPatternsWereRemovedNotification = Notification.Name("WKWebExtensionContextDeniedPermissionMatchPatternsWereRemoved")

    /// posts the permission notifications for a change of one of the four permission dictionaries
    func _postChanges<K: Hashable>(_ old: [K: Date], _ new: [K: Date], added: Notification.Name, removed: Notification.Name, key: NotificationUserInfoKey) {
        let a = Set(new.keys).subtracting(old.keys), r = Set(old.keys).subtracting(new.keys)
        for (name, set) in [(added, a), (removed, r)] where !set.isEmpty {
            NotificationCenter.default.post(name: name, object: self, userInfo: [AnyHashable(key.rawValue): set, AnyHashable(key): set])
        }
    }
}

// MARK: - tabs, windows, actions and commands on the context

@available(iOS 18.4, *)
extension WKWebExtensionContext {
    @objc open var openWindows: [any WKWebExtensionWindow] {
        if let c = _controller, let d = c.delegate, _wkHas(d, "webExtensionController:openWindowsForExtensionContext:") {
            return d.webExtensionController?(c, openWindowsFor: self) ?? []
        }
        return _rt.windows.compactMap { $0 as? any WKWebExtensionWindow }
    }
    @objc open var focusedWindow: (any WKWebExtensionWindow)? {
        if let c = _controller, let d = c.delegate, _wkHas(d, "webExtensionController:focusedWindowForExtensionContext:") {
            return d.webExtensionController?(c, focusedWindowFor: self)
        }
        return _rt.focused as? any WKWebExtensionWindow
    }
    @objc open var openTabs: Set<AnyHashable> { Set(_rt.allTabs.compactMap { ($0 as? NSObject).map(AnyHashable.init) }) }

    @objc(didOpenWindow:) open func didOpenWindow(_ newWindow: any WKWebExtensionWindow) {
        if !_rt.windows.contains(where: { $0 === newWindow }) { _rt.windows.append(newWindow) }
        _rt.fire("windows.onCreated", [_rt.windowInfo(newWindow, populate: false)])
    }
    @objc(didCloseWindow:) open func didCloseWindow(_ closedWindow: any WKWebExtensionWindow) {
        let id = _rt.id(closedWindow)
        _rt.windows.removeAll { $0 === closedWindow }
        if _rt.focused === closedWindow { _rt.focused = nil }
        _rt.fire("windows.onRemoved", [id])
        _rt.forget(closedWindow)
    }
    @objc(didFocusWindow:) open func didFocusWindow(_ focusedWindow: (any WKWebExtensionWindow)?) {
        _rt.focused = focusedWindow
        _rt.fire("windows.onFocusChanged", [focusedWindow.map { _rt.id($0) } ?? -1])
    }
    @objc(didOpenTab:) open func didOpenTab(_ newTab: any WKWebExtensionTab) {
        if !_rt.tabs.contains(where: { $0 === newTab }) { _rt.tabs.append(newTab) }
        _rt.fire("tabs.onCreated", [_rt.tabInfo(newTab)])
    }
    @objc(didCloseTab:windowIsClosing:) open func didCloseTab(_ closedTab: any WKWebExtensionTab, windowIsClosing: Bool = false) {
        let id = _rt.id(closedTab), w = _rt.window(of: closedTab).map { _rt.id($0) } ?? -1
        _rt.tabs.removeAll { $0 === closedTab }
        _rt.clearGesture(closedTab)
        _rt.actions[ObjectIdentifier(closedTab)] = nil
        _rt.fire("tabs.onRemoved", [id, ["windowId": w, "isWindowClosing": windowIsClosing]])
        _rt.forget(closedTab)
    }
    @objc(didActivateTab:previousActiveTab:) open func didActivateTab(_ activatedTab: any WKWebExtensionTab, previousActiveTab previousTab: (any WKWebExtensionTab)? = nil) {
        var info: [String: Any] = ["tabId": _rt.id(activatedTab), "windowId": _rt.window(of: activatedTab).map { _rt.id($0) } ?? -1]
        if let previousTab { info["previousTabId"] = _rt.id(previousTab) }
        _rt.fire("tabs.onActivated", [info])
    }
    @objc(didSelectTabs:) open func didSelectTabs(_ selectedTabs: [any WKWebExtensionTab]) { _rt.highlighted(selectedTabs) }
    @objc(didDeselectTabs:) open func didDeselectTabs(_ deselectedTabs: [any WKWebExtensionTab]) { _rt.highlighted(deselectedTabs) }
    @objc(didMoveTab:fromIndex:inWindow:) open func didMoveTab(_ movedTab: any WKWebExtensionTab, from index: Int, in oldWindow: (any WKWebExtensionWindow)? = nil) {
        let w = _rt.window(of: movedTab)
        _rt.fire("tabs.onMoved", [_rt.id(movedTab), ["windowId": (w ?? oldWindow).map { _rt.id($0) } ?? -1, "fromIndex": index,
                                                      "toIndex": movedTab.indexInWindow?(for: self) ?? index]])
    }
    @objc(didReplaceTab:withTab:) open func didReplaceTab(_ oldTab: any WKWebExtensionTab, with newTab: any WKWebExtensionTab) {
        let oldID = _rt.id(oldTab)
        if let i = _rt.tabs.firstIndex(where: { $0 === oldTab }) { _rt.tabs[i] = newTab } else { _rt.tabs.append(newTab) }
        _rt.fire("tabs.onReplaced", [_rt.id(newTab), oldID])
        _rt.forget(oldTab)
    }
    public func didChangeTabProperties(_ properties: WKWebExtension.TabChangedProperties, for changedTab: any WKWebExtensionTab) {
        if properties.contains(.URL) { _rt.clearGesture(changedTab) }
        let tab = _rt.tabInfo(changedTab)
        var change: [String: Any] = [:]
        if properties.contains(.loading) { change["status"] = tab["status"] }
        if properties.contains(.URL), let u = tab["url"] { change["url"] = u }
        if properties.contains(.title), let t = tab["title"] { change["title"] = t }
        if properties.contains(.pinned) { change["pinned"] = tab["pinned"] }
        if properties.contains(.muted) { change["mutedInfo"] = tab["mutedInfo"] }
        if properties.contains(.playingAudio) { change["audible"] = tab["audible"] }
        if properties.contains(.readerMode) { change["isInReaderMode"] = changedTab.isReaderModeActive?(for: self) ?? false }
        if properties.contains(.zoomFactor) { change["zoomFactor"] = changedTab.zoomFactor?(for: self) ?? 1 }
        guard !change.isEmpty || properties.contains(.size) else { return }
        _rt.fire("tabs.onUpdated", [_rt.id(changedTab), change, tab])
    }
    @objc(didChangeTabProperties:forTab:) func _objc_didChange(_ properties: UInt, for tab: any WKWebExtensionTab) {
        didChangeTabProperties(WKWebExtension.TabChangedProperties(rawValue: properties), for: tab)
    }

    // permissions in a tab: the tab can bypass them, and a user gesture grants activeTab
    @objc(hasPermission:inTab:) func _objc_has(_ p: String, inTab tab: (any WKWebExtensionTab)?) -> Bool { hasPermission(WKWebExtension.Permission(p), in: tab) }
    public func hasPermission(_ permission: WKWebExtension.Permission, in tab: (any WKWebExtensionTab)?) -> Bool {
        if let tab, tab.shouldBypassPermissions?(for: self) == true { return true }
        if let tab, permission == .tabs, _rt.grants[ObjectIdentifier(tab)] != nil { return true }
        return hasPermission(permission)
    }
    @objc(hasAccessToURL:inTab:) open func hasAccess(to url: URL, in tab: (any WKWebExtensionTab)?) -> Bool {
        if let tab, tab.shouldBypassPermissions?(for: self) == true { return true }
        if let tab, let p = _rt.grants[ObjectIdentifier(tab)], p.matches(url) { return true }
        return hasAccess(to: url)
    }
    public func permissionStatus(for permission: WKWebExtension.Permission, in tab: (any WKWebExtensionTab)?) -> PermissionStatus {
        if let tab, tab.shouldBypassPermissions?(for: self) == true { return .grantedImplicitly }
        if let tab, permission == .tabs, _rt.grants[ObjectIdentifier(tab)] != nil { return .grantedImplicitly }
        return permissionStatus(for: permission)
    }
    public func permissionStatus(for url: URL, in tab: (any WKWebExtensionTab)?) -> PermissionStatus {
        if let tab, tab.shouldBypassPermissions?(for: self) == true { return .grantedImplicitly }
        if let tab, let p = _rt.grants[ObjectIdentifier(tab)], p.matches(url) { return .grantedImplicitly }
        return permissionStatus(for: url)
    }
    public func permissionStatus(for pattern: WKWebExtension.MatchPattern, in tab: (any WKWebExtensionTab)?) -> PermissionStatus {
        if let tab, tab.shouldBypassPermissions?(for: self) == true { return .grantedImplicitly }
        if let tab, let p = _rt.grants[ObjectIdentifier(tab)], p.matches(pattern) { return .grantedImplicitly }
        return permissionStatus(for: pattern)
    }
    @objc(permissionStatusForPermission:inTab:) func _objc_status(_ p: String, inTab tab: (any WKWebExtensionTab)?) -> PermissionStatus {
        permissionStatus(for: WKWebExtension.Permission(p), in: tab)
    }
    @objc(permissionStatusForURL:inTab:) func _objc_status(url: URL, inTab tab: (any WKWebExtensionTab)?) -> PermissionStatus { permissionStatus(for: url, in: tab) }
    @objc(permissionStatusForMatchPattern:inTab:) func _objc_status(pattern: WKWebExtension.MatchPattern, inTab tab: (any WKWebExtensionTab)?) -> PermissionStatus {
        permissionStatus(for: pattern, in: tab)
    }

    @objc(userGesturePerformedInTab:) open func userGesturePerformed(in tab: any WKWebExtensionTab) {
        let k = ObjectIdentifier(tab)
        _rt.gestures.insert(k)
        let wants = webExtension.requestedPermissions.contains(.activeTab) || webExtension.optionalPermissions.contains(.activeTab)
        guard wants, tab.shouldGrantPermissionsOnUserGesture?(for: self) ?? true,
              let url = tab.url?(for: self) ?? tab.webView?(for: self)?.url, let scheme = url.scheme, let host = url.host,
              let p = try? WKWebExtension.MatchPattern(string: "\(scheme)://\(host)/*") else { return }
        _rt.grants[k] = p
    }
    @objc(hasActiveUserGestureInTab:) open func hasActiveUserGesture(in tab: any WKWebExtensionTab) -> Bool { _rt.gestures.contains(ObjectIdentifier(tab)) }
    @objc(clearUserGestureInTab:) open func clearUserGesture(in tab: any WKWebExtensionTab) { _rt.clearGesture(tab) }

    @objc(actionForTab:) open func action(for tab: (any WKWebExtensionTab)?) -> WKWebExtension.Action? {
        guard webExtension._actionManifest != nil else { return nil }
        let base = _rt.defaultAction ?? WKWebExtension.Action(context: self, tab: nil, parent: nil)
        _rt.defaultAction = base
        guard let tab else { return base }
        if let a = _rt.actions[ObjectIdentifier(tab)] { return a }
        let a = WKWebExtension.Action(context: self, tab: tab, parent: base)
        _rt.actions[ObjectIdentifier(tab)] = a
        return a
    }
    @objc(performActionForTab:) open func performAction(for tab: (any WKWebExtensionTab)?) {
        if let tab { userGesturePerformed(in: tab) }
        guard let a = action(for: tab), a.isEnabled else { return }
        if a.presentsPopup {
            guard let c = _controller else { return }
            Task { @MainActor in
                _ = try? await _wkExtDo(c.delegate, "webExtensionController:presentPopupForAction:forExtensionContext:completionHandler:",
                                        "webExtensionController:presentPopupForAction:forExtensionContext:asyncCompletionHandler:",
                                        sync: { d in c.delegate?.webExtensionController?(c, presentActionPopup: a, for: self, completionHandler: d) },
                                        async: { x, d in x._presentPopup(c, a, for: self, completionHandler: d) })
            }
        } else {
            _rt.fire("action.onClicked", [tab.map { _rt.tabInfo($0) } ?? NSNull()], loadBackground: true)
        }
    }

    @objc open var commands: [WKWebExtension.Command] {
        if let c = _rt.commands { return c }
        let entries = (webExtension.manifest["commands"] as? [String: Any]) ?? [:]
        let list = entries.keys.sorted().compactMap { k in (entries[k] as? [String: Any]).map { WKWebExtension.Command(context: self, id: k, entry: $0) } }
        _rt.commands = list
        return list
    }
    @objc(performCommand:) open func performCommand(_ command: WKWebExtension.Command) {
        let tab = focusedWindow?.activeTab?(for: self)
        if command.id.hasPrefix("_execute_") { performAction(for: tab); return }
        if let tab { userGesturePerformed(in: tab) }
        _rt.fire("commands.onCommand", [command.id, tab.map { _rt.tabInfo($0) } ?? NSNull()], loadBackground: true)
    }
    @objc(performCommandForKeyCommand:) open func performCommand(for keyCommand: UIKeyCommand) -> Bool {
        let id = keyCommand.propertyList as? String
        guard let c = commands.first(where: { $0.id == id })
                ?? commands.first(where: { $0.activationKey == keyCommand.input && $0.modifierFlags == keyCommand.modifierFlags && $0.activationKey != nil }) else { return false }
        performCommand(c)
        return true
    }
    @objc(menuItemsForTab:) open func menuItems(for tab: any WKWebExtensionTab) -> [UIMenuElement] { _rt.menuElements(action: false, tab: tab) }

    @objc(loadBackgroundContentWithCompletionHandler:) open func loadBackgroundContent(completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        _rt.loadBackground(completionHandler)
    }
    public func loadBackgroundContent() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Swift.Error>) in
            _rt.loadBackground { e in if let e { c.resume(throwing: e) } else { c.resume() } }
        }
    }

    // the controller's hooks
    var _handlerID: String { uniqueIdentifier.filter { $0.isLetter || $0.isNumber } }
    var _contentHandler: String { "isimExtC" + _handlerID }
    var _pageHandler: String { "isimExtP" + _handlerID }
    func _didLoad() {
        _WKExtRegistry.contexts.removeAll { $0.context == nil || $0.context === self }
        _WKExtRegistry.contexts.append(_WKWeakContext(self))
        if webExtension.hasBackgroundContent { _rt.loadBackground { [weak self] e in if e == nil { self?._rt.fire("runtime.onInstalled", [["reason": "install"]]) } } }
    }
    func _didUnload() {
        _WKExtRegistry.contexts.removeAll { $0.context == nil || $0.context === self }
        _rt.teardown()
    }
}

@available(iOS 18.4, *)
extension WKWebExtension {
    var _actionManifest: [String: Any]? { (manifest[manifestVersion >= 3 ? "action" : "browser_action"] ?? manifest["page_action"]) as? [String: Any] }
}

// MARK: - controller: delegate events, did* forwarding, data records

@available(iOS 18.4, *)
extension WKWebExtensionController {
    @objc(didOpenWindow:) open func didOpenWindow(_ newWindow: any WKWebExtensionWindow) { for c in _contexts { c.didOpenWindow(newWindow) } }
    @objc(didCloseWindow:) open func didCloseWindow(_ closedWindow: any WKWebExtensionWindow) { for c in _contexts { c.didCloseWindow(closedWindow) } }
    @objc(didFocusWindow:) open func didFocusWindow(_ focusedWindow: (any WKWebExtensionWindow)?) { for c in _contexts { c.didFocusWindow(focusedWindow) } }
    @objc(didOpenTab:) open func didOpenTab(_ newTab: any WKWebExtensionTab) { for c in _contexts { c.didOpenTab(newTab) } }
    @objc(didCloseTab:windowIsClosing:) open func didCloseTab(_ closedTab: any WKWebExtensionTab, windowIsClosing: Bool = false) {
        for c in _contexts { c.didCloseTab(closedTab, windowIsClosing: windowIsClosing) }
    }
    @objc(didActivateTab:previousActiveTab:) open func didActivateTab(_ activatedTab: any WKWebExtensionTab, previousActiveTab previousTab: (any WKWebExtensionTab)? = nil) {
        for c in _contexts { c.didActivateTab(activatedTab, previousActiveTab: previousTab) }
    }
    @objc(didSelectTabs:) open func didSelectTabs(_ selectedTabs: [any WKWebExtensionTab]) { for c in _contexts { c.didSelectTabs(selectedTabs) } }
    @objc(didDeselectTabs:) open func didDeselectTabs(_ deselectedTabs: [any WKWebExtensionTab]) { for c in _contexts { c.didDeselectTabs(deselectedTabs) } }
    @objc(didMoveTab:fromIndex:inWindow:) open func didMoveTab(_ movedTab: any WKWebExtensionTab, from index: Int, in oldWindow: (any WKWebExtensionWindow)? = nil) {
        for c in _contexts { c.didMoveTab(movedTab, from: index, in: oldWindow) }
    }
    @objc(didReplaceTab:withTab:) open func didReplaceTab(_ oldTab: any WKWebExtensionTab, with newTab: any WKWebExtensionTab) {
        for c in _contexts { c.didReplaceTab(oldTab, with: newTab) }
    }
    public func didChangeTabProperties(_ properties: WKWebExtension.TabChangedProperties, for changedTab: any WKWebExtensionTab) {
        for c in _contexts { c.didChangeTabProperties(properties, for: changedTab) }
    }
    @objc(didChangeTabProperties:forTab:) func _objc_didChange(_ properties: UInt, for tab: any WKWebExtensionTab) {
        didChangeTabProperties(WKWebExtension.TabChangedProperties(rawValue: properties), for: tab)
    }

    @objc open class var allExtensionDataTypes: Set<WKWebExtension.DataType> { [.local, .session, .synchronized] }
    @objc(fetchDataRecordsOfTypes:completionHandler:)
    public func fetchDataRecords(ofTypes dataTypes: Set<WKWebExtension.DataType>, completionHandler: @escaping ([WKWebExtension.DataRecord]) -> Void) {
        completionHandler(_contexts.compactMap { $0._rt.record(dataTypes) })
    }
    public func dataRecords(ofTypes dataTypes: Set<WKWebExtension.DataType>) async -> [WKWebExtension.DataRecord] {
        _contexts.compactMap { $0._rt.record(dataTypes) }
    }
    @objc(fetchDataRecordOfTypes:forExtensionContext:completionHandler:)
    public func fetchDataRecord(ofTypes dataTypes: Set<WKWebExtension.DataType>, for extensionContext: WKWebExtensionContext,
                              completionHandler: @escaping (WKWebExtension.DataRecord?) -> Void) {
        completionHandler(extensionContext._rt.record(dataTypes, always: true))
    }
    public func dataRecord(ofTypes dataTypes: Set<WKWebExtension.DataType>, for extensionContext: WKWebExtensionContext) async -> WKWebExtension.DataRecord? {
        extensionContext._rt.record(dataTypes, always: true)
    }
    @objc(removeDataOfTypes:fromDataRecords:completionHandler:)
    public func removeData(ofTypes dataTypes: Set<WKWebExtension.DataType>, from dataRecords: [WKWebExtension.DataRecord], completionHandler: @escaping () -> Void) {
        _removeData(dataTypes, dataRecords)
        completionHandler()
    }
    public func removeData(ofTypes dataTypes: Set<WKWebExtension.DataType>, from dataRecords: [WKWebExtension.DataRecord]) async {
        _removeData(dataTypes, dataRecords)
    }
    private func _removeData(_ types: Set<WKWebExtension.DataType>, _ records: [WKWebExtension.DataRecord]) {
        for r in records {
            guard let ctx = r._context ?? _contexts.first(where: { $0.uniqueIdentifier == r.uniqueIdentifier }) else { continue }
            for t in types { ctx._rt.clearStorage(t) }
        }
    }
}

// MARK: - the context's runtime state

@available(iOS 18.4, *)
final class _WKWeakContext { weak var context: WKWebExtensionContext?; init(_ c: WKWebExtensionContext) { context = c } }

@available(iOS 18.4, *)
@MainActor enum _WKExtRegistry {
    static var contexts: [_WKWeakContext] = []
    static func context(handler name: String) -> WKWebExtensionContext? {
        contexts.compactMap(\.context).first { $0._contentHandler == name || $0._pageHandler == name }
    }
    static func context(host: String) -> WKWebExtensionContext? {
        contexts.compactMap(\.context).first { $0.baseURL.host?.lowercased() == host.lowercased() }
    }
}

final class _WKOnce { var done = false; func first() -> Bool { if done { return false }; done = true; return true } }

/// calls an optional requirement that takes a completion handler, in whichever form (completion handler or `async`)
/// the object implements; (false, nil) when it implements neither
@available(iOS 18.4, *)
@MainActor func _wkExtCall<T>(_ o: AnyObject?, _ syncSel: String, _ asyncSel: String,
                              sync: (@escaping (T?, (any Error)?) -> Void) -> Void,
                              async: (_WKExtAsync, @escaping (T?, (any Error)?) -> Void) -> Void) async throws -> (Bool, T?) {
    guard let n = o as? NSObjectProtocol else { return (false, nil) }
    let s = _wkHas(n, syncSel), a = _wkHas(n, asyncSel)
    guard s || a else { return (false, nil) }
    let v: T? = try await withCheckedThrowingContinuation { (c: CheckedContinuation<T?, any Error>) in
        let once = _WKOnce()
        let done: (T?, (any Error)?) -> Void = { v, e in
            guard once.first() else { return }
            if let e { c.resume(throwing: e) } else { c.resume(returning: v) }
        }
        if s { sync(done) } else { async(_wkExtAsync(n), done) }
    }
    return (true, v)
}
@available(iOS 18.4, *)
@MainActor func _wkExtDo(_ o: AnyObject?, _ syncSel: String, _ asyncSel: String,
                         sync: (@escaping ((any Error)?) -> Void) -> Void,
                         async: (_WKExtAsync, @escaping ((any Error)?) -> Void) -> Void) async throws -> Bool {
    let r: (Bool, Bool?) = try await _wkExtCall(o, syncSel, asyncSel, sync: { d in sync { d(nil, $0) } }, async: { x, d in async(x) { d(nil, $0) } })
    return r.0
}

struct _WKExtError: Error {
    let message: String
    init(_ m: String) { message = m }
}

@available(iOS 18.4, *)
@MainActor final class _WKExtState {
    weak var ctx: WKWebExtensionContext?
    init(_ c: WKWebExtensionContext) { ctx = c }

    // tabs and windows the app reported; numeric ids for the extension
    var windows: [AnyObject] = [], tabs: [AnyObject] = []
    weak var focused: AnyObject?
    var ids: [ObjectIdentifier: Int] = [:], objects: [Int: AnyObject] = [:], nextID = 1
    var gestures: Set<ObjectIdentifier> = []
    var grants: [ObjectIdentifier: WKWebExtension.MatchPattern] = [:]
    var defaultAction: WKWebExtension.Action?
    var actions: [ObjectIdentifier: WKWebExtension.Action] = [:]
    var commands: [WKWebExtension.Command]?
    var menus: [[String: Any]] = []
    var ports: [String: WKWebExtension.MessagePort] = [:]
    var storage: [WKWebExtension.DataType: [String: Any]] = [:]
    // background content and the other extension pages
    var background: WKWebView?
    var backgroundDelegate: _WKExtBackgroundDelegate?
    var backgroundLoaded = false
    var backgroundWaiters: [((any Error)?) -> Void] = []
    var pages: [_WKWeakView] = []

    func id(_ o: AnyObject) -> Int {
        let k = ObjectIdentifier(o)
        if let i = ids[k] { return i }
        let i = nextID
        nextID += 1
        ids[k] = i; objects[i] = o
        return i
    }
    func forget(_ o: AnyObject) { if let i = ids.removeValue(forKey: ObjectIdentifier(o)) { objects[i] = nil } }
    func clearGesture(_ t: AnyObject) { gestures.remove(ObjectIdentifier(t)); grants[ObjectIdentifier(t)] = nil }
    var allTabs: [any WKWebExtensionTab] {
        guard let ctx else { return [] }
        var out: [any WKWebExtensionTab] = tabs.compactMap { $0 as? any WKWebExtensionTab }
        for w in ctx.openWindows { for t in w.tabs?(for: ctx) ?? [] where !out.contains(where: { $0 === t }) { out.append(t) } }
        return out
    }
    func tab(_ id: Any?) -> (any WKWebExtensionTab)? {
        guard let n = (id as? NSNumber).map({ Int($0.intValue) }) else { return nil }
        return (objects[n] as? any WKWebExtensionTab) ?? allTabs.first { self.id($0) == n }
    }
    func windowObject(_ id: Any?) -> (any WKWebExtensionWindow)? {
        guard let n = (id as? NSNumber).map({ Int($0.intValue) }), let ctx else { return nil }
        if n == -2 { return ctx.focusedWindow }
        return (objects[n] as? any WKWebExtensionWindow) ?? ctx.openWindows.first { self.id($0) == n }
    }
    func window(of t: any WKWebExtensionTab) -> (any WKWebExtensionWindow)? {
        guard let ctx else { return nil }
        if let w = t.window?(for: ctx) { return w }
        return ctx.openWindows.first { w in (w.tabs?(for: ctx) ?? []).contains { $0 === t } }
    }
    func tab(of view: WKWebView) -> (any WKWebExtensionTab)? {
        guard let ctx else { return nil }
        return allTabs.first { $0.webView?(for: ctx) === view }
    }
    func currentWindow(_ view: WKWebView?) -> (any WKWebExtensionWindow)? {
        if let view, let t = tab(of: view), let w = window(of: t) { return w }
        return ctx?.focusedWindow
    }

    func tabInfo(_ t: any WKWebExtensionTab) -> [String: Any] {
        guard let ctx else { return [:] }
        let w = window(of: t)
        let active = w.map { $0.activeTab?(for: ctx) === t } ?? false
        var o: [String: Any] = ["id": id(t), "index": t.indexInWindow?(for: ctx) ?? 0, "windowId": w.map { id($0) } ?? -1, "active": active,
                                "highlighted": t.isSelected?(for: ctx) ?? active, "selected": t.isSelected?(for: ctx) ?? active,
                                "pinned": t.isPinned?(for: ctx) ?? false, "audible": t.isPlayingAudio?(for: ctx) ?? false,
                                "mutedInfo": ["muted": t.isMuted?(for: ctx) ?? false], "incognito": w?.isPrivate?(for: ctx) ?? false,
                                "status": (t.isLoadingComplete?(for: ctx) ?? true) ? "complete" : "loading",
                                "isInReaderMode": t.isReaderModeActive?(for: ctx) ?? false, "discarded": false, "autoDiscardable": true, "groupId": -1]
        if let s = t.size?(for: ctx) { o["width"] = Int(s.width); o["height"] = Int(s.height) }
        if let p = t.parentTab?(for: ctx) { o["openerTabId"] = id(p) }
        if let url = t.url?(for: ctx) ?? t.webView?(for: ctx)?.url, ctx.hasPermission(.tabs, in: t) || ctx.hasAccess(to: url, in: t) {
            o["url"] = url.absoluteString
            o["title"] = t.title?(for: ctx) ?? t.webView?(for: ctx)?.title ?? ""
            if let p = t.pendingURL?(for: ctx) { o["pendingUrl"] = p.absoluteString }
        }
        return o
    }
    func windowInfo(_ w: any WKWebExtensionWindow, populate: Bool) -> [String: Any] {
        guard let ctx else { return [:] }
        let states = ["normal", "minimized", "maximized", "fullscreen"]
        var o: [String: Any] = ["id": id(w), "focused": ctx.focusedWindow === w, "alwaysOnTop": false,
                                "type": (w.windowType?(for: ctx) ?? .normal) == .popup ? "popup" : "normal",
                                "state": states[(w.windowState?(for: ctx) ?? .normal).rawValue], "incognito": w.isPrivate?(for: ctx) ?? false]
        if let f = w.frame?(for: ctx), !f.isNull {
            o["left"] = Int(f.minX); o["top"] = Int(f.minY); o["width"] = Int(f.width); o["height"] = Int(f.height)
        }
        if populate { o["tabs"] = (w.tabs?(for: ctx) ?? []).map { tabInfo($0) } }
        return o
    }
    func highlighted(_ changed: [any WKWebExtensionTab]) {
        guard let ctx, let t = changed.first, let w = window(of: t) else { return }
        let selected = (w.tabs?(for: ctx) ?? []).filter { $0.isSelected?(for: ctx) ?? false }.map { id($0) }
        fire("tabs.onHighlighted", [["windowId": id(w), "tabIds": selected]])
    }

    // MARK: events into the extension's pages and content scripts
    var livePages: [WKWebView] {
        pages.removeAll { $0.view == nil }
        return pages.compactMap(\.view)
    }
    func dispatch(_ view: WKWebView, world: WKContentWorld, _ event: String, _ args: [Any], _ done: ((Any?) -> Void)? = nil) {
        view.callAsyncJavaScript("return window.__isimExt ? await window.__isimExt.dispatch(e, a) : null", arguments: ["e": event, "a": args],
                                 in: nil, in: world) { r in done?(try? r.get()) }
    }
    func dispatch(_ view: WKWebView, world: WKContentWorld, _ event: String, _ args: [Any]) async -> Any? {
        await withCheckedContinuation { (c: CheckedContinuation<Any?, Never>) in dispatch(view, world: world, event, args) { c.resume(returning: $0) } }
    }
    /// an event for the extension's pages (the background page, popups, extension pages)
    func fire(_ event: String, _ args: [Any], loadBackground: Bool = false) {
        let send = { [weak self] in
            guard let self else { return }
            for v in self.livePages { self.dispatch(v, world: .page, event, args) }
        }
        if loadBackground, background == nil || !backgroundLoaded, ctx?.webExtension.hasBackgroundContent == true {
            self.loadBackground { _ in send() }
        } else { send() }
    }
    /// an event for content scripts too (storage.onChanged)
    func fireContent(_ event: String, _ args: [Any]) {
        guard let ctx, let c = ctx._controller else { return }
        for v in c._webViews.compactMap(\.view) { dispatch(v, world: ctx._world, event, args) }
    }

    // MARK: background content
    func loadBackground(_ done: @escaping ((any Error)?) -> Void) {
        guard let ctx else { done(WKWebExtensionContext.Error(.notLoaded)); return }
        guard ctx.isLoaded else {
            done(WKWebExtensionContext.Error(.notLoaded, userInfo: [NSLocalizedDescriptionKey: "Extension context is not loaded."])); return
        }
        let ext = ctx.webExtension
        guard ext.hasBackgroundContent, let bg = ext.manifest["background"] as? [String: Any] else {
            done(WKWebExtensionContext.Error(.noBackgroundContent, userInfo: [NSLocalizedDescriptionKey: "No background content is available to load."])); return
        }
        if backgroundLoaded, background != nil { done(nil); return }
        backgroundWaiters.append(done)
        guard background == nil else { return }
        let config = ctx.webViewConfiguration ?? WKWebViewConfiguration()
        let w = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 400), configuration: config)
        let d = _WKExtBackgroundDelegate(self)
        w.navigationDelegate = d
        w.isInspectable = ctx.isInspectable
        background = w; backgroundDelegate = d
        pages.append(_WKWeakView(w))
        if let page = bg["page"] as? String {
            w.load(URLRequest(url: ctx.baseURL.appendingPathComponent(page)))
            return
        }
        var scripts = (bg["scripts"] as? [Any] ?? []).compactMap { $0 as? String }
        if let sw = bg["service_worker"] as? String { scripts.append(sw) }
        let module = bg["type"] as? String == "module"
        var html = "<!doctype html><html><head><meta charset=utf-8></head><body>"
        for s in scripts {
            if module { html += "<script type=module src=\"\(s)\"></script>"; continue }
            let code = (ext._resource(s) ?? "").replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
            html += "<script>\(code)\n</script>"
        }
        html += "</body></html>"
        w.loadHTMLString(html, baseURL: ctx.baseURL)
    }
    func backgroundFinished(_ error: (any Error)?) {
        if error == nil { backgroundLoaded = true } else { teardownBackground() }
        let waiters = backgroundWaiters
        backgroundWaiters = []
        let e = error.map { WKWebExtensionContext.Error(.backgroundContentFailedToLoad, userInfo: [NSLocalizedDescriptionKey: "The background content failed to load.",
                                                                                                    NSUnderlyingErrorKey: $0]) }
        for w in waiters { w(e) }
    }
    func teardownBackground() {
        if let b = background { pages.removeAll { $0.view == nil || $0.view === b } }
        background = nil; backgroundDelegate = nil; backgroundLoaded = false
    }
    func teardown() {
        for p in ports.values { p.disconnect() }
        ports = [:]
        defaultAction?.closePopup()
        for a in actions.values { a.closePopup() }
        teardownBackground()
        backgroundFinished(WKWebExtensionContext.Error(.notLoaded))
        pages = []
    }

    // MARK: storage
    func areaType(_ name: String) -> WKWebExtension.DataType? {
        switch name { case "local": return .local; case "session": return .session; case "sync": return .synchronized; default: return nil }
    }
    var storageDirectory: URL? {
        guard let ctx, let c = ctx._controller, c.configuration.isPersistent else { return nil }
        let id = c.configuration.identifier?.uuidString ?? "Default"
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/WebKit/WebExtensions/\(id)/\(ctx.uniqueIdentifier)")
    }
    func items(_ t: WKWebExtension.DataType) -> [String: Any] {
        if let s = storage[t] { return s }
        var s: [String: Any] = [:]
        if t != .session, let dir = storageDirectory, let d = FileManager.default.contents(atPath: dir.appendingPathComponent(t.rawValue + ".json").path),
           let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] { s = o }
        storage[t] = s
        return s
    }
    func save(_ t: WKWebExtension.DataType, _ s: [String: Any]) {
        storage[t] = s
        guard t != .session, let dir = storageDirectory else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let d = try? JSONSerialization.data(withJSONObject: s, options: [.sortedKeys]) { try? d.write(to: dir.appendingPathComponent(t.rawValue + ".json")) }
    }
    func size(_ s: [String: Any], keys: [String]? = nil) -> Int {
        var n = 0
        for (k, v) in s where keys?.contains(k) ?? true { n += k.utf8.count + _wkJSONText(v).utf8.count }
        return n
    }
    func clearStorage(_ t: WKWebExtension.DataType) {
        let old = items(t)
        save(t, [:])
        changed(t, old: old, new: [:])
    }
    func changed(_ t: WKWebExtension.DataType, old: [String: Any], new: [String: Any]) {
        var changes: [String: Any] = [:]
        for k in Set(old.keys).union(new.keys) {
            let a = old[k].map { _wkJSONText($0) }, b = new[k].map { _wkJSONText($0) }
            guard a != b else { continue }
            var c: [String: Any] = [:]
            if let o = old[k] { c["oldValue"] = o }
            if let n = new[k] { c["newValue"] = n }
            changes[k] = c
        }
        guard !changes.isEmpty else { return }
        let area = t == .synchronized ? "sync" : t.rawValue
        for (e, args) in [("storage.onChanged", [changes, area] as [Any]), ("storage.\(area).onChanged", [changes] as [Any])] {
            fire(e, args); fireContent(e, args)
        }
    }
    func record(_ types: Set<WKWebExtension.DataType>, always: Bool = false) -> WKWebExtension.DataRecord? {
        guard let ctx else { return nil }
        var sizes: [WKWebExtension.DataType: Int] = [:]
        for t in types { let s = items(t); if !s.isEmpty { sizes[t] = size(s) } }
        if sizes.isEmpty && !always { return nil }
        return WKWebExtension.DataRecord(context: ctx, sizes: sizes)
    }

    // MARK: menus (browser.menus / contextMenus)
    func menuElements(action: Bool, tab: (any WKWebExtensionTab)?) -> [UIMenuElement] {
        let want: Set<String> = action ? ["all", "action", "browser_action", "page_action"] : ["all", "page", "tab"]
        func children(_ parent: String?) -> [UIMenuElement] {
            menus.filter { m in (m["parentId"].map { "\($0)" }) == parent }.compactMap { m -> UIMenuElement? in
                let contexts = Set((m["contexts"] as? [Any] ?? ["page"]).compactMap { $0 as? String })
                guard parent != nil || !contexts.isDisjoint(with: want), m["visible"] as? Bool ?? true, m["type"] as? String != "separator" else { return nil }
                let id = "\(m["id"] ?? "")", title = (m["title"] as? String ?? "").replacingOccurrences(of: "%s", with: "")
                let kids = children(id)
                if !kids.isEmpty { return UIMenu(title: title, children: kids) }
                let checked = m["checked"] as? Bool ?? false
                let a = UIAction(title: title, attributes: m["enabled"] as? Bool == false ? [.disabled] : [], state: checked ? .on : .off) { [weak self] _ in
                    self?.menuClicked(id, tab: tab)
                }
                return a
            }
        }
        return children(nil)
    }
    func menuClicked(_ id: String, tab: (any WKWebExtensionTab)?) {
        guard let ctx, let i = menus.firstIndex(where: { "\($0["id"] ?? "")" == id }) else { return }
        var info: [String: Any] = ["menuItemId": menus[i]["id"] ?? id, "editable": false]
        if let p = menus[i]["parentId"] { info["parentMenuItemId"] = p }
        if let type = menus[i]["type"] as? String, type == "checkbox" || type == "radio" {
            let was = menus[i]["checked"] as? Bool ?? false
            menus[i]["checked"] = type == "radio" ? true : !was
            info["wasChecked"] = was; info["checked"] = menus[i]["checked"]
        }
        if let tab, let u = tab.url?(for: ctx) ?? tab.webView?(for: ctx)?.url, ctx.hasAccess(to: u, in: tab) { info["pageUrl"] = u.absoluteString }
        if let tab { ctx.userGesturePerformed(in: tab) }
        fire("menus.onClicked", [info, tab.map { tabInfo($0) } ?? NSNull()], loadBackground: true)
    }
}

@available(iOS 18.4, *)
@MainActor final class _WKExtBackgroundDelegate: NSObject, WKNavigationDelegate {
    weak var state: _WKExtState?
    init(_ s: _WKExtState) { state = s }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { if state?.background === webView { state?.backgroundFinished(nil) } }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if state?.background === webView, state?.backgroundLoaded == false { state?.backgroundFinished(error) }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if state?.background === webView, state?.backgroundLoaded == false { state?.backgroundFinished(error) }
    }
}

// MARK: - webkit-extension:// resources

@available(iOS 18.4, *)
@MainActor final class _WKExtSchemeHandler: NSObject, WKURLSchemeHandler {
    static let shared = _WKExtSchemeHandler()
    static let types = ["html": "text/html", "htm": "text/html", "js": "text/javascript", "mjs": "text/javascript", "css": "text/css", "json": "application/json",
                        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "svg": "image/svg+xml", "webp": "image/webp",
                        "ico": "image/x-icon", "txt": "text/plain", "wasm": "application/wasm", "woff": "font/woff", "woff2": "font/woff2"]
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let u = urlSchemeTask.request.url, let ctx = _WKExtRegistry.context(host: u.host ?? "") else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let base = ctx.webExtension._base.standardizedFileURL
        let file = base.appendingPathComponent(String(u.path.drop { $0 == "/" })).standardizedFileURL
        guard file.path.hasPrefix(base.path + "/"), let data = FileManager.default.contents(atPath: file.path) else {
            urlSchemeTask.didReceive(HTTPURLResponse(url: u, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/plain"])!)
            urlSchemeTask.didReceive(Data("Not Found".utf8))
            urlSchemeTask.didFinish()
            return
        }
        let mime = Self.types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        urlSchemeTask.didReceive(HTTPURLResponse(url: u, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime])!)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

// MARK: - the browser.* bridge

@available(iOS 18.4, *)
@MainActor enum _WKExtBridge {
    /// a message from a `browser.*` call (WKWebView._messageEvent routes names starting with "isimExt" here)
    static func receive(_ view: WKWebView, name: String, body: Any, reply: @escaping (Any?, String?) -> Void) {
        guard let ctx = _WKExtRegistry.context(handler: name), ctx.isLoaded else { reply(nil, "The extension is not loaded."); return }
        let content = name == ctx._contentHandler
        if !content {
            // extension pages only: the page-world handler is visible to every page of the controller's web views
            let own = ctx._rt.livePages.contains { $0 === view }
            let url = view.url
            guard own || (url?.scheme == "webkit-extension" && url?.host?.lowercased() == ctx.baseURL.host?.lowercased()) else {
                reply(nil, "Not an extension page."); return
            }
            if !own { ctx._rt.pages.append(_WKWeakView(view)) }
        }
        let o = body as? [String: Any] ?? [:]
        let api = o["api"] as? String ?? "", args = o["args"] as? [Any] ?? []
        if content, !(api == "runtime.sendMessage" || api.hasPrefix("storage.")) { reply(nil, "\(api) is not available to content scripts."); return }
        Task { @MainActor in
            do { reply(try await handle(ctx, api, args, view: view, world: content ? ctx._world : .page), nil) }
            catch { reply(nil, (error as? _WKExtError)?.message ?? (error as NSError).localizedDescription) }
        }
    }

    static func need(_ ctx: WKWebExtensionContext, _ p: WKWebExtension.Permission, _ tab: (any WKWebExtensionTab)? = nil) throws {
        guard ctx.hasPermission(p, in: tab) else { throw _WKExtError("Missing the '\(p.rawValue)' permission.") }
    }
    static func url(_ ctx: WKWebExtensionContext, _ s: Any?) -> URL? {
        guard let s = s as? String, !s.isEmpty else { return nil }
        if let u = URL(string: s), u.scheme != nil { return u }
        return URL(string: s, relativeTo: ctx.baseURL)?.absoluteURL
    }
    static func sender(_ ctx: WKWebExtensionContext, _ view: WKWebView) -> [String: Any] {
        var s: [String: Any] = ["id": ctx.uniqueIdentifier, "frameId": 0]
        if let u = view.url { s["url"] = u.absoluteString; if let sc = u.scheme, let h = u.host { s["origin"] = "\(sc)://\(h)" } }
        if let t = ctx._rt.tab(of: view) { s["tab"] = ctx._rt.tabInfo(t) }
        return s
    }
    /// runtime.onMessage in the given views; the first listener that answers gives the response
    static func deliver(_ ctx: WKWebExtensionContext, _ views: [WKWebView], world: WKContentWorld, _ message: Any, sender: [String: Any]) async -> Any? {
        for v in views {
            if let r = await ctx._rt.dispatch(v, world: world, "runtime.onMessage", [message, sender]) as? [String: Any], r["handled"] as? Bool == true {
                return r["response"] is NSNull ? nil : r["response"]
            }
        }
        return nil
    }

    static func handle(_ ctx: WKWebExtensionContext, _ api: String, _ a: [Any], view: WKWebView, world: WKContentWorld) async throws -> Any? {
        let rt = ctx._rt
        let arg = { (i: Int) -> Any? in i < a.count && !(a[i] is NSNull) ? a[i] : nil }
        let dict = { (i: Int) -> [String: Any] in arg(i) as? [String: Any] ?? [:] }
        guard let c = ctx._controller else { throw _WKExtError("The extension is not loaded.") }
        switch api {
        // runtime
        case "runtime.sendMessage":
            if ctx.webExtension.hasBackgroundContent, rt.background == nil || !rt.backgroundLoaded {
                try? await ctx.loadBackgroundContent()
            }
            return await deliver(ctx, rt.livePages.filter { $0 !== view }, world: .page, arg(0) ?? NSNull(), sender: sender(ctx, view))
        case "runtime.openOptionsPage":
            let done = try await _wkExtDo(c.delegate, "webExtensionController:openOptionsPageForExtensionContext:completionHandler:",
                                          "webExtensionController:openOptionsPageForExtensionContext:asyncCompletionHandler:",
                                          sync: { d in c.delegate?.webExtensionController?(c, openOptionsPageFor: ctx, completionHandler: d) },
                                          async: { x, d in x._openOptions(c, for: ctx, completionHandler: d) })
            if !done { throw _WKExtError("The app cannot open the options page.") }
            return nil
        case "runtime.sendNativeMessage":
            try need(ctx, .nativeMessaging)
            let app = arg(0) as? String, message = arg(1) ?? NSNull()
            let (done, v): (Bool, Any?) = try await _wkExtCall(c.delegate, "webExtensionController:sendMessage:toApplicationWithIdentifier:forExtensionContext:replyHandler:",
                                                               "webExtensionController:sendMessage:toApplicationWithIdentifier:forExtensionContext:asyncReplyHandler:",
                                                               sync: { d in c.delegate?.webExtensionController?(c, sendMessage: message, toApplicationWithIdentifier: app, for: ctx, replyHandler: d) },
                                                               async: { x, d in x._send(c, message, app: app, for: ctx, completionHandler: d) })
            if !done { throw _WKExtError("Native messaging is not supported by the app.") }
            return v
        case "runtime.connectNative":
            try need(ctx, .nativeMessaging)
            guard let id = arg(1) as? String else { throw _WKExtError("Invalid port.") }
            let port = WKWebExtension.MessagePort(id: id, application: arg(0) as? String, context: ctx, view: view, world: world)
            rt.ports[id] = port
            do {
                let done = try await _wkExtDo(c.delegate, "webExtensionController:connectUsingMessagePort:forExtensionContext:completionHandler:",
                                              "webExtensionController:connectUsingMessagePort:forExtensionContext:asyncCompletionHandler:",
                                              sync: { d in c.delegate?.webExtensionController?(c, connectUsing: port, for: ctx, completionHandler: d) },
                                              async: { x, d in x._connect(c, port, for: ctx, completionHandler: d) })
                if !done { throw _WKExtError("Native messaging is not supported by the app.") }
            } catch { rt.ports[id] = nil; throw error }
            return nil
        case "port.post":
            guard let p = rt.ports[arg(0) as? String ?? ""], !p.isDisconnected else { throw _WKExtError("The port is disconnected.") }
            p.messageHandler?(arg(1), nil)
            return nil
        case "port.disconnect":
            rt.ports[arg(0) as? String ?? ""]?._remoteDisconnected()
            return nil

        // storage
        case _ where api.hasPrefix("storage."):
            try need(ctx, .storage)
            guard let t = rt.areaType(arg(0) as? String ?? "") else { throw _WKExtError("Unknown storage area.") }
            let old = rt.items(t)
            func keys(_ v: Any?) -> [String]? {
                if let s = v as? String { return [s] }
                if let l = v as? [Any] { return l.compactMap { $0 as? String } }
                if let d = v as? [String: Any] { return Array(d.keys) }
                return nil
            }
            switch api {
            case "storage.get":
                let k = keys(arg(1))
                var out: [String: Any] = (arg(1) as? [String: Any]) ?? [:]
                for (key, v) in old where k?.contains(key) ?? true { out[key] = v }
                return out
            case "storage.set":
                var new = old
                for (k, v) in dict(1) { new[k] = v }
                rt.save(t, new); rt.changed(t, old: old, new: new)
            case "storage.remove":
                var new = old
                for k in keys(arg(1)) ?? [] { new[k] = nil }
                rt.save(t, new); rt.changed(t, old: old, new: new)
            case "storage.clear": rt.clearStorage(t)
            case "storage.getBytesInUse": return rt.size(old, keys: keys(arg(1)))
            default: throw _WKExtError("\(api) is not supported.")
            }
            return nil

        // tabs
        case "tabs.query":
            let q = dict(0), current = rt.currentWindow(view)
            var out: [[String: Any]] = []
            for t in rt.allTabs {
                let info = rt.tabInfo(t), w = rt.window(of: t)
                if let v = q["active"] as? Bool, info["active"] as? Bool != v { continue }
                if let v = q["pinned"] as? Bool, info["pinned"] as? Bool != v { continue }
                if let v = q["audible"] as? Bool, info["audible"] as? Bool != v { continue }
                if let v = q["highlighted"] as? Bool, info["highlighted"] as? Bool != v { continue }
                if let v = q["muted"] as? Bool, (info["mutedInfo"] as? [String: Any])?["muted"] as? Bool != v { continue }
                if let v = q["status"] as? String, info["status"] as? String != v { continue }
                if let v = q["index"] as? Int, info["index"] as? Int != v { continue }
                if q["currentWindow"] as? Bool == true, w == nil || w !== current { continue }
                if q["lastFocusedWindow"] as? Bool == true, w == nil || w !== ctx.focusedWindow { continue }
                if let v = q["windowId"] as? Int, (v == -2 ? (w == nil || w !== current) : info["windowId"] as? Int != v) { continue }
                if let v = q["windowType"] as? String, let w, ((w.windowType?(for: ctx) ?? .normal) == .popup ? "popup" : "normal") != v { continue }
                if let u = q["url"] {
                    let pats = ((u as? [Any]) ?? [u]).compactMap { ($0 as? String).flatMap { try? WKWebExtension.MatchPattern(string: $0) } }
                    guard let s = info["url"] as? String, let tu = URL(string: s), pats.contains(where: { $0.matches(tu) }) else { continue }
                }
                if let v = q["title"] as? String {
                    guard let s = info["title"] as? String, s.range(of: WKWebExtension.MatchPattern._glob(v), options: .regularExpression) != nil else { continue }
                }
                out.append(info)
            }
            return out.sorted { ($0["windowId"] as? Int ?? 0, $0["index"] as? Int ?? 0) < ($1["windowId"] as? Int ?? 0, $1["index"] as? Int ?? 0) }
        case "tabs.get":
            guard let t = rt.tab(arg(0)) else { throw _WKExtError("No tab with id: \(arg(0) ?? "-").") }
            return rt.tabInfo(t)
        case "tabs.getCurrent":
            return rt.tab(of: view).map { rt.tabInfo($0) }
        case "tabs.create", "windows.create":
            return try await create(ctx, c, api, dict(0), view: view)
        case "tabs.update":
            let p = dict(1)
            guard let t = arg(0) == nil ? (rt.tab(of: view) ?? rt.currentWindow(view)?.activeTab?(for: ctx)) : rt.tab(arg(0)) else { throw _WKExtError("No tab.") }
            if let u = url(ctx, p["url"]) {
                _ = try await _wkExtDo(t, "loadURL:forWebExtensionContext:completionHandler:", "loadURL:forWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in t.loadURL?(u, for: ctx, completionHandler: d) }, async: { x, d in x._load(u, for: ctx, completionHandler: d) })
            }
            if p["active"] as? Bool == true {
                _ = try await _wkExtDo(t, "activateForWebExtensionContext:completionHandler:", "activateForWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in t.activate?(for: ctx, completionHandler: d) }, async: { x, d in x._activate(for: ctx, completionHandler: d) })
            }
            if let v = (p["highlighted"] ?? p["selected"]) as? Bool {
                _ = try await _wkExtDo(t, "setSelected:forWebExtensionContext:completionHandler:", "setSelected:forWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in t.setSelected?(v, for: ctx, completionHandler: d) }, async: { x, d in x._setSelected(v, for: ctx, completionHandler: d) })
            }
            if let v = p["pinned"] as? Bool {
                _ = try await _wkExtDo(t, "setPinned:forWebExtensionContext:completionHandler:", "setPinned:forWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in t.setPinned?(v, for: ctx, completionHandler: d) }, async: { x, d in x._setPinned(v, for: ctx, completionHandler: d) })
            }
            if let v = p["muted"] as? Bool {
                _ = try await _wkExtDo(t, "setMuted:forWebExtensionContext:completionHandler:", "setMuted:forWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in t.setMuted?(v, for: ctx, completionHandler: d) }, async: { x, d in x._setMuted(v, for: ctx, completionHandler: d) })
            }
            if let o = p["openerTabId"] {
                let parent = rt.tab(o)
                _ = try await _wkExtDo(t, "setParentTab:forWebExtensionContext:completionHandler:", "setParentTab:forWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in t.setParentTab?(parent, for: ctx, completionHandler: d) }, async: { x, d in x._setParentTab(parent, for: ctx, completionHandler: d) })
            }
            return rt.tabInfo(t)
        case "tabs.remove":
            for id in (arg(0) as? [Any]) ?? [] {
                guard let t = rt.tab(id) else { throw _WKExtError("No tab with id: \(id).") }
                _ = try await _wkExtDo(t, "closeForWebExtensionContext:completionHandler:", "closeForWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in t.close?(for: ctx, completionHandler: d) }, async: { x, d in x._close(for: ctx, completionHandler: d) })
            }
            return nil
        case "tabs.reload", "tabs.goBack", "tabs.goForward":
            guard let t = arg(0) == nil ? (rt.tab(of: view) ?? rt.currentWindow(view)?.activeTab?(for: ctx)) : rt.tab(arg(0)) else { throw _WKExtError("No tab.") }
            let ok: Bool
            if api == "tabs.reload" {
                let bypass = dict(1)["bypassCache"] as? Bool ?? false
                ok = try await _wkExtDo(t, "reloadFromOrigin:forWebExtensionContext:completionHandler:", "reloadFromOrigin:forWebExtensionContext:asyncCompletionHandler:",
                                        sync: { d in t.reload?(fromOrigin: bypass, for: ctx, completionHandler: d) }, async: { x, d in x._reload(bypass, for: ctx, completionHandler: d) })
                if !ok { t.webView?(for: ctx)?.reload() }
            } else if api == "tabs.goBack" {
                ok = try await _wkExtDo(t, "goBackForWebExtensionContext:completionHandler:", "goBackForWebExtensionContext:asyncCompletionHandler:",
                                        sync: { d in t.goBack?(for: ctx, completionHandler: d) }, async: { x, d in x._back(for: ctx, completionHandler: d) })
                if !ok { t.webView?(for: ctx)?.goBack() }
            } else {
                ok = try await _wkExtDo(t, "goForwardForWebExtensionContext:completionHandler:", "goForwardForWebExtensionContext:asyncCompletionHandler:",
                                        sync: { d in t.goForward?(for: ctx, completionHandler: d) }, async: { x, d in x._forward(for: ctx, completionHandler: d) })
                if !ok { t.webView?(for: ctx)?.goForward() }
            }
            return nil
        case "tabs.duplicate":
            guard let t = rt.tab(arg(0)) else { throw _WKExtError("No tab with id: \(arg(0) ?? "-").") }
            let w = rt.window(of: t)
            let config = WKWebExtension.TabConfiguration(window: w, index: (t.indexInWindow?(for: ctx) ?? 0) + 1, parentTab: t, url: t.url?(for: ctx),
                                                         active: true, selected: true, pinned: false, muted: false, readerMode: false)
            let (done, n): (Bool, AnyObject?) = try await _wkExtCall(t, "duplicateUsingConfiguration:forWebExtensionContext:completionHandler:",
                                                                     "duplicateUsingConfiguration:forWebExtensionContext:asyncCompletionHandler:",
                                                                     sync: { d in t.duplicate?(using: config, for: ctx, completionHandler: { d($0, $1) }) },
                                                                     async: { x, d in x._duplicate(config, for: ctx, completionHandler: d) })
            if !done { throw _WKExtError("The app cannot duplicate this tab.") }
            return (n as? any WKWebExtensionTab).map { rt.tabInfo($0) }
        case "tabs.sendMessage":
            guard let t = rt.tab(arg(0)), let w = t.webView?(for: ctx) else { throw _WKExtError("Could not establish connection. Receiving end does not exist.") }
            return await deliver(ctx, [w], world: ctx._world, arg(1) ?? NSNull(), sender: sender(ctx, view))

        // windows
        case "windows.getAll":
            let p = dict(0), types = (p["windowTypes"] as? [Any])?.compactMap { $0 as? String }
            return ctx.openWindows.map { rt.windowInfo($0, populate: p["populate"] as? Bool ?? false) }.filter { types?.contains($0["type"] as? String ?? "") ?? true }
        case "windows.get", "windows.getCurrent", "windows.getLastFocused":
            let w: (any WKWebExtensionWindow)?
            switch api {
            case "windows.get": w = rt.windowObject(arg(0))
            case "windows.getCurrent": w = rt.currentWindow(view)
            default: w = ctx.focusedWindow
            }
            guard let w else { throw _WKExtError("No window.") }
            return rt.windowInfo(w, populate: dict(api == "windows.get" ? 1 : 0)["populate"] as? Bool ?? false)
        case "windows.update":
            guard let w = rt.windowObject(arg(0)) else { throw _WKExtError("No window with id: \(arg(0) ?? "-").") }
            let p = dict(1)
            if let s = p["state"] as? String, let i = ["normal", "minimized", "maximized", "fullscreen"].firstIndex(of: s), let st = WKWebExtension.WindowState(rawValue: i) {
                _ = try await _wkExtDo(w, "setWindowState:forWebExtensionContext:completionHandler:", "setWindowState:forWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in w.setWindowState?(st, for: ctx, completionHandler: d) }, async: { x, d in x._setState(st, for: ctx, completionHandler: d) })
            }
            if p["left"] != nil || p["top"] != nil || p["width"] != nil || p["height"] != nil {
                var f = w.frame?(for: ctx) ?? .zero
                if let v = p["left"] as? Double { f.origin.x = v }
                if let v = p["top"] as? Double { f.origin.y = v }
                if let v = p["width"] as? Double { f.size.width = v }
                if let v = p["height"] as? Double { f.size.height = v }
                _ = try await _wkExtDo(w, "setFrame:forWebExtensionContext:completionHandler:", "setFrame:forWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in w.setFrame?(f, for: ctx, completionHandler: d) }, async: { x, d in x._setFrame(f, for: ctx, completionHandler: d) })
            }
            if p["focused"] as? Bool == true {
                _ = try await _wkExtDo(w, "focusForWebExtensionContext:completionHandler:", "focusForWebExtensionContext:asyncCompletionHandler:",
                                       sync: { d in w.focus?(for: ctx, completionHandler: d) }, async: { x, d in x._focus(for: ctx, completionHandler: d) })
            }
            return rt.windowInfo(w, populate: false)
        case "windows.remove":
            guard let w = rt.windowObject(arg(0)) else { throw _WKExtError("No window with id: \(arg(0) ?? "-").") }
            _ = try await _wkExtDo(w, "closeForWebExtensionContext:completionHandler:", "closeForWebExtensionContext:asyncCompletionHandler:",
                                   sync: { d in w.close?(for: ctx, completionHandler: d) }, async: { x, d in x._close(for: ctx, completionHandler: d) })
            return nil

        // scripting
        case "scripting.executeScript", "scripting.insertCSS", "scripting.removeCSS":
            try need(ctx, .scripting)
            let inj = dict(0), target = inj["target"] as? [String: Any] ?? [:]
            guard let t = rt.tab(target["tabId"]), let w = t.webView?(for: ctx) else { throw _WKExtError("No tab with id: \(target["tabId"] ?? "-").") }
            guard let u = t.url?(for: ctx) ?? w.url, ctx.hasAccess(to: u, in: t) else {
                throw _WKExtError("Cannot access contents of the page. Extension manifest must request permission to access the respective host.")
            }
            let scriptWorld: WKContentWorld = (inj["world"] as? String)?.uppercased() == "MAIN" ? .page : ctx._world
            if api == "scripting.executeScript" {
                var result: Any? = nil
                if let f = inj["func"] as? String {
                    result = try await w.callAsyncJavaScript("return await (\(f))(...args)", arguments: ["args": inj["args"] as? [Any] ?? []], contentWorld: scriptWorld)
                }
                for file in (inj["files"] as? [Any] ?? []).compactMap({ $0 as? String }) {
                    guard let code = ctx.webExtension._resource(file) else { throw _WKExtError("Could not load file: '\(file)'.") }
                    result = try await w.evaluateJavaScript(code, contentWorld: scriptWorld)
                }
                return [["frameId": 0, "documentId": "", "result": result ?? NSNull()]]
            }
            var css = inj["css"] as? String ?? ""
            for file in (inj["files"] as? [Any] ?? []).compactMap({ $0 as? String }) { css += ctx.webExtension._resource(file) ?? "" }
            let js = api == "scripting.insertCSS"
                ? "(function(c){var s=document.createElement('style');s.setAttribute('data-isim-extension','');s.textContent=c;(document.head||document.documentElement).appendChild(s)})(css)"
                : "document.querySelectorAll('style[data-isim-extension]').forEach(function(s){if(s.textContent===css)s.remove()})"
            _ = try await w.callAsyncJavaScript(js, arguments: ["css": css], contentWorld: ctx._world)
            return nil

        // action
        case "action.set", "action.get":
            let prop = arg(0) as? String ?? "", d = dict(1), tab = d["tabId"].flatMap { rt.tab($0) }
            guard let act = ctx.action(for: tab) else { throw _WKExtError("The extension has no action.") }
            if api == "action.get" {
                switch prop {
                case "badgeText": return act.badgeText
                case "title": return act.label
                case "popup": return act._popupPath.isEmpty ? "" : ctx.baseURL.appendingPathComponent(act._popupPath).absoluteString
                case "enabled": return act.isEnabled
                default: return nil
                }
            }
            let reset = d.keys.contains(prop == "badgeText" ? "text" : prop) && (d[prop == "badgeText" ? "text" : prop] is NSNull)
            switch prop {
            case "badgeText":
                act._badge = reset ? (tab == nil ? "" : nil) : d["text"] as? String ?? ""
                act.hasUnreadBadgeText = !act.badgeText.isEmpty
            case "title": act._label = reset ? (tab == nil ? (ctx.webExtension.displayActionLabel ?? "") : nil) : d["title"] as? String
            case "popup": act._popup = reset ? (tab == nil ? "" : nil) : (d["popup"] as? String).map { $0.hasPrefix(ctx.baseURL.absoluteString) ? String($0.dropFirst(ctx.baseURL.absoluteString.count)) : $0 }
            case "icon":
                if let p = d["path"] as? String { act._icon = p }
                else if let p = d["path"] as? [String: Any] { act._icon = p.sorted { (Int($0.key) ?? 0) > (Int($1.key) ?? 0) }.first?.value as? String }
            case "enabled": act._enabled = d["enabled"] as? Bool ?? true
            default: break
            }
            act._changed()
            return nil
        case "action.openPopup":
            let tab = rt.currentWindow(view)?.activeTab?(for: ctx)
            guard let act = ctx.action(for: tab), act.presentsPopup else { throw _WKExtError("The action has no popup.") }
            let done = try await _wkExtDo(c.delegate, "webExtensionController:presentPopupForAction:forExtensionContext:completionHandler:",
                                          "webExtensionController:presentPopupForAction:forExtensionContext:asyncCompletionHandler:",
                                          sync: { d in c.delegate?.webExtensionController?(c, presentActionPopup: act, for: ctx, completionHandler: d) },
                                          async: { x, d in x._presentPopup(c, act, for: ctx, completionHandler: d) })
            if !done { throw _WKExtError("The app cannot show the popup.") }
            return nil

        // commands, menus
        case "commands.getAll":
            return ctx.commands.map { cmd -> [String: Any] in
                var keys: [String] = []
                if cmd.modifierFlags.contains(.command) { keys.append("Command") }
                if cmd.modifierFlags.contains(.control) { keys.append("MacCtrl") }
                if cmd.modifierFlags.contains(.alternate) { keys.append("Alt") }
                if cmd.modifierFlags.contains(.shift) { keys.append("Shift") }
                if let k = cmd.activationKey { keys.append(k.uppercased()) }
                return ["name": cmd.id, "description": cmd.title, "shortcut": cmd.activationKey == nil ? "" : keys.joined(separator: "+")]
            }
        case "menus.create":
            let p = dict(0), id = "\(p["id"] ?? UUID().uuidString)"
            if rt.menus.contains(where: { "\($0["id"] ?? "")" == id }) { throw _WKExtError("Cannot create item with duplicate id \(id).") }
            rt.menus.append(p)
            return id
        case "menus.update":
            let id = "\(arg(0) ?? "")"
            guard let i = rt.menus.firstIndex(where: { "\($0["id"] ?? "")" == id }) else { throw _WKExtError("Cannot find menu item with id \(id).") }
            for (k, v) in dict(1) { rt.menus[i][k] = v }
            return nil
        case "menus.remove":
            var gone: Set<String> = ["\(arg(0) ?? "")"], changed = true
            while changed {
                changed = false
                for m in rt.menus where !gone.contains("\(m["id"] ?? "")") && m["parentId"].map({ gone.contains("\($0)") }) == true { gone.insert("\(m["id"] ?? "")"); changed = true }
            }
            rt.menus.removeAll { gone.contains("\($0["id"] ?? "")") }
            return nil
        case "menus.removeAll":
            rt.menus = []
            return nil

        // permissions
        case "permissions.getAll":
            return ["permissions": ctx.currentPermissions.map(\.rawValue).sorted(), "origins": ctx.currentPermissionMatchPatterns.map(\.string).sorted()]
        case "permissions.contains":
            let p = dict(0)
            let perms = (p["permissions"] as? [Any] ?? []).compactMap { $0 as? String }.map { WKWebExtension.Permission($0) }
            let origins = (p["origins"] as? [Any] ?? []).compactMap { ($0 as? String).flatMap { try? WKWebExtension.MatchPattern(string: $0) } }
            return perms.allSatisfy { ctx.hasPermission($0) }
                && origins.allSatisfy { [.grantedExplicitly, .grantedImplicitly].contains(ctx.permissionStatus(for: $0)) }
        case "permissions.request":
            let p = dict(0), tab = rt.tab(of: view) ?? rt.currentWindow(view)?.activeTab?(for: ctx)
            let declared = ctx.webExtension.requestedPermissions.union(ctx.webExtension.optionalPermissions)
            let perms = Set((p["permissions"] as? [Any] ?? []).compactMap { $0 as? String }.map { WKWebExtension.Permission($0) })
            let origins = Set((p["origins"] as? [Any] ?? []).compactMap { ($0 as? String).flatMap { try? WKWebExtension.MatchPattern(string: $0) } })
            if let bad = perms.subtracting(declared).first { throw _WKExtError("Only permissions specified in the manifest may be requested: \(bad.rawValue).") }
            let wantPerms = perms.filter { !ctx.hasPermission($0) }
            let wantOrigins = origins.filter { ![.grantedExplicitly, .grantedImplicitly].contains(ctx.permissionStatus(for: $0)) }
            var addedPerms: [String] = [], addedOrigins: [String] = []
            if !wantPerms.isEmpty {
                let (done, r): (Bool, (Set<WKWebExtension.Permission>, Date?)?) = try await _wkExtCall(c.delegate,
                    "webExtensionController:promptForPermissions:inTab:forExtensionContext:completionHandler:",
                    "webExtensionController:promptForPermissions:inTab:forExtensionContext:asyncCompletionHandler:",
                    sync: { d in c.delegate?.webExtensionController?(c, promptForPermissions: wantPerms, in: tab, for: ctx) { d(($0, $1), nil) } },
                    async: { x, d in x._prompt(c, permissions: wantPerms, in: tab, for: ctx) { d(($0, $1), nil) } })
                guard done, let (allowed, expires) = r else { return false }
                for q in allowed.intersection(wantPerms) { ctx.setPermissionStatus(.grantedExplicitly, for: q, expirationDate: expires); addedPerms.append(q.rawValue) }
            }
            if !wantOrigins.isEmpty {
                let (done, r): (Bool, (Set<WKWebExtension.MatchPattern>, Date?)?) = try await _wkExtCall(c.delegate,
                    "webExtensionController:promptForPermissionMatchPatterns:inTab:forExtensionContext:completionHandler:",
                    "webExtensionController:promptForPermissionMatchPatterns:inTab:forExtensionContext:asyncCompletionHandler:",
                    sync: { d in c.delegate?.webExtensionController?(c, promptForPermissionMatchPatterns: wantOrigins, in: tab, for: ctx) { d(($0, $1), nil) } },
                    async: { x, d in x._prompt(c, patterns: wantOrigins, in: tab, for: ctx) { d(($0, $1), nil) } })
                guard done, let (allowed, expires) = r else { return false }
                for q in allowed { ctx.setPermissionStatus(.grantedExplicitly, for: q, expirationDate: expires); addedOrigins.append(q.string) }
            }
            if !addedPerms.isEmpty || !addedOrigins.isEmpty { rt.fire("permissions.onAdded", [["permissions": addedPerms, "origins": addedOrigins]]) }
            return perms.allSatisfy { ctx.hasPermission($0) } && origins.allSatisfy { [.grantedExplicitly, .grantedImplicitly].contains(ctx.permissionStatus(for: $0)) }
        case "permissions.remove":
            let p = dict(0)
            let perms = (p["permissions"] as? [Any] ?? []).compactMap { $0 as? String }
            let origins = (p["origins"] as? [Any] ?? []).compactMap { $0 as? String }
            for q in perms { ctx.setPermissionStatus(.requestedExplicitly, for: WKWebExtension.Permission(q)) }
            for o in origins { if let m = try? WKWebExtension.MatchPattern(string: o) { ctx.setPermissionStatus(.requestedExplicitly, for: m) } }
            rt.fire("permissions.onRemoved", [["permissions": perms, "origins": origins]])
            return true
        default:
            throw _WKExtError("\(api) is not supported on isim.")
        }
    }

    /// tabs.create and windows.create: the delegate opens them
    static func create(_ ctx: WKWebExtensionContext, _ c: WKWebExtensionController, _ api: String, _ p: [String: Any], view: WKWebView) async throws -> Any? {
        let rt = ctx._rt
        if api == "tabs.create" {
            let w = p["windowId"].flatMap { rt.windowObject($0) } ?? rt.currentWindow(view)
            let active = p["active"] as? Bool ?? true
            let config = WKWebExtension.TabConfiguration(window: w, index: p["index"] as? Int ?? (w?.tabs?(for: ctx).count ?? 0),
                                                         parentTab: p["openerTabId"].flatMap { rt.tab($0) }, url: url(ctx, p["url"]), active: active,
                                                         selected: active, pinned: p["pinned"] as? Bool ?? false, muted: p["muted"] as? Bool ?? false,
                                                         readerMode: p["openInReaderMode"] as? Bool ?? false)
            let (done, t): (Bool, AnyObject?) = try await _wkExtCall(c.delegate, "webExtensionController:openNewTabUsingConfiguration:forExtensionContext:completionHandler:",
                                                                     "webExtensionController:openNewTabUsingConfiguration:forExtensionContext:asyncCompletionHandler:",
                                                                     sync: { d in c.delegate?.webExtensionController?(c, openNewTabUsing: config, for: ctx, completionHandler: { d($0, $1) }) },
                                                                     async: { x, d in x._openTab(c, config, for: ctx, completionHandler: d) })
            if !done { throw _WKExtError("The app cannot open tabs.") }
            return (t as? any WKWebExtensionTab).map { rt.tabInfo($0) }
        }
        let urls = ((p["url"] as? [Any]) ?? (p["url"].map { [$0] } ?? [])).compactMap { url(ctx, $0) }
        let states = ["normal", "minimized", "maximized", "fullscreen"]
        let state = WKWebExtension.WindowState(rawValue: states.firstIndex(of: p["state"] as? String ?? "normal") ?? 0) ?? .normal
        var frame = CGRect.null
        if let wd = p["width"] as? Double, let h = p["height"] as? Double { frame = CGRect(x: p["left"] as? Double ?? 0, y: p["top"] as? Double ?? 0, width: wd, height: h) }
        let tabs = ((p["tabId"].map { [$0] }) ?? []).compactMap { rt.tab($0) }
        let config = WKWebExtension.WindowConfiguration(type: p["type"] as? String == "popup" ? .popup : .normal, state: state, frame: frame, tabURLs: urls,
                                                        tabs: tabs, focused: p["focused"] as? Bool ?? true, private: p["incognito"] as? Bool ?? false)
        let (done, w): (Bool, AnyObject?) = try await _wkExtCall(c.delegate, "webExtensionController:openNewWindowUsingConfiguration:forExtensionContext:completionHandler:",
                                                                 "webExtensionController:openNewWindowUsingConfiguration:forExtensionContext:asyncCompletionHandler:",
                                                                 sync: { d in c.delegate?.webExtensionController?(c, openNewWindowUsing: config, for: ctx, completionHandler: { d($0, $1) }) },
                                                                 async: { x, d in x._openWindow(c, config, for: ctx, completionHandler: d) })
        if !done { throw _WKExtError("The app cannot open windows.") }
        return (w as? any WKWebExtensionWindow).map { rt.windowInfo($0, populate: true) }
    }

    /// the `browser` object: in a content script's world (content), or in extension pages (page world, only on the
    /// extension's own origin)
    static func script(_ ctx: WKWebExtensionContext, content: Bool) -> String {
        let ext = ctx.webExtension
        let host = (ctx.baseURL.host ?? ctx.uniqueIdentifier).lowercased()
        let guardJS = content ? "" : "if (location.protocol !== 'webkit-extension:' || location.host.toLowerCase() !== \(_wkJSLiteral(host))) return;"
        let messages = (try? JSONSerialization.data(withJSONObject: ext._messageEntries)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return _wkExtShim
            .replacingOccurrences(of: "@GUARD@", with: guardJS)
            .replacingOccurrences(of: "@NAME@", with: content ? ctx._contentHandler : ctx._pageHandler)
            .replacingOccurrences(of: "@ID@", with: _wkJSLiteral(ctx.uniqueIdentifier))
            .replacingOccurrences(of: "@BASE@", with: _wkJSLiteral(ctx.baseURL.absoluteString))
            .replacingOccurrences(of: "@CONTENT@", with: content ? "true" : "false")
            .replacingOccurrences(of: "@MESSAGES@", with: messages)
            .replacingOccurrences(of: "@MANIFEST@", with: ext._localizedManifestJSON)
    }
}

/// `browser.*` in JavaScript; calls go to the context through window.webkit.messageHandlers (with reply), events come
/// back through __isimExt.dispatch
let _wkExtShim = #"""
(function(){
'use strict';
if (window.__isimExt) return;
@GUARD@
const H = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers['@NAME@'];
if (!H) return;
const ID = @ID@, BASE = @BASE@, CONTENT = @CONTENT@, MSG = @MESSAGES@, MANIFEST = @MANIFEST@;
const clean = v => { const s = JSON.stringify(v); return s === undefined ? null : JSON.parse(s); };
const call = (api, ...args) => H.postMessage({api: api, args: args.map(clean)}).then(r => { const v = typeof r === 'string' ? JSON.parse(r) : r; return v === null ? undefined : v; },
    e => { throw new Error(e && e.message ? e.message : String(e)); });
const P = (p, cb) => {
  if (typeof cb !== 'function') return p;
  p.then(v => cb(v), e => { B.runtime.lastError = {message: e.message}; try { cb(); } finally { B.runtime.lastError = undefined; } });
};
const fn = (...a) => a.find(x => typeof x === 'function');
const events = {};
const ev = n => events[n] || (events[n] = (() => {
  const ls = [];
  return { addListener(f) { if (typeof f === 'function' && !ls.includes(f)) ls.push(f); },
           removeListener(f) { const i = ls.indexOf(f); if (i >= 0) ls.splice(i, 1); },
           hasListener(f) { return ls.includes(f); }, hasListeners() { return ls.length > 0; }, _ls: ls };
})());
const ports = {}, clicks = {};
const uid = () => Math.random().toString(36).slice(2) + Date.now().toString(36);
const onMessage = (m, s) => new Promise(resolve => {
  let pending = 0, done = false;
  const finish = v => { if (!done) { done = true; resolve({handled: true, response: v === undefined ? null : clean(v)}); } };
  const fail = () => { if (--pending <= 0 && !done) { done = true; resolve({handled: false}); } };
  for (const l of ev('runtime.onMessage')._ls.slice()) {
    let r;
    try { r = l(m, s, finish); } catch (e) { console.error(e); continue; }
    if (r === true) pending++;
    else if (r && typeof r.then === 'function') { pending++; r.then(v => v === undefined ? fail() : finish(v), fail); }
  }
  if (pending === 0 && !done) { done = true; resolve({handled: false}); }
});
window.__isimExt = { dispatch: async function(name, args) {
  if (name === 'runtime.onMessage') return await onMessage(args[0], args[1]);
  if (name === 'port.message' || name === 'port.disconnect') {
    const p = ports[args[0]];
    if (!p) return null;
    if (name === 'port.message') { for (const l of p.onMessage._ls.slice()) { try { l(args[1], p); } catch (e) { console.error(e); } } return null; }
    delete ports[args[0]];
    if (args[1]) B.runtime.lastError = {message: args[1]};
    for (const l of p.onDisconnect._ls.slice()) { try { l(p); } catch (e) { console.error(e); } }
    B.runtime.lastError = undefined;
    return null;
  }
  if (name === 'menus.onClicked' && args[0] && clicks[args[0].menuItemId]) { try { clicks[args[0].menuItemId](args[0], args[1]); } catch (e) { console.error(e); } }
  for (const l of ev(name)._ls.slice()) { try { await l(...args); } catch (e) { console.error(e); } }
  return null;
}};
const storage = area => ({
  get: (k, cb) => P(call('storage.get', area, typeof k === 'function' || k === undefined ? null : k), fn(k, cb)),
  set: (o, cb) => P(call('storage.set', area, o || {}), cb),
  remove: (k, cb) => P(call('storage.remove', area, k), cb),
  clear: cb => P(call('storage.clear', area), cb),
  getBytesInUse: (k, cb) => P(call('storage.getBytesInUse', area, typeof k === 'function' || k === undefined ? null : k), fn(k, cb)),
  onChanged: ev('storage.' + area + '.onChanged') });
const B = {
  runtime: {
    id: ID, lastError: undefined,
    getManifest: () => JSON.parse(JSON.stringify(MANIFEST)),
    getURL: p => BASE + String(p).replace(/^\//, ''),
    sendMessage: (...a) => { const cb = typeof a[a.length - 1] === 'function' ? a.pop() : undefined;
                             return P(call('runtime.sendMessage', a.length >= 2 && typeof a[0] === 'string' ? a[1] : a[0]), cb); },
    getPlatformInfo: cb => P(Promise.resolve({os: 'ios', arch: 'arm', nacl_arch: 'arm'}), cb),
    onMessage: ev('runtime.onMessage'), onInstalled: ev('runtime.onInstalled'), onStartup: ev('runtime.onStartup') },
  storage: { local: storage('local'), session: storage('session'), sync: storage('sync'), onChanged: ev('storage.onChanged') },
  i18n: {
    getMessage: (n, s) => {
      n = String(n).toLowerCase();
      if (n === '@@extension_id') return ID;
      if (n === '@@ui_locale') return navigator.language.replace('-', '_');
      const e = MSG[n];
      if (!e) return '';
      const subs = s === undefined ? [] : Array.isArray(s) ? s.map(String) : [String(s)], ph = e.placeholders || {};
      return String(e.message || '')
        .replace(/\$([A-Za-z0-9_@]+)\$/g, (m, k) => { const p = ph[k.toLowerCase()]; return p ? String(p.content || '').replace(/\$(\d)/g, (x, d) => subs[d - 1] || '') : m; })
        .replace(/\$(\d)/g, (m, d) => subs[d - 1] || '').replace(/\$\$/g, '$');
    },
    getUILanguage: () => navigator.language,
    getAcceptLanguages: cb => P(Promise.resolve(navigator.languages ? [...navigator.languages] : [navigator.language]), cb) } };
if (!CONTENT) {
  Object.assign(B.runtime, {
    sendNativeMessage: (app, m, cb) => P(call('runtime.sendNativeMessage', app, m), cb),
    connectNative: app => {
      const id = uid();
      const p = { name: app, onMessage: ev('port.message:' + id), onDisconnect: ev('port.disconnect:' + id),
                  postMessage(m) { if (!ports[id]) throw new Error('Attempting to use a disconnected port object'); call('port.post', id, m).catch(() => {}); },
                  disconnect() { if (ports[id]) { delete ports[id]; call('port.disconnect', id).catch(() => {}); } } };
      ports[id] = p;
      call('runtime.connectNative', app, id).catch(e => { if (!ports[id]) return; delete ports[id]; B.runtime.lastError = {message: e.message};
        for (const l of p.onDisconnect._ls.slice()) { try { l(p); } catch (x) { console.error(x); } } B.runtime.lastError = undefined; });
      return p;
    },
    openOptionsPage: cb => P(call('runtime.openOptionsPage'), cb) });
  const tabArg = (a, b, c) => typeof a === 'number' ? [a, b, c] : [null, a, b];
  B.tabs = {
    TAB_ID_NONE: -1,
    query: (q, cb) => P(call('tabs.query', q || {}), cb),
    get: (id, cb) => P(call('tabs.get', id), cb),
    getCurrent: cb => P(call('tabs.getCurrent'), cb),
    create: (p, cb) => P(call('tabs.create', p || {}), cb),
    duplicate: (id, cb) => P(call('tabs.duplicate', id), cb),
    update: (a, b, c) => { const [id, p, cb] = tabArg(a, b, c); return P(call('tabs.update', id, p || {}), cb); },
    remove: (ids, cb) => P(call('tabs.remove', Array.isArray(ids) ? ids : [ids]), cb),
    reload: (a, b, c) => { const [id, p, cb] = tabArg(a, b, c); return P(call('tabs.reload', id, p && typeof p === 'object' ? p : {}), fn(p, cb)); },
    goBack: (a, cb) => P(call('tabs.goBack', typeof a === 'number' ? a : null), fn(a, cb)),
    goForward: (a, cb) => P(call('tabs.goForward', typeof a === 'number' ? a : null), fn(a, cb)),
    sendMessage: (id, m, o, cb) => P(call('tabs.sendMessage', id, m), fn(o, cb)),
    onCreated: ev('tabs.onCreated'), onRemoved: ev('tabs.onRemoved'), onActivated: ev('tabs.onActivated'), onUpdated: ev('tabs.onUpdated'),
    onMoved: ev('tabs.onMoved'), onReplaced: ev('tabs.onReplaced'), onHighlighted: ev('tabs.onHighlighted') };
  B.windows = {
    WINDOW_ID_NONE: -1, WINDOW_ID_CURRENT: -2,
    getAll: (o, cb) => P(call('windows.getAll', typeof o === 'object' && o ? o : {}), fn(o, cb)),
    get: (id, o, cb) => P(call('windows.get', id, typeof o === 'object' && o ? o : {}), fn(o, cb)),
    getCurrent: (o, cb) => P(call('windows.getCurrent', typeof o === 'object' && o ? o : {}), fn(o, cb)),
    getLastFocused: (o, cb) => P(call('windows.getLastFocused', typeof o === 'object' && o ? o : {}), fn(o, cb)),
    create: (p, cb) => P(call('windows.create', typeof p === 'object' && p ? p : {}), fn(p, cb)),
    update: (id, p, cb) => P(call('windows.update', id, p || {}), cb),
    remove: (id, cb) => P(call('windows.remove', id), cb),
    onCreated: ev('windows.onCreated'), onRemoved: ev('windows.onRemoved'), onFocusChanged: ev('windows.onFocusChanged') };
  B.scripting = {
    executeScript: (i, cb) => P(call('scripting.executeScript', Object.assign({}, i, {func: typeof i.func === 'function' ? i.func.toString() : undefined})), cb),
    insertCSS: (i, cb) => P(call('scripting.insertCSS', i), cb),
    removeCSS: (i, cb) => P(call('scripting.removeCSS', i), cb) };
  const getter = k => (d, cb) => P(call('action.get', k, typeof d === 'object' && d ? d : {tabId: typeof d === 'number' ? d : undefined}), fn(d, cb));
  const action = {
    setBadgeText: (d, cb) => P(call('action.set', 'badgeText', d || {}), cb), getBadgeText: getter('badgeText'),
    setTitle: (d, cb) => P(call('action.set', 'title', d || {}), cb), getTitle: getter('title'),
    setPopup: (d, cb) => P(call('action.set', 'popup', d || {}), cb), getPopup: getter('popup'),
    setIcon: (d, cb) => P(call('action.set', 'icon', d || {}), cb),
    enable: (id, cb) => P(call('action.set', 'enabled', {tabId: typeof id === 'number' ? id : undefined, enabled: true}), fn(id, cb)),
    disable: (id, cb) => P(call('action.set', 'enabled', {tabId: typeof id === 'number' ? id : undefined, enabled: false}), fn(id, cb)),
    isEnabled: getter('enabled'),
    openPopup: (o, cb) => P(call('action.openPopup'), fn(o, cb)),
    setBadgeBackgroundColor: (d, cb) => P(Promise.resolve(), cb), setBadgeTextColor: (d, cb) => P(Promise.resolve(), cb),
    onClicked: ev('action.onClicked') };
  B.action = action;
  if (MANIFEST.manifest_version < 3) { B.browserAction = action; B.pageAction = action; }
  B.commands = { getAll: cb => P(call('commands.getAll'), cb), onCommand: ev('commands.onCommand') };
  const menus = {
    create: (p, cb) => { const id = p && p.id !== undefined ? p.id : uid(); if (p && typeof p.onclick === 'function') clicks[id] = p.onclick;
                         call('menus.create', Object.assign({}, p, {id: id, onclick: undefined})).then(() => { if (typeof cb === 'function') cb(); },
                           e => { B.runtime.lastError = {message: e.message}; if (typeof cb === 'function') cb(); B.runtime.lastError = undefined; });
                         return id; },
    update: (id, p, cb) => P(call('menus.update', id, p || {}), cb),
    remove: (id, cb) => { delete clicks[id]; return P(call('menus.remove', id), cb); },
    removeAll: cb => P(call('menus.removeAll'), cb),
    onClicked: ev('menus.onClicked') };
  B.menus = menus; B.contextMenus = menus;
  B.permissions = {
    contains: (p, cb) => P(call('permissions.contains', p || {}), cb), getAll: cb => P(call('permissions.getAll'), cb),
    request: (p, cb) => P(call('permissions.request', p || {}), cb), remove: (p, cb) => P(call('permissions.remove', p || {}), cb),
    onAdded: ev('permissions.onAdded'), onRemoved: ev('permissions.onRemoved') };
}
window.browser = B;
window.chrome = B;
})();
"""#
