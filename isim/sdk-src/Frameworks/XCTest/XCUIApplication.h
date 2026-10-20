#pragma once
#import <XCTest/XCUIElement.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, XCUIApplicationState) {
    XCUIApplicationStateUnknown = 0,
    XCUIApplicationStateNotRunning = 1,
    XCUIApplicationStateRunningBackgroundSuspended = 2,
    XCUIApplicationStateRunningBackground = 3,
    XCUIApplicationStateRunningForeground = 4,
} NS_SWIFT_NAME(XCUIApplication.State);

/* What a privacy prompt protects (resetAuthorizationStatus(for:)). */
typedef NS_ENUM(NSInteger, XCUIProtectedResource) {
    XCUIProtectedResourceContacts = 1,
    XCUIProtectedResourceCalendar = 2,
    XCUIProtectedResourceReminders = 3,
    XCUIProtectedResourcePhotos = 4,
    XCUIProtectedResourceMicrophone = 5,
    XCUIProtectedResourceCamera = 6,
    XCUIProtectedResourceMediaLibrary = 7,
    XCUIProtectedResourceHomeKit = 8,
    XCUIProtectedResourceBluetooth = -0x40000000,
    XCUIProtectedResourceKeyboardNetwork = -0x40000001,
    XCUIProtectedResourceLocation = -0x40000002,
    XCUIProtectedResourceHealth = -0x40000003,
};

/* The application under test. isim: launch() starts the app (the UI-test target's TEST_TARGET_NAME app, or the
 * bundle identifier given) as its own simulator process with the launch arguments and environment, and
 * drives it through isim's control channel. */
@interface XCUIApplication : XCUIElement
- (instancetype)init;
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier;
@property (readonly, copy) NSString *bundleIdentifier;
@property (copy) NSArray<NSString *> *launchArguments;
@property (copy) NSDictionary<NSString *, NSString *> *launchEnvironment;
@property (readonly) XCUIApplicationState state;
- (void)launch;
- (void)activate;
- (void)terminate;
- (BOOL)waitForState:(XCUIApplicationState)state timeout:(NSTimeInterval)timeout NS_SWIFT_NAME(wait(for:timeout:));
/* forgets the app's answer to a privacy prompt, so it asks again: like iOS, the app is terminated if it runs; isim
 * (adapted) clears the stored answer when the app is next launched. Bluetooth, HomeKit and keyboard network access
 * keep no answer in isim (nothing to reset). */
- (void)resetAuthorizationStatusForResource:(XCUIProtectedResource)resource NS_SWIFT_NAME(resetAuthorizationStatus(for:));
@end

/* Accessibility audits (iOS 17). isim (adapted): the audit reads the app's accessibility snapshot and reports elements
 * without a description (sufficientElementDescription) and controls smaller than 44 x 44 points (hitRegion); contrast,
 * element detection, Dynamic Type, clipped text and traits are not checked. */
typedef NS_OPTIONS(uint64_t, XCUIAccessibilityAuditType) {
    XCUIAccessibilityAuditTypeContrast = 1UL << 0,
    XCUIAccessibilityAuditTypeElementDetection = 1UL << 1,
    XCUIAccessibilityAuditTypeHitRegion = 1UL << 2,
    XCUIAccessibilityAuditTypeSufficientElementDescription = 1UL << 3,
    XCUIAccessibilityAuditTypeDynamicType = 1UL << 16,
    XCUIAccessibilityAuditTypeTextClipped = 1UL << 17,
    XCUIAccessibilityAuditTypeTrait = 1UL << 18,
    XCUIAccessibilityAuditTypeAll = ~0UL,
} API_AVAILABLE(ios(17.0));

/* One problem an audit found. */
API_AVAILABLE(ios(17.0))
@interface XCUIAccessibilityAuditIssue : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (readonly, nullable) XCUIElement *element;
@property (readonly, copy) NSString *compactDescription;
@property (readonly, copy) NSString *detailedDescription;
@property (readonly) XCUIAccessibilityAuditType auditType;
@end

@interface XCUIApplication (XCUIAccessibilityAudit)
/* every issue goes to the handler; one it does not handle (returns NO, or no handler) fails the test */
- (BOOL)performAccessibilityAuditWithAuditTypes:(XCUIAccessibilityAuditType)auditTypes
                                   issueHandler:(BOOL (NS_NOESCAPE ^_Nullable)(XCUIAccessibilityAuditIssue *issue))issueHandler
                                          error:(NSError **)outError API_AVAILABLE(ios(17.0))
    NS_SWIFT_NAME(__performAccessibilityAudit(with:issueHandler:));
@end

NS_ASSUME_NONNULL_END
