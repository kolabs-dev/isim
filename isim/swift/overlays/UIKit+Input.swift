// isim UIKit overlay, input part (self-authored): Swift-only API shapes from Apple's UIKit overlay for pointers.

// MARK: - Pointer effects and shapes (enums in Swift, classes in Objective-C)
public enum UIPointerEffect {
    public typealias TintMode = __UIPointerEffectTintMode
    case automatic(UITargetedPreview)
    case highlight(UITargetedPreview)
    case lift(UITargetedPreview)
    case hover(UITargetedPreview, preferredTintMode: TintMode = .overlay, prefersShadow: Bool = false, prefersScaledContent: Bool = true)
    public var preview: UITargetedPreview {
        switch self { case .automatic(let p), .highlight(let p), .lift(let p), .hover(let p, _, _, _): return p }
    }
    var _objc: __UIPointerEffect {
        switch self {
        case .automatic(let p), .highlight(let p): return __UIPointerHighlightEffect(preview: p)
        case .lift(let p): return __UIPointerLiftEffect(preview: p)
        case .hover(let p, let tint, let shadow, let scaled):
            let e = __UIPointerHoverEffect(preview: p)
            e.preferredTintMode = tint; e.prefersShadow = shadow; e.prefersScaledContent = scaled
            return e
        }
    }
}
public enum UIPointerShape {
    public static let defaultCornerRadius: CGFloat = 8
    case path(UIBezierPath)
    case roundedRect(CGRect, radius: CGFloat = UIPointerShape.defaultCornerRadius)
    case verticalBeam(length: CGFloat)
    case horizontalBeam(length: CGFloat)
    var _objc: __UIPointerShape {
        switch self {
        case .path(let p): return __UIPointerShape(path: p)
        case .roundedRect(let r, let radius): return __UIPointerShape(roundedRect: r, cornerRadius: radius)
        case .verticalBeam(let l): return __UIPointerShape.beam(withPreferredLength: l, axis: .vertical)
        case .horizontalBeam(let l): return __UIPointerShape.beam(withPreferredLength: l, axis: .horizontal)
        }
    }
}
extension UIPointerAccessory {
    public typealias Position = UIPointerAccessoryPosition
    /// an arrow pointing away from the pointer at that position
    public static func arrow(_ position: Position) -> UIPointerAccessory { __arrowAccessory(with: position) }
}
extension UIPointerAccessoryPosition {
    public static var top: Self { UIPointerAccessoryPositionTop }
    public static var topRight: Self { UIPointerAccessoryPositionTopRight }
    public static var right: Self { UIPointerAccessoryPositionRight }
    public static var bottomRight: Self { UIPointerAccessoryPositionBottomRight }
    public static var bottom: Self { UIPointerAccessoryPositionBottom }
    public static var bottomLeft: Self { UIPointerAccessoryPositionBottomLeft }
    public static var left: Self { UIPointerAccessoryPositionLeft }
    public static var topLeft: Self { UIPointerAccessoryPositionTopLeft }
}
// MARK: - UIAccessibility (a namespace in Swift)
public enum UIAccessibility {
    public struct Notification: Hashable, RawRepresentable, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let screenChanged = Notification(rawValue: UIAccessibilityScreenChangedNotification)
        public static let layoutChanged = Notification(rawValue: UIAccessibilityLayoutChangedNotification)
        public static let announcement = Notification(rawValue: UIAccessibilityAnnouncementNotification)
        public static let pageScrolled = Notification(rawValue: UIAccessibilityPageScrolledNotification)
        public static let pauseAssistiveTechnology = Notification(rawValue: UIAccessibilityPauseAssistiveTechnologyNotification)
        public static let resumeAssistiveTechnology = Notification(rawValue: UIAccessibilityResumeAssistiveTechnologyNotification)
    }
    @MainActor public static func post(notification: Notification, argument: Any?) { UIAccessibilityPostNotification(notification.rawValue, argument) }
    public static var isVoiceOverRunning: Bool { UIAccessibilityIsVoiceOverRunning() }
    public static var isReduceMotionEnabled: Bool { UIAccessibilityIsReduceMotionEnabled() }
    public static var isBoldTextEnabled: Bool { UIAccessibilityIsBoldTextEnabled() }
    public static var isReduceTransparencyEnabled: Bool { UIAccessibilityIsReduceTransparencyEnabled() }
    public static var isDarkerSystemColorsEnabled: Bool { UIAccessibilityIsDarkerSystemColorsEnabled() }
    public static var shouldDifferentiateWithoutColor: Bool { UIAccessibilityShouldDifferentiateWithoutColor() }
    public static var isInvertColorsEnabled: Bool { UIAccessibilityIsInvertColorsEnabled() }
    public static var isGrayscaleEnabled: Bool { UIAccessibilityIsGrayscaleEnabled() }
    public static var isSwitchControlRunning: Bool { UIAccessibilityIsSwitchControlRunning() }
    public static var isClosedCaptioningEnabled: Bool { UIAccessibilityIsClosedCaptioningEnabled() }
    public static var isOnOffSwitchLabelsEnabled: Bool { UIAccessibilityIsOnOffSwitchLabelsEnabled() }
    public static var buttonShapesEnabled: Bool { UIAccessibilityButtonShapesEnabled() }
    public static var prefersCrossFadeTransitions: Bool { UIAccessibilityPrefersCrossFadeTransitions() }
    public static var isVideoAutoplayEnabled: Bool { UIAccessibilityIsVideoAutoplayEnabled() }
    public static let voiceOverStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityVoiceOverStatusDidChangeNotification")
    public static let switchControlStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilitySwitchControlStatusDidChangeNotification")
    public static let reduceMotionStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityReduceMotionStatusDidChangeNotification")
    public static let boldTextStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityBoldTextStatusDidChangeNotification")
    public static let reduceTransparencyStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityReduceTransparencyStatusDidChangeNotification")
    public static let darkerSystemColorsStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityDarkerSystemColorsStatusDidChangeNotification")
    public static let differentiateWithoutColorDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityDifferentiateWithoutColorDidChangeNotification")
    public static let announcementDidFinishNotification = NSNotification.Name(rawValue: "UIAccessibilityAnnouncementDidFinishNotification")
    public static let elementFocusedNotification = NSNotification.Name(rawValue: "UIAccessibilityElementFocusedNotification")
    public static let announcementStringValueUserInfoKey = "UIAccessibilityAnnouncementKeyStringValue"
    public static let announcementWasSuccessfulUserInfoKey = "UIAccessibilityAnnouncementKeyWasSuccessful"
    public static let focusedElementUserInfoKey = "UIAccessibilityFocusedElementKey"
    public static let unfocusedElementUserInfoKey = "UIAccessibilityUnfocusedElementKey"
    public static let assistiveTechnologyUserInfoKey = "UIAccessibilityAssistiveTechnologyKey"
    // the further Settings > Accessibility values and their notifications
    public static var isGuidedAccessEnabled: Bool { UIAccessibilityIsGuidedAccessEnabled() }
    public static var isMonoAudioEnabled: Bool { UIAccessibilityIsMonoAudioEnabled() }
    public static var isSpeakScreenEnabled: Bool { UIAccessibilityIsSpeakScreenEnabled() }
    public static var isSpeakSelectionEnabled: Bool { UIAccessibilityIsSpeakSelectionEnabled() }
    public static var isAssistiveTouchRunning: Bool { UIAccessibilityIsAssistiveTouchRunning() }
    public static var isShakeToUndoEnabled: Bool { UIAccessibilityIsShakeToUndoEnabled() }
    public static var hearingDevicePairedEar: HearingDeviceEar { UIAccessibilityHearingDevicePairedEar() }
    public static let guidedAccessStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityGuidedAccessStatusDidChangeNotification")
    public static let monoAudioStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityMonoAudioStatusDidChangeNotification")
    public static let speakScreenStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilitySpeakScreenStatusDidChangeNotification")
    public static let speakSelectionStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilitySpeakSelectionStatusDidChangeNotification")
    public static let assistiveTouchStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityAssistiveTouchStatusDidChangeNotification")
    public static let shakeToUndoDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityShakeToUndoDidChangeNotification")
    public static let hearingDevicePairedEarDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityHearingDevicePairedEarDidChangeNotification")
    public static let closedCaptioningStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityClosedCaptioningStatusDidChangeNotification")
    public static let grayscaleStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityGrayscaleStatusDidChangeNotification")
    public static let invertColorsStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityInvertColorsStatusDidChangeNotification")
    public static let videoAutoplayStatusDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityVideoAutoplayStatusDidChangeNotification")
    public static let prefersCrossFadeTransitionsStatusDidChange = NSNotification.Name(rawValue: "UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification")
    public static let onOffSwitchLabelsDidChangeNotification = NSNotification.Name(rawValue: "UIAccessibilityOnOffSwitchLabelsDidChangeNotification")
    public typealias AssistiveTechnologyIdentifier = UIAccessibilityAssistiveTechnologyIdentifier
    public typealias HearingDeviceEar = UIAccessibilityHearingDeviceEar
    public typealias ZoomType = UIAccessibilityZoomType
    @available(iOS 13.0, *) public typealias TextualContext = UIAccessibilityTextualContext
    public typealias GuidedAccessRestrictionState = UIGuidedAccessRestrictionState
    // isim's error enums are plain enums: this is the Swift error type of their codes (an NSError from
    // configureForGuidedAccess has this domain and a Code raw value)
    @available(iOS 12.2, *) public struct GuidedAccessError: CustomNSError, Hashable {
        public typealias Code = UIGuidedAccessErrorCode
        public let code: Code
        public init(_ code: Code) { self.code = code }
        public static var errorDomain: String { UIGuidedAccessErrorDomain }
        public var errorCode: Int { code.rawValue }
        public static var permissionDenied: Code { .permissionDenied }
        public static var failed: Code { .failed }
    }
    @available(iOS 12.2, *) public static var guidedAccessErrorDomain: String { UIGuidedAccessErrorDomain }
    @available(iOS 18.0, *) public typealias ExpandedStatus = UIAccessibilityExpandedStatus
    @available(iOS 17.0, *) public typealias DirectTouchOptions = UIAccessibilityDirectTouchOptions
    @MainActor public static func focusedElement(using assistiveTechnologyIdentifier: AssistiveTechnologyIdentifier?) -> Any? {
        UIAccessibilityFocusedElement(assistiveTechnologyIdentifier)
    }
    @MainActor public static func convertToScreenCoordinates(_ rect: CGRect, in view: UIView) -> CGRect { UIAccessibilityConvertFrameToScreenCoordinates(rect, view) }
    @MainActor public static func convertToScreenCoordinates(_ path: UIBezierPath, in view: UIView) -> UIBezierPath { UIAccessibilityConvertPathToScreenCoordinates(path, view) }
    @MainActor public static func zoomFocusChanged(_ type: ZoomType, frame: CGRect, in view: UIView) { UIAccessibilityZoomFocusChanged(type, frame, view) }
    @MainActor public static func registerGestureConflictWithZoom() { UIAccessibilityRegisterGestureConflictWithZoom() }
    @MainActor public static func guidedAccessRestrictionState(forIdentifier restrictionIdentifier: String) -> GuidedAccessRestrictionState {
        UIGuidedAccessRestrictionStateForIdentifier(restrictionIdentifier)
    }
    @MainActor public static func requestGuidedAccessSession(enabled enable: Bool, completionHandler: @escaping (Bool) -> Void) {
        UIAccessibilityRequestGuidedAccessSession(enable, completionHandler)
    }
    @available(iOS 12.2, *) @MainActor public static func configureForGuidedAccess(features: UIGuidedAccessAccessibilityFeature, enabled: Bool,
                                                           completionHandler: @escaping (Bool, Error?) -> Void) {
        UIGuidedAccessConfigureAccessibilityFeatures(features, enabled, completionHandler)
    }
}

// UIAccessibilityTraits is an option set in Swift ([.button, .selected], insert, contains)
extension UIAccessibilityTraits: OptionSet {}

// MARK: - Dynamic Type
extension UIContentSizeCategory: Comparable {
    public var isAccessibilityCategory: Bool { __UIContentSizeCategoryIsAccessibilityCategory(self) }
    public static func < (a: UIContentSizeCategory, b: UIContentSizeCategory) -> Bool { __UIContentSizeCategoryCompareToCategory(a, b) == .orderedAscending }
    public static let didChangeNotification = NSNotification.Name(rawValue: "UIContentSizeCategoryDidChangeNotification")
    public static let newValueUserInfoKey = "UIContentSizeCategoryNewValueKey"
}

extension UIPointerStyle {
    public convenience init(effect: UIPointerEffect, shape: UIPointerShape? = nil) { self.init(__effect: effect._objc, shape: shape?._objc) }
    public convenience init(shape: UIPointerShape, constrainedAxes axes: UIAxis = []) { self.init(__shape: shape._objc, constrainedAxes: axes) }
}
