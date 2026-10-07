#pragma once
#import <XCTest/XCTestRun.h>

NS_ASSUME_NONNULL_BEGIN

@class XCTestSuite;

@protocol XCTestObservation <NSObject>
@optional
- (void)testBundleWillStart:(NSBundle *)testBundle;
- (void)testBundleDidFinish:(NSBundle *)testBundle;
- (void)testSuiteWillStart:(XCTestSuite *)testSuite;
- (void)testSuiteDidFinish:(XCTestSuite *)testSuite;
- (void)testCaseWillStart:(XCTestCase *)testCase;
- (void)testCase:(XCTestCase *)testCase didFailWithDescription:(NSString *)description inFile:(nullable NSString *)filePath atLine:(NSUInteger)lineNumber;
- (void)testCaseDidFinish:(XCTestCase *)testCase;
@end

@interface XCTestObservationCenter : NSObject
@property (class, readonly, strong) XCTestObservationCenter *sharedTestObservationCenter;
- (void)addTestObserver:(id<XCTestObservation>)testObserver;
- (void)removeTestObserver:(id<XCTestObservation>)testObserver;
@end

/* isim runner entry points (used by `isim test`; not Apple API) */
XCT_EXPORT int XCTIsimRunTestBundle(const char *bundlePath) NS_SWIFT_UNAVAILABLE("isim runner");
XCT_EXPORT XCTestCase *_Nullable _XCTCurrentTestCase(void) NS_SWIFT_NAME(_XCTCurrentTestCase());
XCT_EXPORT void _XCTIsimRecordFailure(NSString *description, NSString *_Nullable filePath, NSUInteger line, BOOL expected);
XCT_EXPORT void _XCTIsimRecordSkip(NSString *_Nullable message, NSString *_Nullable filePath, NSUInteger line);
XCT_EXPORT void _XCTIsimRecordMeasurement(NSArray<NSNumber *> *values, NSString *filePath, NSUInteger line);

NS_ASSUME_NONNULL_END
