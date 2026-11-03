// isim AVKit for Objective-C (issue #811): capture events. The classes carry Apple's Objective-C names (OBJC_NAMES in
// buildlib/swift.py) and these members Apple's selectors; the interaction is a UIInteraction already (addInteraction:).
import UIKit

extension AVCaptureEvent {
    @objc(phase) var _objc_phase: Int { Int(phase.rawValue) }
    @available(iOS 26.0, *) @objc(shouldPlaySound) var _objc_shouldPlay: Bool { shouldPlaySound }
    @available(iOS 26.0, *) @objc(playSound:) func _objc_play(_ s: AVCaptureEventSound) -> Bool { play(s) }
}
@available(iOS 26.0, *)
extension AVCaptureEventSound {
    @objc(initWithURL:error:) convenience init(_objcURL url: URL) throws { try self.init(url: url) }
    @objc(cameraShutterSound) class var _objc_shutter: AVCaptureEventSound { cameraShutter }
    @objc(beginVideoRecordingSound) class var _objc_begin: AVCaptureEventSound { beginVideoRecording }
    @objc(endVideoRecordingSound) class var _objc_end: AVCaptureEventSound { endVideoRecording }
}
extension AVCaptureEventInteraction {
    @objc(initWithEventHandler:) convenience init(_objcHandler h: @escaping (AVCaptureEvent) -> Void) { self.init(handler: h) }
    @objc(initWithPrimaryEventHandler:secondaryEventHandler:) convenience init(_objcPrimary p: @escaping (AVCaptureEvent) -> Void,
                                                                               secondary s: @escaping (AVCaptureEvent) -> Void) {
        self.init(primary: p, secondary: s)
    }
    @objc(isEnabled) var _objc_isEnabled: Bool { isEnabled }
    @objc(setEnabled:) func _objc_setEnabled(_ b: Bool) { isEnabled = b }
    @available(iOS 26.0, *) @objc(defaultCaptureSoundDisabled) class var _objc_soundDisabled: Bool { defaultCaptureSoundDisabled }
    @available(iOS 26.0, *) @objc(setDefaultCaptureSoundDisabled:) class func _objc_setSoundDisabled(_ b: Bool) { defaultCaptureSoundDisabled = b }
}
