// isim NearbyInteraction for Objective-C (sdk-src/Frameworks/NearbyInteraction): Apple's selectors for the overlay's
// classes. NINearbyObject's direction (a simd vector) is Swift-only.
import Foundation

extension NISession {
    @objc(isSupported) class var _objc_isSupported: Bool { false }
    @objc(deviceCapabilities) class var _objc_deviceCapabilities: NIDeviceCapability { deviceCapabilities }
    @objc(delegate) var _objc_delegate: NISessionDelegate? { get { delegate } set { delegate = newValue } }
    @objc(discoveryToken) var _objc_discoveryToken: NIDiscoveryToken? { discoveryToken }
    @objc(configuration) var _objc_configuration: NIConfiguration? { configuration }
    @objc(runWithConfiguration:) func _objc_run(_ c: NIConfiguration) { run(c) }
    @objc(pause) func _objc_pause() { pause() }
    @objc(invalidate) func _objc_invalidate() { invalidate() }
}
extension NINearbyPeerConfiguration {
    @objc(initWithPeerToken:) convenience init(_objcPeerToken t: NIDiscoveryToken) { self.init(peerToken: t) }
    @objc(peerDiscoveryToken) var _objc_peerDiscoveryToken: NIDiscoveryToken { peerDiscoveryToken }
    @objc(isCameraAssistanceEnabled) var _objc_camera: Bool { get { isCameraAssistanceEnabled } set { isCameraAssistanceEnabled = newValue } }
    @objc(isExtendedDistanceMeasurementEnabled) var _objc_extended: Bool {
        get { isExtendedDistanceMeasurementEnabled } set { isExtendedDistanceMeasurementEnabled = newValue }
    }
}
extension NINearbyAccessoryConfiguration {
    @objc(initWithData:error:) convenience init(_objcData data: Data) throws { try self.init(data: data) }
    @objc(accessoryDiscoveryToken) var _objc_accessoryDiscoveryToken: NIDiscoveryToken { accessoryDiscoveryToken }
}
extension NINearbyObject {
    @objc(discoveryToken) var _objc_discoveryToken: NIDiscoveryToken { discoveryToken }
    @objc(distance) var _objc_distance: Float { distance ?? NINearbyObject.distanceNotAvailable }
    @objc(horizontalAngle) var _objc_horizontalAngle: Float { horizontalAngle ?? .nan }
    @objc(verticalDirectionEstimate) var _objc_verticalDirectionEstimate: Int { verticalDirectionEstimate.rawValue }
}
