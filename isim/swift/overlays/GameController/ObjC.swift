// isim GameController: the Objective-C interface (sdk-src/Frameworks/GameController, issue #548). The classes are
// @objc(GC…) and @objcMembers, so what Objective-C can represent is exported under Apple's names; the members below are
// internal Objective-C entry points, under Apple's selectors, for what uses Swift-only types (GCKeyCode, the player
// index and haptic localities, the GCDevice protocol). GCMotion's C structs are in frameworks/GameController.
import UIKit

extension GCController {
    /// GCControllerPlayerIndex's raw value
    @objc(playerIndex) var _objcPlayerIndex: Int {
        get { playerIndex.rawValue }
        set { playerIndex = GCControllerPlayerIndex(rawValue: newValue) ?? .indexUnset }
    }
}
extension GCPhysicalInputProfile {
    /// id<GCDevice>: the controller, keyboard or mouse
    @objc(device) var _objcDevice: NSObject? { device as? NSObject }
}
extension GCKeyboardInput {
    /// the key code as GCKeyCode's raw value (a CFIndex in Objective-C)
    @objc(keyChangedHandler) var _objcKeyChangedHandler: ((GCKeyboardInput, GCControllerButtonInput, Int, Bool) -> Void)? {
        get { keyChangedHandler.map { h in { h($0, $1, GCKeyCode(rawValue: $2), $3) } } }
        set { keyChangedHandler = newValue.map { h in { h($0, $1, $2.rawValue, $3) } } }
    }
    @objc(buttonForKeyCode:) func _objcButton(forKeyCode code: Int) -> GCControllerButtonInput? { button(forKeyCode: GCKeyCode(rawValue: code)) }
}
extension GCDeviceHaptics {
    @objc(supportedLocalities) var _objcSupportedLocalities: Set<String> { Set(supportedLocalities.map(\.rawValue)) }
    @objc(createEngineWithLocality:) func _objcCreateEngine(withLocality locality: String) -> CHHapticEngine? {
        createEngine(withLocality: GCHapticsLocality(rawValue: locality))
    }
}
extension GCVirtualController.Configuration {
    @objc(isHidden) var _objcHidden: Bool {
        get { isHidden }
        @objc(setHidden:) set { isHidden = newValue }
    }
}
extension GCVirtualController.ElementConfiguration {
    @objc(isHidden) var _objcHidden: Bool {
        get { isHidden }
        @objc(setHidden:) set { isHidden = newValue }
    }
}
extension GCMotion {
    @objc(areSensorsActive) var _objcSensorsActive: Bool {
        get { sensorsActive }
        @objc(setSensorsActive:) set { sensorsActive = newValue }
    }
    /// gravity, user acceleration, acceleration (x y z each), rotation rate (x y z), attitude (x y z w): Objective-C's structs
    @objc(_isim_values) var _objcValues: [Double] {
        [gravity.x, gravity.y, gravity.z, userAcceleration.x, userAcceleration.y, userAcceleration.z, acceleration.x, acceleration.y, acceleration.z,
         rotationRate.x, rotationRate.y, rotationRate.z, attitude.x, attitude.y, attitude.z, attitude.w]
    }
}
