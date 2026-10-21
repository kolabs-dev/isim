// isim NearbyInteraction (self-authored, iOS API names): like Apple's Simulator, the device has no Ultra Wideband chip.
// NISession reports no capabilities and no discovery token, and running a configuration invalidates the session with
// NIError.unsupportedPlatform. The types exist so apps build and run their "not supported" paths.
import Foundation
import simd

public let NIErrorDomain = "com.apple.NearbyInteraction"
public struct NIError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, @unchecked Sendable {
        case unsupportedPlatform = -5889, invalidConfiguration = -5888, sessionFailed = -5887, resourceUsageTimeout = -5886
        case activeSessionsLimitExceeded = -5885, userDidNotAllow = -5884, invalidARConfiguration = -5883
        case accessoryPeerDeviceUnavailable = -5882, incompatiblePeerDevice = -5881, activeExtendedDistanceSessionsLimitExceeded = -5880
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { NIErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: code == .unsupportedPlatform ? "Nearby Interaction is not supported on this platform." : "Nearby Interaction error \(code.rawValue)."]
    }
    public static var unsupportedPlatform: Code { .unsupportedPlatform }
    public static var invalidConfiguration: Code { .invalidConfiguration }
    public static var sessionFailed: Code { .sessionFailed }
    public static var resourceUsageTimeout: Code { .resourceUsageTimeout }
    public static var activeSessionsLimitExceeded: Code { .activeSessionsLimitExceeded }
    public static var userDidNotAllow: Code { .userDidNotAllow }
    public static var invalidARConfiguration: Code { .invalidARConfiguration }
    public static var accessoryPeerDeviceUnavailable: Code { .accessoryPeerDeviceUnavailable }
    public static var incompatiblePeerDevice: Code { .incompatiblePeerDevice }
    public static var activeExtendedDistanceSessionsLimitExceeded: Code { .activeExtendedDistanceSessionsLimitExceeded }
}

/// what the device's Ultra Wideband hardware can measure: nothing on isim
@objc(NIDeviceCapability) public protocol NIDeviceCapability: NSObjectProtocol {
    var supportsPreciseDistanceMeasurement: Bool { get }
    var supportsDirectionMeasurement: Bool { get }
    var supportsCameraAssistance: Bool { get }
    var supportsExtendedDistanceMeasurement: Bool { get }
}
final class _NINoCapability: NSObject, NIDeviceCapability {
    var supportsPreciseDistanceMeasurement: Bool { false }
    var supportsDirectionMeasurement: Bool { false }
    var supportsCameraAssistance: Bool { false }
    var supportsExtendedDistanceMeasurement: Bool { false }
}

/// identifies a device in a session (shared with the peer); isim never makes one
@objc(NIDiscoveryToken) open class NIDiscoveryToken: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    let data: Data
    init(data: Data) { self.data = data }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        guard let d = coder.decodeObject(of: NSData.self, forKey: "token") as Data? else { return nil }
        data = d
    }
    public func encode(with coder: NSCoder) { coder.encode(data as NSData, forKey: "token") }
    public func copy(with zone: NSZone? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? NIDiscoveryToken)?.data == data }
    open override var hash: Int { data.hashValue }
}

@objc(NIConfiguration) open class NIConfiguration: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    override init() {}
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {}
    public func encode(with coder: NSCoder) {}
    public func copy(with zone: NSZone? = nil) -> Any { self }
}
/// ranging with another iPhone or Apple Watch, whose discovery token the app exchanged
@objc(NINearbyPeerConfiguration) open class NINearbyPeerConfiguration: NIConfiguration, @unchecked Sendable {
    public let peerDiscoveryToken: NIDiscoveryToken
    open var isCameraAssistanceEnabled = false
    open var isExtendedDistanceMeasurementEnabled = false
    public init(peerToken: NIDiscoveryToken) { peerDiscoveryToken = peerToken; super.init() }
    public required init?(coder: NSCoder) {
        guard let t = coder.decodeObject(of: NIDiscoveryToken.self, forKey: "peer") else { return nil }
        peerDiscoveryToken = t; super.init(coder: coder)
    }
    open override func encode(with coder: NSCoder) { coder.encode(peerDiscoveryToken, forKey: "peer") }
}
/// ranging with a third-party accessory, from the configuration data it sent
@objc(NINearbyAccessoryConfiguration) open class NINearbyAccessoryConfiguration: NIConfiguration, @unchecked Sendable {
    public let accessoryDiscoveryToken: NIDiscoveryToken
    open var isCameraAssistanceEnabled = false
    public init(data: Data) throws {
        guard !data.isEmpty else { throw NIError(.invalidConfiguration) }
        accessoryDiscoveryToken = NIDiscoveryToken(data: data); super.init()
    }
    public init(accessoryData: Data, bluetoothPeerIdentifier identifier: UUID) throws {
        guard !accessoryData.isEmpty else { throw NIError(.invalidConfiguration) }
        accessoryDiscoveryToken = NIDiscoveryToken(data: accessoryData); super.init()
    }
    public required init?(coder: NSCoder) {
        guard let t = coder.decodeObject(of: NIDiscoveryToken.self, forKey: "accessory") else { return nil }
        accessoryDiscoveryToken = t; super.init(coder: coder)
    }
    open override func encode(with coder: NSCoder) { coder.encode(accessoryDiscoveryToken, forKey: "accessory") }
}

/// a device the session measures
@objc(NINearbyObject) open class NINearbyObject: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc(NINearbyObjectRemovalReason) public enum RemovalReason: Int, @unchecked Sendable { case timeout = 0, peerEnded = 1 }
    public enum VerticalDirectionEstimate: Int, @unchecked Sendable { case unknown = 0, same, above, below, aboveOrBelow }
    public static let distanceNotAvailable: Float = -1
    public static let directionNotAvailable = simd_float3(repeating: .nan)
    public let discoveryToken: NIDiscoveryToken
    public let distance: Float?
    public let direction: simd_float3?
    public let verticalDirectionEstimate: VerticalDirectionEstimate
    public let horizontalAngle: Float?
    init(token: NIDiscoveryToken) {
        discoveryToken = token; distance = nil; direction = nil; verticalDirectionEstimate = .unknown; horizontalAngle = nil
    }
    public static var supportsSecureCoding: Bool { true }
    public required convenience init?(coder: NSCoder) {
        guard let t = coder.decodeObject(of: NIDiscoveryToken.self, forKey: "token") else { return nil }
        self.init(token: t)
    }
    public func encode(with coder: NSCoder) { coder.encode(discoveryToken, forKey: "token") }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}

@objc(NISessionDelegate) public protocol NISessionDelegate: NSObjectProtocol {
    @objc(session:didUpdateNearbyObjects:) optional func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject])
    @objc(session:didRemoveNearbyObjects:withReason:)
    optional func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason)
    @objc optional func sessionWasSuspended(_ session: NISession)
    @objc optional func sessionSuspensionEnded(_ session: NISession)
    @objc(session:didInvalidateWithError:) optional func session(_ session: NISession, didInvalidateWith error: Error)
    @objc(session:didGenerateShareableConfigurationData:forObject:)
    optional func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject)
}

/// a ranging session; isim has no Ultra Wideband, so a session that runs is invalidated (like the Simulator)
@objc(NISession) open class NISession: NSObject, @unchecked Sendable {
    @available(iOS, deprecated: 16.0, message: "Use deviceCapabilities")
    open class var isSupported: Bool { false }
    open class var deviceCapabilities: NIDeviceCapability { _NINoCapability() }
    open weak var delegate: NISessionDelegate?
    open var delegateQueue: DispatchQueue?
    open var discoveryToken: NIDiscoveryToken? { nil }
    open private(set) var configuration: NIConfiguration?
    private var invalidated = false
    public override init() { super.init() }
    open func run(_ configuration: NIConfiguration) {
        self.configuration = configuration
        guard !invalidated else { return }
        invalidated = true
        NSLog("isim NearbyInteraction: Ultra Wideband is not available on this device (like the Simulator)")
        (delegateQueue ?? .main).async { self.delegate?.session?(self, didInvalidateWith: NIError(.unsupportedPlatform)) }
    }
    open func pause() {}
    open func invalidate() { invalidated = true }
}
