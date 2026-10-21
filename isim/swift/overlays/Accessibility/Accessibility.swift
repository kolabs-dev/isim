// isim Accessibility Swift overlay (issue #325): AccessibilityNotification, posted through UIKit's UIAccessibility.post
// (isim's VoiceOver speaks announcements and page scrolls, and moves its focus on layout and screen changes), and
// AccessibilitySettings, the device's Settings > Accessibility values (frameworks/Accessibility/AXSettings.m; the
// `accessibility` script command changes them). The Objective-C module (AXCustomContent, AXSettings.h) is re-exported.
@_exported import Accessibility
import Foundation
import UIKit

@_silgen_name("isim_ax_setting") func _axSetting(_ key: NSString) -> Bool          // AXSettings.m

@available(iOS 17.0, *)
public enum AccessibilityNotification {
    public struct Announcement {
        let argument: Any
        public init(_ announcement: String) { argument = announcement }
        public init(_ announcement: NSAttributedString) { argument = announcement }
        public init(_ announcement: AttributedString) { argument = NSAttributedString(announcement) }
        @MainActor public func post() { UIAccessibility.post(notification: .announcement, argument: argument) }
    }
    public struct LayoutChanged {
        let argument: Any?
        public init(_ argument: Any? = nil) { self.argument = argument }
        @MainActor public func post() { UIAccessibility.post(notification: .layoutChanged, argument: argument) }
    }
    public struct ScreenChanged {
        let argument: Any?
        public init(_ argument: Any? = nil) { self.argument = argument }
        @MainActor public func post() { UIAccessibility.post(notification: .screenChanged, argument: argument) }
    }
    public struct PageScrolled {
        let argument: Any
        public init(_ status: String) { argument = status }
        public init(_ status: NSAttributedString) { argument = status }
        public init(_ status: AttributedString) { argument = NSAttributedString(status) }
        @MainActor public func post() { UIAccessibility.post(notification: .pageScrolled, argument: argument) }
    }
}

@available(iOS 14.0, *)
public struct AccessibilitySettings: Sendable {
    public init() {}

    /// Settings > Accessibility > Motion > Auto-Play Animated Images (on by default)
    @available(iOS 18.0, *) public static var animatedImagesEnabled: Bool { AXAnimatedImagesEnabled() }
    @available(iOS 18.0, *) public static var animatedImagesEnabledDidChangeNotification: Notification.Name {
        .AXAnimatedImagesEnabledDidChange
    }
    @available(iOS 18.0, *) public static var prefersHorizontalTextLayout: Bool { AXPrefersHorizontalTextLayout() }
    @available(iOS 18.0, *) public static var prefersHorizontalTextLayoutDidChangeNotification: Notification.Name {
        .AXPrefersHorizontalTextLayoutDidChange
    }
    /// visionOS's head-anchored content: never on an iPhone or iPad
    public static var prefersHeadAnchorAlternative: Bool { false }
    public static var prefersHeadAnchorAlternativeDidChangeNotification: Notification.Name {
        Notification.Name("AXPrefersHeadAnchorAlternativeDidChangeNotification")
    }
    /// Settings > Accessibility > Motion > Prefer Non-Blinking Cursor
    @available(iOS 18.0, *) public static var prefersNonBlinkingTextInsertionIndicator: Bool { _axSetting("ISIMNonBlinkingCursor") }
    @available(iOS 18.0, *) public static let prefersNonBlinkingTextInsertionIndicatorDidChangeNotification =
        NSNotification.Name("AXPrefersNonBlinkingTextInsertionIndicatorDidChangeNotification")
    /// Assistive Access (a simplified iOS for people with cognitive disabilities): isim has none, unless set for a test
    @available(iOS 18.0, *) public static var isAssistiveAccessEnabled: Bool { _axSetting("ISIMAssistiveAccess") }
    /// whether an assistive technology (VoiceOver, Switch Control) is using the app
    @available(iOS 27.0, *) public static var isApplicationAccessibilityEnabled: Bool {
        MainActor.assumeIsolated { UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning }
    }
    @available(iOS 27.0, *) public static let applicationAccessibilityEnabledDidChangeNotification =
        NSNotification.Name("AXApplicationAccessibilityEnabledDidChangeNotification")
    @available(iOS 27.0, *) public struct ApplicationAccessibilityEnabledDidChangeMessage: Sendable { public init() {} }
    @available(iOS 26.4, *) public static var isReduceHighlightingEffectsEnabled: Bool { _axSetting("ISIMReduceHighlightingEffects") }
    @available(iOS 26.4, *) public static let reduceHighlightingEffectsEnabledDidChangeNotification =
        NSNotification.Name("AXReduceHighlightingEffectsEnabledDidChangeNotification")
    @available(iOS 26.1, *) public static var prefersActionSliderAlternative: Bool { _axSetting("ISIMPrefersActionSlider") }
    @available(iOS 26.1, *) public static let prefersActionSliderAlternativeDidChangeNotification =
        NSNotification.Name("AXPrefersActionSliderAlternativeDidChangeNotification")
    /// Settings > Accessibility > Display & Text Size > Show Borders
    @available(iOS 26.1, *) public static var showBordersEnabled: Bool { _axSetting("ISIMShowBorders") }
    @available(iOS 26.1, *) public static let showBordersEnabledStatusDidChangeNotification =
        NSNotification.Name("AXShowBordersEnabledStatusDidChangeNotification")

    /// the Settings pages openSettings(for:) opens (isim: Settings > Accessibility for each)
    @available(iOS 18.0, *) public enum Feature: Int, Sendable {
        case personalVoiceAllowAppsToRequestToUse = 1
        @available(iOS 18.2, *) case allowAppsToAddAudioToCalls = 2
        @available(iOS 26.0, *) case assistiveTouch = 3
        @available(iOS 26.0, *) case assistiveTouchDevices = 4
        @available(iOS 26.0, *) case dwellControl = 5
        @available(iOS 26.4, *) case captionStyles = 6
    }
    @available(iOS 18.0, *) public static func openSettings(for feature: Feature) async throws {
        let opened = await MainActor.run {
            NSLog("isim Accessibility: open Settings for %@", "\(feature)")
            return UIApplication.shared.canOpenURL(URL(string: "app-settings:accessibility")!)
        }
        if opened { _ = await UIApplication.shared.open(URL(string: "app-settings:accessibility")!) }
        else { throw CocoaError(.featureUnsupported) }
    }
    @available(iOS 26.4, *) public static func canOpenSettings(for feature: Feature) -> Bool { true }
}
