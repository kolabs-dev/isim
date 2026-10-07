#pragma once
#import <XCTest/XCTestDefines.h>

NS_ASSUME_NONNULL_BEGIN

/* The base class of tests (XCTestCase) and test suites (XCTestSuite). */
@interface XCTest : NSObject
@property (readonly) NSUInteger testCaseCount;
@property (readonly, copy) NSString *name;
@property (readonly, nullable) Class testRunClass;
@property (readonly, strong, nullable) XCTestRun *testRun;
- (void)performTest:(XCTestRun *)run;
- (void)runTest;
- (BOOL)setUpWithError:(NSError **)error;
- (void)setUp;
- (void)tearDown;
- (BOOL)tearDownWithError:(NSError **)error;
@end

/* What happened when a test ran: counts, timing, success. */
@interface XCTestRun : NSObject
+ (instancetype)testRunWithTest:(XCTest *)test;
- (instancetype)initWithTest:(XCTest *)test;
@property (readonly, strong) XCTest *test;
- (void)start;
- (void)stop;
@property (readonly, nullable, copy) NSDate *startDate;
@property (readonly, nullable, copy) NSDate *stopDate;
@property (readonly) NSTimeInterval totalDuration;
@property (readonly) NSTimeInterval testDuration;
@property (readonly) NSUInteger testCaseCount;
@property (readonly) NSUInteger executionCount;
@property (readonly) NSUInteger skipCount;
@property (readonly) NSUInteger failureCount;
@property (readonly) NSUInteger unexpectedExceptionCount;
@property (readonly) NSUInteger totalFailureCount;
@property (readonly) BOOL hasSucceeded;
@property (readonly) BOOL hasBeenSkipped;
@end

@interface XCTestCaseRun : XCTestRun
- (void)recordFailureWithDescription:(NSString *)description inFile:(nullable NSString *)filePath atLine:(NSUInteger)lineNumber expected:(BOOL)expected;
@end

@interface XCTestSuiteRun : XCTestRun
@property (readonly, copy) NSArray<XCTestRun *> *testRuns;
- (void)addTestRun:(XCTestRun *)testRun;
@end

NS_ASSUME_NONNULL_END
