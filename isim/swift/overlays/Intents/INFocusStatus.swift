// isim Intents Swift overlay: INFocusStatus.isFocused as Bool? (Apple's refined Swift API; the Objective-C property
// is an NSNumber).
@_exported import Intents
import Foundation

extension INFocusStatus {
    /// true while a Focus is on, false when none is; nil without authorization
    public var isFocused: Bool? { __isFocused?.boolValue }
    public convenience init(isFocused: Bool?) { self.init(__isFocused: isFocused.map { NSNumber(value: $0) }) }
}
