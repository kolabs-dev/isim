#pragma once
#import <Foundation/Foundation.h>

#define XCT_EXPORT extern __attribute__((visibility("default")))
#ifndef NS_SWIFT_ASYNC_NAME
#define NS_SWIFT_ASYNC_NAME(_name) __attribute__((swift_async_name(#_name)))
#endif
#ifndef NS_SWIFT_DISABLE_ASYNC
#define NS_SWIFT_DISABLE_ASYNC __attribute__((swift_async(none)))
#endif
#ifndef NS_SWIFT_UI_ACTOR
#define NS_SWIFT_UI_ACTOR __attribute__((swift_attr("@UIActor")))
#endif
#ifndef NS_SWIFT_NONISOLATED
#define NS_SWIFT_NONISOLATED __attribute__((swift_attr("nonisolated")))
#endif

@class XCTestCase, XCTestRun, XCTestSuite, XCTestExpectation;

NS_ASSUME_NONNULL_BEGIN
typedef void (^XCWaitCompletionHandler)(NSError *_Nullable error);
typedef BOOL (^XCNotificationExpectationHandler)(NSNotification *notification);
typedef BOOL (^XCPredicateExpectationHandler)(void);
NS_ASSUME_NONNULL_END
