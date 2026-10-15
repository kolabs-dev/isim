// isim MultipeerConnectivity for Objective-C (sdk-src/Frameworks/MultipeerConnectivity): the classes carry Apple's
// Objective-C names and these members Apple's selectors. The delegate protocols are Swift protocols in the overlay
// (apps built against them keep their witness tables), so an Objective-C delegate is wrapped in an adapter that conforms
// to the Swift protocol and sends each call to the selectors the object implements.
import UIKit
import ObjectiveC

nonisolated(unsafe) private var _mcObjCDelegateKey: UInt8 = 0

/// sends an Objective-C message with up to four object arguments to an object that implements it
@discardableResult
func _mcSend(_ target: AnyObject?, _ sel: String, _ a: AnyObject? = nil, _ b: AnyObject? = nil, _ c: AnyObject? = nil, _ d: AnyObject? = nil) -> Bool {
    let s = NSSelectorFromString(sel)
    guard let t = target as? NSObject, t.responds(to: s) else { return false }
    typealias Send = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?, AnyObject?) -> Void
    unsafeBitCast(t.method(for: s), to: Send.self)(t, s, a, b, c, d)
    return true
}
/// keeps an adapter alive while its owner lives (the owners' delegates are weak)
func _mcRetain(_ owner: AnyObject, _ adapter: AnyObject?) {
    objc_setAssociatedObject(owner, &_mcObjCDelegateKey, adapter, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}
func _mcInfo(_ info: [String: String]?) -> NSDictionary? { info.map { $0 as NSDictionary } }

final class _MCObjCSessionDelegate: MCSessionDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let s = NSSelectorFromString("session:peer:didChangeState:")
        guard let t = target, t.responds(to: s) else { return }
        typealias Send = @convention(c) (AnyObject, Selector, AnyObject, AnyObject, Int) -> Void
        unsafeBitCast(t.method(for: s), to: Send.self)(t, s, session, peerID, state.rawValue)
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        _mcSend(target, "session:didReceiveData:fromPeer:", session, data as NSData, peerID)
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        _mcSend(target, "session:didReceiveStream:withName:fromPeer:", session, stream, streamName as NSString, peerID)
    }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        _mcSend(target, "session:didStartReceivingResourceWithName:fromPeer:withProgress:", session, resourceName as NSString, peerID, progress)
    }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?,
                 withError error: Error?) {
        let s = NSSelectorFromString("session:didFinishReceivingResourceWithName:fromPeer:atURL:withError:")
        guard let t = target, t.responds(to: s) else { return }
        typealias Send = @convention(c) (AnyObject, Selector, AnyObject, AnyObject, AnyObject, AnyObject?, AnyObject?) -> Void
        unsafeBitCast(t.method(for: s), to: Send.self)(t, s, session, resourceName as NSString, peerID, localURL.map { $0 as NSURL },
                                                       error.map { $0 as NSError })
    }
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        let handler: @convention(block) (Bool) -> Void = { certificateHandler($0) }
        if !_mcSend(target, "session:didReceiveCertificate:fromPeer:certificateHandler:", session, certificate.map { $0 as NSArray }, peerID,
                    handler as AnyObject) { certificateHandler(true) }
    }
}
final class _MCObjCAdvertiserDelegate: MCNearbyServiceAdvertiserDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let handler: @convention(block) (Bool, MCSession?) -> Void = { invitationHandler($0, $1) }
        if !_mcSend(target, "advertiser:didReceiveInvitationFromPeer:withContext:invitationHandler:", advertiser, peerID, context.map { $0 as NSData },
                    handler as AnyObject) { invitationHandler(false, nil) }
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        _mcSend(target, "advertiser:didNotStartAdvertisingPeer:", advertiser, error as NSError)
    }
}
final class _MCObjCBrowserDelegate: MCNearbyServiceBrowserDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        _mcSend(target, "browser:foundPeer:withDiscoveryInfo:", browser, peerID, _mcInfo(info))
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) { _mcSend(target, "browser:lostPeer:", browser, peerID) }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        _mcSend(target, "browser:didNotStartBrowsingForPeers:", browser, error as NSError)
    }
}
final class _MCObjCBrowserViewControllerDelegate: MCBrowserViewControllerDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func browserViewControllerDidFinish(_ vc: MCBrowserViewController) { _mcSend(target, "browserViewControllerDidFinish:", vc) }
    func browserViewControllerWasCancelled(_ vc: MCBrowserViewController) { _mcSend(target, "browserViewControllerWasCancelled:", vc) }
    func browserViewController(_ vc: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) -> Bool {
        let s = NSSelectorFromString("browserViewController:shouldPresentNearbyPeer:withDiscoveryInfo:")
        guard let t = target, t.responds(to: s) else { return true }
        typealias Send = @convention(c) (AnyObject, Selector, AnyObject, AnyObject, AnyObject?) -> Bool
        return unsafeBitCast(t.method(for: s), to: Send.self)(t, s, vc, peerID, _mcInfo(info))
    }
}
final class _MCObjCAssistantDelegate: MCAdvertiserAssistantDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func advertiserAssistantWillPresentInvitation(_ a: MCAdvertiserAssistant) { _mcSend(target, "advertiserAssistantWillPresentInvitation:", a) }
    func advertiserAssistantDidDismissInvitation(_ a: MCAdvertiserAssistant) { _mcSend(target, "advertiserAssistantDidDismissInvitation:", a) }
}

extension MCPeerID {
    @objc(initWithDisplayName:) convenience init(_objcDisplayName name: String) { self.init(displayName: name) }
    @objc(displayName) var _objc_displayName: String { displayName }
}

extension MCSession {
    @objc(initWithPeer:) convenience init(_objcPeer peer: MCPeerID) { self.init(peer: peer) }
    @objc(initWithPeer:securityIdentity:encryptionPreference:)
    convenience init(_objcPeer peer: MCPeerID, securityIdentity: [Any]?, encryptionPreference: Int) {
        self.init(peer: peer, securityIdentity: securityIdentity, encryptionPreference: MCEncryptionPreference(rawValue: encryptionPreference) ?? .optional)
    }
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _MCObjCSessionDelegate)?.target ?? (delegate as? NSObject) }
        set { let a = newValue.map(_MCObjCSessionDelegate.init); _mcRetain(self, a); delegate = a }
    }
    @objc(myPeerID) var _objc_myPeerID: MCPeerID { myPeerID }
    @objc(securityIdentity) var _objc_securityIdentity: [Any]? { securityIdentity }
    @objc(encryptionPreference) var _objc_encryptionPreference: Int { encryptionPreference.rawValue }
    @objc(connectedPeers) var _objc_connectedPeers: [MCPeerID] { connectedPeers }
    @objc(sendData:toPeers:withMode:error:) func _objc_send(_ data: Data, toPeers peers: [MCPeerID], withMode mode: Int) throws {
        try send(data, toPeers: peers, with: MCSessionSendDataMode(rawValue: mode) ?? .reliable)
    }
    @objc(sendResourceAtURL:withName:toPeer:withCompletionHandler:)
    func _objc_sendResource(_ url: URL, withName name: String, toPeer peer: MCPeerID,
                            withCompletionHandler h: (@convention(block) (NSError?) -> Void)?) -> Progress? {
        sendResource(at: url, withName: name, toPeer: peer) { e in h?(e.map { $0 as NSError }) }
    }
    @objc(startStreamWithName:toPeer:error:) func _objc_startStream(_ name: String, toPeer peer: MCPeerID) throws -> OutputStream {
        try startStream(withName: name, toPeer: peer)
    }
    @objc(disconnect) func _objc_disconnect() { disconnect() }
    @objc(nearbyConnectionDataForPeer:withCompletionHandler:)
    func _objc_nearbyConnectionData(_ peer: MCPeerID, withCompletionHandler h: @escaping @convention(block) (Data?, NSError?) -> Void) {
        nearbyConnectionData(forPeer: peer) { d, e in h(d, e.map { $0 as NSError }) }
    }
    @objc(connectPeer:withNearbyConnectionData:) func _objc_connectPeer(_ peer: MCPeerID, withNearbyConnectionData d: Data) { connectPeer(peer, withNearbyConnectionData: d) }
    @objc(cancelConnectPeer:) func _objc_cancelConnectPeer(_ peer: MCPeerID) { cancelConnectPeer(peer) }
}

extension MCNearbyServiceAdvertiser {
    @objc(initWithPeer:discoveryInfo:serviceType:)
    convenience init(_objcPeer peer: MCPeerID, discoveryInfo: [String: String]?, serviceType: String) {
        self.init(peer: peer, discoveryInfo: discoveryInfo, serviceType: serviceType)
    }
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _MCObjCAdvertiserDelegate)?.target ?? (delegate as? NSObject) }
        set { let a = newValue.map(_MCObjCAdvertiserDelegate.init); _mcRetain(self, a); delegate = a }
    }
    @objc(myPeerID) var _objc_myPeerID: MCPeerID { myPeerID }
    @objc(discoveryInfo) var _objc_discoveryInfo: [String: String]? { discoveryInfo }
    @objc(serviceType) var _objc_serviceType: String { serviceType }
    @objc(startAdvertisingPeer) func _objc_start() { startAdvertisingPeer() }
    @objc(stopAdvertisingPeer) func _objc_stop() { stopAdvertisingPeer() }
}

extension MCNearbyServiceBrowser {
    @objc(initWithPeer:serviceType:) convenience init(_objcPeer peer: MCPeerID, serviceType: String) { self.init(peer: peer, serviceType: serviceType) }
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _MCObjCBrowserDelegate)?.target ?? (delegate as? NSObject) }
        set { let a = newValue.map(_MCObjCBrowserDelegate.init); _mcRetain(self, a); delegate = a }
    }
    @objc(myPeerID) var _objc_myPeerID: MCPeerID { myPeerID }
    @objc(serviceType) var _objc_serviceType: String { serviceType }
    @objc(startBrowsingForPeers) func _objc_start() { startBrowsingForPeers() }
    @objc(stopBrowsingForPeers) func _objc_stop() { stopBrowsingForPeers() }
    @objc(invitePeer:toSession:withContext:timeout:)
    func _objc_invite(_ peer: MCPeerID, toSession session: MCSession, withContext context: Data?, timeout: TimeInterval) {
        invitePeer(peer, to: session, withContext: context, timeout: timeout)
    }
}

extension MCBrowserViewController {
    @objc(initWithBrowser:session:) convenience init(_objcBrowser browser: MCNearbyServiceBrowser, session: MCSession) {
        self.init(browser: browser, session: session)
    }
    @objc(initWithServiceType:session:) convenience init(_objcServiceType serviceType: String, session: MCSession) {
        self.init(serviceType: serviceType, session: session)
    }
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _MCObjCBrowserViewControllerDelegate)?.target ?? (delegate as? NSObject) }
        set { let a = newValue.map(_MCObjCBrowserViewControllerDelegate.init); _mcRetain(self, a); delegate = a }
    }
    @objc(browser) var _objc_browser: MCNearbyServiceBrowser? { browser }
    @objc(session) var _objc_session: MCSession { session }
    @objc(minimumNumberOfPeers) var _objc_minimumNumberOfPeers: Int { get { minimumNumberOfPeers } set { minimumNumberOfPeers = newValue } }
    @objc(maximumNumberOfPeers) var _objc_maximumNumberOfPeers: Int { get { maximumNumberOfPeers } set { maximumNumberOfPeers = newValue } }
}

extension MCAdvertiserAssistant {
    @objc(initWithServiceType:discoveryInfo:session:)
    convenience init(_objcServiceType serviceType: String, discoveryInfo: [String: String]?, session: MCSession) {
        self.init(serviceType: serviceType, discoveryInfo: discoveryInfo, session: session)
    }
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _MCObjCAssistantDelegate)?.target ?? (delegate as? NSObject) }
        set { let a = newValue.map(_MCObjCAssistantDelegate.init); _mcRetain(self, a); delegate = a }
    }
    @objc(session) var _objc_session: MCSession { session }
    @objc(discoveryInfo) var _objc_discoveryInfo: [String: String]? { discoveryInfo }
    @objc(serviceType) var _objc_serviceType: String { serviceType }
    @objc(start) func _objc_start() { start() }
    @objc(stop) func _objc_stop() { stop() }
}
