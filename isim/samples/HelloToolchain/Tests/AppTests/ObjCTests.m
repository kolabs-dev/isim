#import <XCTest/XCTest.h>
#import <MathKit/MKCalculator.h>

/* an Objective-C XCTestCase in the same (mixed) test target */
@interface ObjCTests : XCTestCase
@end

@implementation ObjCTests
- (void)testCalculator {
    XCTAssertEqual([MKCalculator add:20 to:22], 42);
    XCTAssertEqualObjects(@"a", [@"A" lowercaseString]);
    XCTAssertNotNil(NSClassFromString(@"TCScorer"), @"the host app's @objc Swift class is visible to the test bundle");
    XCTAssertNotNil([NSDate date]);
    XCTAssertEqualWithAccuracy(1.0, 1.05, 0.1);
}
- (void)testExceptions {
    XCTAssertThrows([NSException raise:@"Boom" format:@"thrown"]);
    XCTAssertThrowsSpecificNamed([NSException raise:@"Boom" format:@"again"], NSException, @"Boom");
    XCTAssertNoThrow([@[@1] objectAtIndex:0]);
}
- (void)testObjCSkip {
    XCTSkipIf(YES, @"skipped from Objective-C");
    XCTFail(@"not reached");
}
@end

/* deliberately failing (skipped by the scheme): an uncaught NSException is recorded as a failure */
@interface ExpectedObjCFailureTests : XCTestCase
@end
@implementation ExpectedObjCFailureTests
- (void)testUncaughtException {
    [NSException raise:NSInternalInconsistencyException format:@"deliberate %@", @"exception"];
    XCTFail(@"not reached");
}
@end
