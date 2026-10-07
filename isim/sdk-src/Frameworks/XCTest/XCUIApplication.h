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
@end

NS_ASSUME_NONNULL_END
