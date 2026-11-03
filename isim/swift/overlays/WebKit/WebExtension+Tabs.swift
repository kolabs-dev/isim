// isim WebKit (issue #791): the app's side of web extension tabs and windows (iOS 18.4). The app's browser tabs and windows
// adopt WKWebExtensionTab / WKWebExtensionWindow and tell the context (or controller) when they open, close, move or
// change; extensions see them through `browser.tabs` and `browser.windows` (WebExtension+Runtime.swift). Here:
// - the tab and window protocols, TabChangedProperties, WindowType and WindowState, the tab and window configurations;
// - WKWebExtensionControllerDelegate (opening tabs, windows and the options page, permission prompts, action popups,
//   native messaging);
// - WKWebExtension.Action (the toolbar button: label, icon, badge, popup web view), WKWebExtension.Command (manifest
//   `commands` as UIKeyCommands and menu items), WKWebExtension.MessagePort (native messaging), WKWebExtension.DataRecord
//   and DataType (the extensions' storage).
// Apple's completion-handler requirements are also matched when the app implements their `async` forms.
import UIKit

@available(iOS 18.4, *)
extension WKWebExtension {
    /// what changed in a tab (didChangeTabProperties(_:for:))
    public struct TabChangedProperties: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let loading = TabChangedProperties(rawValue: 1 << 1)
        public static let muted = TabChangedProperties(rawValue: 1 << 2)
        public static let pinned = TabChangedProperties(rawValue: 1 << 3)
        public static let playingAudio = TabChangedProperties(rawValue: 1 << 4)
        public static let readerMode = TabChangedProperties(rawValue: 1 << 5)
        public static let size = TabChangedProperties(rawValue: 1 << 6)
        public static let title = TabChangedProperties(rawValue: 1 << 7)
        public static let URL = TabChangedProperties(rawValue: 1 << 8)
        public static let zoomFactor = TabChangedProperties(rawValue: 1 << 9)
    }
    @objc(WKWebExtensionWindowType) public enum WindowType: Int, Sendable { case normal, popup }
    @objc(WKWebExtensionWindowState) public enum WindowState: Int, Sendable { case normal, minimized, maximized, fullscreen }

    /// a kind of data an extension stores (`browser.storage.local`, `.session`, `.sync`)
    public struct DataType: Hashable, Equatable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let local = DataType("local")
        public static let session = DataType("session")
        public static let synchronized = DataType("synchronized")
    }

    /// how an extension asks for a new tab (browser.tabs.create)
    @MainActor @objc(WKWebExtensionTabConfiguration) open class TabConfiguration: NSObject, @unchecked Sendable {
        @objc open private(set) var window: (any WKWebExtensionWindow)?
        @objc open private(set) var index: Int
        @objc open private(set) var parentTab: (any WKWebExtensionTab)?
        @objc open private(set) var url: URL?
        @objc open private(set) var shouldBeActive: Bool
        @objc open private(set) var shouldAddToSelection: Bool
        @objc open private(set) var shouldBePinned: Bool
        @objc open private(set) var shouldBeMuted: Bool
        @objc open private(set) var shouldReaderModeBeActive: Bool
        init(window: (any WKWebExtensionWindow)?, index: Int, parentTab: (any WKWebExtensionTab)?, url: URL?, active: Bool, selected: Bool,
             pinned: Bool, muted: Bool, readerMode: Bool) {
            self.window = window; self.index = index; self.parentTab = parentTab; self.url = url; shouldBeActive = active
            shouldAddToSelection = selected; shouldBePinned = pinned; shouldBeMuted = muted; shouldReaderModeBeActive = readerMode
        }
    }

    /// how an extension asks for a new window (browser.windows.create)
    @MainActor @objc(WKWebExtensionWindowConfiguration) open class WindowConfiguration: NSObject, @unchecked Sendable {
        @objc open private(set) var windowType: WindowType
        @objc open private(set) var windowState: WindowState
        @objc open private(set) var frame: CGRect
        @objc open private(set) var tabURLs: [URL]
        @objc open private(set) var tabs: [any WKWebExtensionTab]
        @objc open private(set) var shouldBeFocused: Bool
        @objc open private(set) var shouldBePrivate: Bool
        init(type: WindowType, state: WindowState, frame: CGRect, tabURLs: [URL], tabs: [any WKWebExtensionTab], focused: Bool, private isPrivate: Bool) {
            windowType = type; windowState = state; self.frame = frame; self.tabURLs = tabURLs; self.tabs = tabs
            shouldBeFocused = focused; shouldBePrivate = isPrivate
        }
    }
}

// MARK: - tabs and windows

@available(iOS 18.4, *)
@MainActor @objc(WKWebExtensionTab) public protocol WKWebExtensionTab: NSObjectProtocol {
    @objc(windowForWebExtensionContext:) optional func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)?
    @objc(indexInWindowForWebExtensionContext:) optional func indexInWindow(for context: WKWebExtensionContext) -> Int
    @objc(parentTabForWebExtensionContext:) optional func parentTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)?
    @objc(setParentTab:forWebExtensionContext:completionHandler:)
    optional func setParentTab(_ parentTab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setParentTab:forWebExtensionContext:asyncCompletionHandler:)
    optional func setParentTab(_ parentTab: (any WKWebExtensionTab)?, for context: WKWebExtensionContext) async throws
    @objc(webViewForWebExtensionContext:) optional func webView(for context: WKWebExtensionContext) -> WKWebView?
    @objc(titleForWebExtensionContext:) optional func title(for context: WKWebExtensionContext) -> String?
    @objc(isPinnedForWebExtensionContext:) optional func isPinned(for context: WKWebExtensionContext) -> Bool
    @objc(setPinned:forWebExtensionContext:completionHandler:)
    optional func setPinned(_ pinned: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setPinned:forWebExtensionContext:asyncCompletionHandler:) optional func setPinned(_ pinned: Bool, for context: WKWebExtensionContext) async throws
    @objc(isReaderModeAvailableForWebExtensionContext:) optional func isReaderModeAvailable(for context: WKWebExtensionContext) -> Bool
    @objc(isReaderModeActiveForWebExtensionContext:) optional func isReaderModeActive(for context: WKWebExtensionContext) -> Bool
    @objc(setReaderModeActive:forWebExtensionContext:completionHandler:)
    optional func setReaderModeActive(_ active: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setReaderModeActive:forWebExtensionContext:asyncCompletionHandler:)
    optional func setReaderModeActive(_ active: Bool, for context: WKWebExtensionContext) async throws
    @objc(isPlayingAudioForWebExtensionContext:) optional func isPlayingAudio(for context: WKWebExtensionContext) -> Bool
    @objc(isMutedForWebExtensionContext:) optional func isMuted(for context: WKWebExtensionContext) -> Bool
    @objc(setMuted:forWebExtensionContext:completionHandler:)
    optional func setMuted(_ muted: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setMuted:forWebExtensionContext:asyncCompletionHandler:) optional func setMuted(_ muted: Bool, for context: WKWebExtensionContext) async throws
    @objc(sizeForWebExtensionContext:) optional func size(for context: WKWebExtensionContext) -> CGSize
    @objc(zoomFactorForWebExtensionContext:) optional func zoomFactor(for context: WKWebExtensionContext) -> Double
    @objc(setZoomFactor:forWebExtensionContext:completionHandler:)
    optional func setZoomFactor(_ zoomFactor: Double, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setZoomFactor:forWebExtensionContext:asyncCompletionHandler:)
    optional func setZoomFactor(_ zoomFactor: Double, for context: WKWebExtensionContext) async throws
    @objc(urlForWebExtensionContext:) optional func url(for context: WKWebExtensionContext) -> URL?
    @objc(pendingURLForWebExtensionContext:) optional func pendingURL(for context: WKWebExtensionContext) -> URL?
    @objc(isLoadingCompleteForWebExtensionContext:) optional func isLoadingComplete(for context: WKWebExtensionContext) -> Bool
    @objc(detectWebpageLocaleForWebExtensionContext:completionHandler:)
    optional func detectWebpageLocale(for context: WKWebExtensionContext, completionHandler: @escaping (Locale?, (any Error)?) -> Void)
    @objc(detectWebpageLocaleForWebExtensionContext:asyncCompletionHandler:)
    optional func detectWebpageLocale(for context: WKWebExtensionContext) async throws -> Locale?
    @objc(takeSnapshotUsingConfiguration:forWebExtensionContext:completionHandler:)
    optional func takeSnapshot(using configuration: WKSnapshotConfiguration, for context: WKWebExtensionContext, completionHandler: @escaping (UIImage?, (any Error)?) -> Void)
    @objc(takeSnapshotUsingConfiguration:forWebExtensionContext:asyncCompletionHandler:)
    optional func snapshot(using configuration: WKSnapshotConfiguration, for context: WKWebExtensionContext) async throws -> UIImage?
    @objc(loadURL:forWebExtensionContext:completionHandler:)
    optional func loadURL(_ url: URL, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(loadURL:forWebExtensionContext:asyncCompletionHandler:) optional func loadURL(_ url: URL, for context: WKWebExtensionContext) async throws
    @objc(reloadFromOrigin:forWebExtensionContext:completionHandler:)
    optional func reload(fromOrigin: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(reloadFromOrigin:forWebExtensionContext:asyncCompletionHandler:) optional func reload(fromOrigin: Bool, for context: WKWebExtensionContext) async throws
    @objc(goBackForWebExtensionContext:completionHandler:) optional func goBack(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(goBackForWebExtensionContext:asyncCompletionHandler:) optional func goBack(for context: WKWebExtensionContext) async throws
    @objc(goForwardForWebExtensionContext:completionHandler:) optional func goForward(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(goForwardForWebExtensionContext:asyncCompletionHandler:) optional func goForward(for context: WKWebExtensionContext) async throws
    @objc(activateForWebExtensionContext:completionHandler:) optional func activate(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(activateForWebExtensionContext:asyncCompletionHandler:) optional func activate(for context: WKWebExtensionContext) async throws
    @objc(isSelectedForWebExtensionContext:) optional func isSelected(for context: WKWebExtensionContext) -> Bool
    @objc(setSelected:forWebExtensionContext:completionHandler:)
    optional func setSelected(_ selected: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setSelected:forWebExtensionContext:asyncCompletionHandler:) optional func setSelected(_ selected: Bool, for context: WKWebExtensionContext) async throws
    @objc(duplicateUsingConfiguration:forWebExtensionContext:completionHandler:)
    optional func duplicate(using configuration: WKWebExtension.TabConfiguration, for context: WKWebExtensionContext,
                            completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void)
    @objc(duplicateUsingConfiguration:forWebExtensionContext:asyncCompletionHandler:)
    optional func duplicate(using configuration: WKWebExtension.TabConfiguration, for context: WKWebExtensionContext) async throws -> (any WKWebExtensionTab)?
    @objc(closeForWebExtensionContext:completionHandler:) optional func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(closeForWebExtensionContext:asyncCompletionHandler:) optional func close(for context: WKWebExtensionContext) async throws
    @objc(shouldGrantPermissionsOnUserGestureForWebExtensionContext:) optional func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool
    @objc(shouldBypassPermissionsForWebExtensionContext:) optional func shouldBypassPermissions(for context: WKWebExtensionContext) -> Bool
}

@available(iOS 18.4, *)
@MainActor @objc(WKWebExtensionWindow) public protocol WKWebExtensionWindow: NSObjectProtocol {
    @objc(tabsForWebExtensionContext:) optional func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab]
    @objc(activeTabForWebExtensionContext:) optional func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)?
    @objc(windowTypeForWebExtensionContext:) optional func windowType(for context: WKWebExtensionContext) -> WKWebExtension.WindowType
    @objc(windowStateForWebExtensionContext:) optional func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState
    @objc(setWindowState:forWebExtensionContext:completionHandler:)
    optional func setWindowState(_ state: WKWebExtension.WindowState, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setWindowState:forWebExtensionContext:asyncCompletionHandler:)
    optional func setWindowState(_ state: WKWebExtension.WindowState, for context: WKWebExtensionContext) async throws
    @objc(isPrivateForWebExtensionContext:) optional func isPrivate(for context: WKWebExtensionContext) -> Bool
    @objc(screenFrameForWebExtensionContext:) optional func screenFrame(for context: WKWebExtensionContext) -> CGRect
    @objc(frameForWebExtensionContext:) optional func frame(for context: WKWebExtensionContext) -> CGRect
    @objc(setFrame:forWebExtensionContext:completionHandler:)
    optional func setFrame(_ frame: CGRect, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(setFrame:forWebExtensionContext:asyncCompletionHandler:) optional func setFrame(_ frame: CGRect, for context: WKWebExtensionContext) async throws
    @objc(focusForWebExtensionContext:completionHandler:) optional func focus(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(focusForWebExtensionContext:asyncCompletionHandler:) optional func focus(for context: WKWebExtensionContext) async throws
    @objc(closeForWebExtensionContext:completionHandler:) optional func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void)
    @objc(closeForWebExtensionContext:asyncCompletionHandler:) optional func close(for context: WKWebExtensionContext) async throws
}

// MARK: - the controller's delegate

@available(iOS 18.4, *)
@MainActor @objc(WKWebExtensionControllerDelegate) public protocol WKWebExtensionControllerDelegate: NSObjectProtocol {
    @objc(webExtensionController:openWindowsForExtensionContext:)
    optional func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow]
    @objc(webExtensionController:focusedWindowForExtensionContext:)
    optional func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)?
    @objc(webExtensionController:openNewWindowUsingConfiguration:forExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
                                         for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionWindow)?, (any Error)?) -> Void)
    @objc(webExtensionController:openNewWindowUsingConfiguration:forExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
                                         for extensionContext: WKWebExtensionContext) async throws -> (any WKWebExtensionWindow)?
    @objc(webExtensionController:openNewTabUsingConfiguration:forExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration,
                                         for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, (any Error)?) -> Void)
    @objc(webExtensionController:openNewTabUsingConfiguration:forExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration,
                                         for extensionContext: WKWebExtensionContext) async throws -> (any WKWebExtensionTab)?
    @objc(webExtensionController:openOptionsPageForExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext,
                                         completionHandler: @escaping ((any Error)?) -> Void)
    @objc(webExtensionController:openOptionsPageForExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext) async throws
    @objc(webExtensionController:promptForPermissions:inTab:forExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>,
                                         in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext,
                                         completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void)
    @objc(webExtensionController:promptForPermissions:inTab:forExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>,
                                         in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<WKWebExtension.Permission>, Date?)
    @objc(webExtensionController:promptForPermissionToAccessURLs:inTab:forExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any WKWebExtensionTab)?,
                                         for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<URL>, Date?) -> Void)
    @objc(webExtensionController:promptForPermissionToAccessURLs:inTab:forExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any WKWebExtensionTab)?,
                                         for extensionContext: WKWebExtensionContext) async -> (Set<URL>, Date?)
    @objc(webExtensionController:promptForPermissionMatchPatterns:inTab:forExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
                                         in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext,
                                         completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void)
    @objc(webExtensionController:promptForPermissionMatchPatterns:inTab:forExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
                                         in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext) async -> (Set<WKWebExtension.MatchPattern>, Date?)
    @objc(webExtensionController:didUpdateAction:forExtensionContext:)
    optional func webExtensionController(_ controller: WKWebExtensionController, didUpdate action: WKWebExtension.Action, forExtensionContext context: WKWebExtensionContext)
    @objc(webExtensionController:presentPopupForAction:forExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action, for context: WKWebExtensionContext,
                                         completionHandler: @escaping ((any Error)?) -> Void)
    @objc(webExtensionController:presentPopupForAction:forExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action, for context: WKWebExtensionContext) async throws
    @objc(webExtensionController:sendMessage:toApplicationWithIdentifier:forExtensionContext:replyHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, sendMessage message: Any, toApplicationWithIdentifier applicationIdentifier: String?,
                                         for extensionContext: WKWebExtensionContext, replyHandler: @escaping (Any?, (any Error)?) -> Void)
    @objc(webExtensionController:sendMessage:toApplicationWithIdentifier:forExtensionContext:asyncReplyHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, sendMessage message: Any, toApplicationWithIdentifier applicationIdentifier: String?,
                                         for extensionContext: WKWebExtensionContext) async throws -> Any?
    @objc(webExtensionController:connectUsingMessagePort:forExtensionContext:completionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, connectUsing port: WKWebExtension.MessagePort, for extensionContext: WKWebExtensionContext,
                                         completionHandler: @escaping ((any Error)?) -> Void)
    @objc(webExtensionController:connectUsingMessagePort:forExtensionContext:asyncCompletionHandler:)
    optional func webExtensionController(_ controller: WKWebExtensionController, connectUsing port: WKWebExtension.MessagePort, for extensionContext: WKWebExtensionContext) async throws
}

/// The completion-handler form of the `async` requirements above: Swift exposes an implemented async requirement to
/// Objective-C under these selectors, so isim calls them through objc_msgSend (like _WKAsync in WKWebView.swift).
@available(iOS 18.4, *)
@objc protocol _WKExtAsync {
    @objc(setParentTab:forWebExtensionContext:asyncCompletionHandler:) func _setParentTab(_ t: AnyObject?, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(setPinned:forWebExtensionContext:asyncCompletionHandler:) func _setPinned(_ v: Bool, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(setReaderModeActive:forWebExtensionContext:asyncCompletionHandler:) func _setReaderMode(_ v: Bool, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(setMuted:forWebExtensionContext:asyncCompletionHandler:) func _setMuted(_ v: Bool, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(setZoomFactor:forWebExtensionContext:asyncCompletionHandler:) func _setZoom(_ v: Double, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(detectWebpageLocaleForWebExtensionContext:asyncCompletionHandler:) func _detectLocale(for c: WKWebExtensionContext, completionHandler: @escaping (Locale?, Error?) -> Void)
    @objc(takeSnapshotUsingConfiguration:forWebExtensionContext:asyncCompletionHandler:)
    func _snapshot(_ s: WKSnapshotConfiguration, for c: WKWebExtensionContext, completionHandler: @escaping (UIImage?, Error?) -> Void)
    @objc(loadURL:forWebExtensionContext:asyncCompletionHandler:) func _load(_ u: URL, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(reloadFromOrigin:forWebExtensionContext:asyncCompletionHandler:) func _reload(_ v: Bool, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(goBackForWebExtensionContext:asyncCompletionHandler:) func _back(for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(goForwardForWebExtensionContext:asyncCompletionHandler:) func _forward(for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(activateForWebExtensionContext:asyncCompletionHandler:) func _activate(for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(setSelected:forWebExtensionContext:asyncCompletionHandler:) func _setSelected(_ v: Bool, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(duplicateUsingConfiguration:forWebExtensionContext:asyncCompletionHandler:)
    func _duplicate(_ t: WKWebExtension.TabConfiguration, for c: WKWebExtensionContext, completionHandler: @escaping (AnyObject?, Error?) -> Void)
    @objc(closeForWebExtensionContext:asyncCompletionHandler:) func _close(for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(setWindowState:forWebExtensionContext:asyncCompletionHandler:) func _setState(_ v: WKWebExtension.WindowState, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(setFrame:forWebExtensionContext:asyncCompletionHandler:) func _setFrame(_ v: CGRect, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(focusForWebExtensionContext:asyncCompletionHandler:) func _focus(for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(webExtensionController:openNewWindowUsingConfiguration:forExtensionContext:asyncCompletionHandler:)
    func _openWindow(_ x: WKWebExtensionController, _ w: WKWebExtension.WindowConfiguration, for c: WKWebExtensionContext, completionHandler: @escaping (AnyObject?, Error?) -> Void)
    @objc(webExtensionController:openNewTabUsingConfiguration:forExtensionContext:asyncCompletionHandler:)
    func _openTab(_ x: WKWebExtensionController, _ t: WKWebExtension.TabConfiguration, for c: WKWebExtensionContext, completionHandler: @escaping (AnyObject?, Error?) -> Void)
    @objc(webExtensionController:openOptionsPageForExtensionContext:asyncCompletionHandler:)
    func _openOptions(_ x: WKWebExtensionController, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(webExtensionController:promptForPermissions:inTab:forExtensionContext:asyncCompletionHandler:)
    func _prompt(_ x: WKWebExtensionController, permissions p: Set<WKWebExtension.Permission>, in t: AnyObject?, for c: WKWebExtensionContext,
                 completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void)
    @objc(webExtensionController:promptForPermissionToAccessURLs:inTab:forExtensionContext:asyncCompletionHandler:)
    func _prompt(_ x: WKWebExtensionController, urls u: Set<URL>, in t: AnyObject?, for c: WKWebExtensionContext, completionHandler: @escaping (Set<URL>, Date?) -> Void)
    @objc(webExtensionController:promptForPermissionMatchPatterns:inTab:forExtensionContext:asyncCompletionHandler:)
    func _prompt(_ x: WKWebExtensionController, patterns p: Set<WKWebExtension.MatchPattern>, in t: AnyObject?, for c: WKWebExtensionContext,
                 completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void)
    @objc(webExtensionController:presentPopupForAction:forExtensionContext:asyncCompletionHandler:)
    func _presentPopup(_ x: WKWebExtensionController, _ a: WKWebExtension.Action, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
    @objc(webExtensionController:sendMessage:toApplicationWithIdentifier:forExtensionContext:asyncReplyHandler:)
    func _send(_ x: WKWebExtensionController, _ m: Any, app: String?, for c: WKWebExtensionContext, completionHandler: @escaping (Any?, Error?) -> Void)
    @objc(webExtensionController:connectUsingMessagePort:forExtensionContext:asyncCompletionHandler:)
    func _connect(_ x: WKWebExtensionController, _ p: WKWebExtension.MessagePort, for c: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void)
}
@available(iOS 18.4, *)
func _wkExtAsync(_ o: AnyObject) -> _WKExtAsync { unsafeBitCast(o, to: _WKExtAsync.self) }

// MARK: - actions

@available(iOS 18.4, *)
extension WKWebExtension {
    /// the extension's toolbar button (manifest `action`, or `browser_action` / `page_action` in manifest version 2), for
    /// all tabs (action(for: nil)) or one tab; `browser.action` changes it
    @MainActor @objc(WKWebExtensionAction) open class Action: NSObject, @unchecked Sendable {
        @objc open private(set) weak var webExtensionContext: WKWebExtensionContext?
        weak var _tab: AnyObject?
        weak var _parent: Action?               // the action for all tabs, when this one is for a tab
        var _label: String?, _badge: String?, _enabled: Bool?, _popup: String?, _icon: String?
        var _popupWebView: WKWebView?, _popupController: UIViewController?, _popupDelegate: _WKExtPopupDelegate?
        init(context: WKWebExtensionContext, tab: AnyObject?, parent: Action?) {
            webExtensionContext = context; _tab = tab; _parent = parent
            super.init()
            if parent == nil {
                let m = context.webExtension._actionManifest
                _label = context.webExtension.displayActionLabel ?? context.webExtension.displayName ?? ""
                _popup = m?["default_popup"] as? String ?? ""
                _enabled = true; _badge = ""
            }
        }
        @objc open var associatedTab: (any WKWebExtensionTab)? { _tab as? any WKWebExtensionTab }
        @objc(iconForSize:) open func icon(for size: CGSize) -> UIImage? {
            guard let ext = webExtensionContext?.webExtension else { return nil }
            if let p = _icon ?? _parent?._icon, !p.isEmpty, let img = UIImage(contentsOfFile: ext._base.appendingPathComponent(p).path) { return img }
            return ext.actionIcon(for: size)
        }
        @objc open var label: String { _label ?? _parent?.label ?? "" }
        @objc open var badgeText: String { _badge ?? _parent?.badgeText ?? "" }
        @objc open var hasUnreadBadgeText = false
        @objc open var inspectionName: String?
        @objc open var isEnabled: Bool { _enabled ?? _parent?.isEnabled ?? true }
        @objc open var menuItems: [UIMenuElement] { webExtensionContext?._rt.menuElements(action: true, tab: associatedTab) ?? [] }
        var _popupPath: String { _popup ?? _parent?._popupPath ?? "" }
        @objc open var presentsPopup: Bool { isEnabled && !_popupPath.isEmpty }
        @objc open var popupWebView: WKWebView? {
            guard presentsPopup, let ctx = webExtensionContext, ctx.isLoaded else { return nil }
            if let w = _popupWebView { return w }
            let config = ctx.webViewConfiguration ?? WKWebViewConfiguration()
            let w = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 240), configuration: config)
            let d = _WKExtPopupDelegate(self)
            w.navigationDelegate = d; w.uiDelegate = d
            w.isInspectable = ctx.isInspectable
            _popupDelegate = d; _popupWebView = w
            ctx._rt.pages.append(_WKWeakView(w))
            w.load(URLRequest(url: ctx.baseURL.appendingPathComponent(_popupPath)))
            return w
        }
        @objc open var popupViewController: UIViewController? {
            guard let w = popupWebView else { return nil }
            if let c = _popupController { return c }
            let c = UIViewController()
            c.view = w
            c.preferredContentSize = CGSize(width: 320, height: 240)
            c.title = label
            _popupController = c
            return c
        }
        @objc open func closePopup() {
            let c = _popupController
            _popupController = nil
            if let w = _popupWebView { webExtensionContext?._rt.pages.removeAll { $0.view == nil || $0.view === w } }
            _popupWebView = nil; _popupDelegate = nil
            if let c, c.presentingViewController != nil { c.dismiss(animated: true) }
        }
        func _changed() {
            guard let ctx = webExtensionContext, let c = ctx.webExtensionController else { return }
            c.delegate?.webExtensionController?(c, didUpdate: self, forExtensionContext: ctx)
        }
    }
}

/// a popup's size follows its page (like Safari's popovers); window.close() in the popup closes it
@available(iOS 18.4, *)
@MainActor final class _WKExtPopupDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var action: WKWebExtension.Action?
    init(_ a: WKWebExtension.Action) { action = a }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("[document.documentElement.scrollWidth, document.documentElement.scrollHeight]") { [weak self] r, _ in
            guard let a = r as? [NSNumber], a.count == 2, let c = self?.action?._popupController else { return }
            c.preferredContentSize = CGSize(width: min(max(a[0].doubleValue, 160), 400), height: min(max(a[1].doubleValue, 40), 600))
        }
    }
    func webViewDidClose(_ webView: WKWebView) { action?.closePopup() }
}

// MARK: - commands

@available(iOS 18.4, *)
extension WKWebExtension {
    /// a keyboard shortcut from the manifest's `commands` (`_execute_action` performs the action)
    @MainActor @objc(WKWebExtensionCommand) open class Command: NSObject, @unchecked Sendable {
        @objc open private(set) weak var webExtensionContext: WKWebExtensionContext?
        @objc(identifier) open private(set) var id: String
        @objc open private(set) var title: String
        @objc open var activationKey: String?
        @objc open var modifierFlags: UIKeyModifierFlags
        init(context: WKWebExtensionContext, id: String, entry: [String: Any]) {
            webExtensionContext = context; self.id = id
            let ext = context.webExtension
            title = id == "_execute_action" || id == "_execute_browser_action" || id == "_execute_page_action"
                ? (ext.displayActionLabel ?? ext.displayName ?? id) : (ext._localized(entry["description"] as? String) ?? id)
            var shortcut: String?
            if let s = entry["suggested_key"] as? [String: Any] { shortcut = (s["ios"] ?? s["mac"] ?? s["default"]) as? String }
            else { shortcut = entry["suggested_key"] as? String }
            var flags: UIKeyModifierFlags = [], key: String?
            for part in (shortcut ?? "").split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                switch part.lowercased() {
                case "ctrl", "command": flags.insert(.command)          // Chrome's convention: Ctrl is ⌘ on Apple platforms
                case "macctrl": flags.insert(.control)
                case "alt", "option": flags.insert(.alternate)
                case "shift": flags.insert(.shift)
                case "": break
                default: key = Self._key(part)
                }
            }
            activationKey = key; modifierFlags = key == nil ? [] : flags
        }
        static func _key(_ s: String) -> String {
            switch s.lowercased() {
            case "comma": return ","
            case "period": return "."
            case "space": return " "
            case "up": return UIKeyCommand.inputUpArrow
            case "down": return UIKeyCommand.inputDownArrow
            case "left": return UIKeyCommand.inputLeftArrow
            case "right": return UIKeyCommand.inputRightArrow
            case "home": return UIKeyCommand.inputHome
            case "end": return UIKeyCommand.inputEnd
            case "pageup": return UIKeyCommand.inputPageUp
            case "pagedown": return UIKeyCommand.inputPageDown
            default: return s.lowercased()
            }
        }
        @objc open var menuItem: UIMenuElement {
            let a = UIAction(title: title) { [weak self] _ in
                guard let self, let ctx = self.webExtensionContext else { return }
                ctx.performCommand(self)
            }
            return a
        }
        @objc open var keyCommand: UIKeyCommand? {
            guard let key = activationKey, !key.isEmpty else { return nil }
            let k = UIKeyCommand(title: title, image: nil, action: NSSelectorFromString("_performWebExtensionCommandForKeyCommand:"), input: key,
                                 modifierFlags: modifierFlags, propertyList: id)
            return k
        }
    }
}

// MARK: - native messaging

public let WKWebExtensionMessagePortErrorDomain = "WKWebExtensionMessagePortErrorDomain"
public let WKWebExtensionDataRecordErrorDomain = "WKWebExtensionDataRecordErrorDomain"

@available(iOS 18.4, *)
extension WKWebExtension {
    /// a connection between an extension (browser.runtime.connectNative) and the app
    @MainActor @objc(WKWebExtensionMessagePort) open class MessagePort: NSObject, @unchecked Sendable {
        public struct Error: Swift.Error, CustomNSError, Hashable, @unchecked Sendable {
            public enum Code: Int, Sendable { case unknown = 1, notConnected, messageInvalid }
            public let code: Code
            public let userInfo: [String: Any]
            public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
            public static var errorDomain: String { WKWebExtensionMessagePortErrorDomain }
            public var errorCode: Int { code.rawValue }
            public var errorUserInfo: [String: Any] { userInfo }
            public static func == (a: Error, b: Error) -> Bool { a.code == b.code }
            public func hash(into h: inout Hasher) { h.combine(code) }
            public static var unknown: Code { .unknown }
            public static var notConnected: Code { .notConnected }
            public static var messageInvalid: Code { .messageInvalid }
        }
        public static let errorDomain = WKWebExtensionMessagePortErrorDomain
        @objc open private(set) var applicationIdentifier: String?
        @objc open var messageHandler: ((Any?, (any Swift.Error)?) -> Void)?
        @objc open var disconnectHandler: (((any Swift.Error)?) -> Void)?
        @objc open private(set) var isDisconnected = false
        let _id: String
        weak var _context: WKWebExtensionContext?
        weak var _view: WKWebView?
        var _world: WKContentWorld
        init(id: String, application: String?, context: WKWebExtensionContext, view: WKWebView, world: WKContentWorld) {
            _id = id; applicationIdentifier = application; _context = context; _view = view; _world = world
        }
        @objc(sendMessage:completionHandler:) open func sendMessage(_ message: Any?, completionHandler: (((any Swift.Error)?) -> Void)? = nil) {
            guard !isDisconnected, let view = _view else { completionHandler?(Error(.notConnected)); return }
            let m = message ?? NSNull()
            guard JSONSerialization.isValidJSONObject([m]) else { completionHandler?(Error(.messageInvalid)); return }
            _context?._rt.dispatch(view, world: _world, "port.message", [_id, m])
            completionHandler?(nil)
        }
        open func sendMessage(_ message: Any?) async throws {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Swift.Error>) in
                sendMessage(message) { e in if let e { c.resume(throwing: e) } else { c.resume() } }
            }
        }
        @objc open func disconnect() { disconnect(throwing: nil) }
        @objc(disconnectWithError:) open func disconnect(throwing error: (any Swift.Error)?) {
            guard !isDisconnected else { return }
            isDisconnected = true
            if let view = _view { _context?._rt.dispatch(view, world: _world, "port.disconnect", [_id, error.map { ($0 as NSError).localizedDescription } ?? NSNull()]) }
            _context?._rt.ports[_id] = nil
        }
        /// the extension disconnected
        func _remoteDisconnected() {
            guard !isDisconnected else { return }
            isDisconnected = true
            _context?._rt.ports[_id] = nil
            disconnectHandler?(nil)
        }
    }

    /// what one extension stores, by data type (WKWebExtensionController.fetchDataRecords(ofTypes:))
    @MainActor @objc(WKWebExtensionDataRecord) open class DataRecord: NSObject, @unchecked Sendable {
        public struct Error: Swift.Error, CustomNSError, Hashable, @unchecked Sendable {
            public enum Code: Int, Sendable { case unknown = 1, localStorageFailed, sessionStorageFailed, synchronizedStorageFailed }
            public let code: Code
            public let userInfo: [String: Any]
            public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; self.userInfo = userInfo }
            public static var errorDomain: String { WKWebExtensionDataRecordErrorDomain }
            public var errorCode: Int { code.rawValue }
            public var errorUserInfo: [String: Any] { userInfo }
            public static func == (a: Error, b: Error) -> Bool { a.code == b.code }
            public func hash(into h: inout Hasher) { h.combine(code) }
            public static var unknown: Code { .unknown }
            public static var localStorageFailed: Code { .localStorageFailed }
            public static var sessionStorageFailed: Code { .sessionStorageFailed }
            public static var synchronizedStorageFailed: Code { .synchronizedStorageFailed }
        }
        public static let errorDomain = WKWebExtensionDataRecordErrorDomain
        @objc open private(set) var displayName: String
        @objc open private(set) var uniqueIdentifier: String
        var _sizes: [DataType: Int]
        @objc open var containedDataTypes: Set<DataType> { Set(_sizes.keys) }
        open private(set) var errors: [any Swift.Error] = []
        @objc open var totalSizeInBytes: Int { _sizes.values.reduce(0, +) }
        @objc(sizeInBytesOfTypes:) open func sizeInBytes(ofTypes dataTypes: Set<DataType>) -> Int { _sizes.filter { dataTypes.contains($0.key) }.map(\.value).reduce(0, +) }
        weak var _context: WKWebExtensionContext?
        init(context: WKWebExtensionContext, sizes: [DataType: Int]) {
            displayName = context.webExtension.displayName ?? context.uniqueIdentifier
            uniqueIdentifier = context.uniqueIdentifier; _sizes = sizes; _context = context
        }
        @objc(errors) var _objc_errors: [NSError] { errors.map { $0 as NSError } }
    }
}
