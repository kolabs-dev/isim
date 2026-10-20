#pragma once
#import <XCTest/XCTestCase.h>
NS_ASSUME_NONNULL_BEGIN

/* The context a test runs in. Activities group a test's steps: `isim test` prints each when it starts, nested ones
 * indented (Xcode's console format), and attachments added to one are kept with the test. */
@interface XCTContext : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (void)runActivityNamed:(NSString *)name block:(void (NS_NOESCAPE ^)(id<XCTActivity> activity))block NS_REFINED_FOR_SWIFT;
@end

/* isim: the activity runActivity(named:) runs (used by the Swift overlay) */
XCT_EXPORT id<XCTActivity> _XCTIsimBeginActivity(NSString *name) NS_SWIFT_NAME(_XCTIsimBeginActivity(_:));
XCT_EXPORT void _XCTIsimEndActivity(id<XCTActivity> activity) NS_SWIFT_NAME(_XCTIsimEndActivity(_:));

NS_ASSUME_NONNULL_END
