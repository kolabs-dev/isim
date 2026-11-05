// isim AVFoundation (issue #856): the members of AudioToolbox's Audio Unit version 3 classes that take AVFAudio and
// UIKit types. isim's AudioToolbox sits below AVFoundation and UIKit, so they are this extension's: Swift code sees
// them once it imports AVFoundation (as it must to make an AVAudioFormat), and Objective-C as the classes' methods.
import Foundation
import AudioToolbox
import UIKit

extension AUAudioUnitBus {
    @objc(initWithFormat:error:) public convenience init(format: AVAudioFormat) throws {
        let d = format.streamDescription.pointee
        guard d.mFormatID == kAudioFormatLinearPCM, d.mSampleRate > 0, d.mChannelsPerFrame > 0 else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        self.init(_streamDescription: d, formatObject: format)
    }
    @objc public var format: AVAudioFormat {
        if let f = _formatObject as? AVAudioFormat { return f }
        var d = _asbd
        let f = AVAudioFormat(streamDescription: &d) ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _formatObject = f
        return f
    }
    @objc(setFormat:error:) public func setFormat(_ format: AVAudioFormat) throws {
        try _setStreamDescription(format.streamDescription.pointee, formatObject: format)
    }
}

extension AUAudioUnit {
    /// Whether the unit takes a format on a bus; a subclass may override it (isim's units take any linear PCM format).
    @objc(shouldChangeToFormat:forBus:) open func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool { true }
    /// isim's audio units have no user interface: the handler gets nil, on the main queue.
    @objc(requestViewControllerWithCompletionHandler:) open func requestViewController(completionHandler: @escaping (UIViewController?) -> Void) {
        DispatchQueue.main.async { completionHandler(nil) }
    }
}

extension AVAudioUnit {
    /// The node's Audio Unit as version 3 (an AUAudioUnitV2Bridge over `audioUnit`).
    @objc public var auAudioUnit: AUAudioUnit {
        if let a = objc_getAssociatedObject(self, &_auAudioUnitKey) as? AUAudioUnit { return a }
        let a = AUAudioUnit._bridge(audioUnit)
        objc_setAssociatedObject(self, &_auAudioUnitKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return a
    }
}
nonisolated(unsafe) private var _auAudioUnitKey: UInt8 = 0
