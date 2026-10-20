#pragma once
#import <XCTest/XCTIssue.h>
NS_ASSUME_NONNULL_BEGIN

/* Which issues an XCTExpectFailure scope expects, whether it is on, and whether it must match one (strict). */
NS_SWIFT_NAME(XCTExpectedFailure.Options)
@interface XCTExpectedFailureOptions : NSObject <NSCopying>
/* not strict: the scope may end without matching an issue */
+ (instancetype)nonStrictOptions;
/* default: every issue matches */
@property (copy) BOOL (^issueMatcher)(XCTIssue *issue);
@property (getter=isEnabled) BOOL enabled;
@property (getter=isStrict) BOOL strict;
@end

/* An issue an XCTExpectFailure scope matched: recorded as an expected failure, it does not fail the test. */
@interface XCTExpectedFailure : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (readonly, copy, nullable) NSString *failureReason;
@property (readonly) XCTIssue *issue;
@end

/* Expected failures: issues recorded after the call (until the end of the test) or in the block are expected
 * failures. A strict scope that ends without one records an issue of type XCTIssueTypeUnmatchedExpectedFailure. */
XCT_EXPORT void XCTExpectFailure(NSString *_Nullable failureReason) NS_REFINED_FOR_SWIFT;
XCT_EXPORT void XCTExpectFailureWithOptions(NSString *_Nullable failureReason, XCTExpectedFailureOptions *options) NS_REFINED_FOR_SWIFT;
XCT_EXPORT void XCTExpectFailureInBlock(NSString *_Nullable failureReason, void (NS_NOESCAPE ^failingBlock)(void)) NS_REFINED_FOR_SWIFT;
XCT_EXPORT void XCTExpectFailureWithOptionsInBlock(NSString *_Nullable failureReason, XCTExpectedFailureOptions *options,
                                                   void (NS_NOESCAPE ^failingBlock)(void)) NS_REFINED_FOR_SWIFT;

/* isim: a scope the Swift overlay opens and closes around a throwing block */
XCT_EXPORT id _XCTIsimPushExpectedFailure(NSString *_Nullable failureReason, XCTExpectedFailureOptions *options) NS_SWIFT_NAME(_XCTIsimPushExpectedFailure(_:_:));
XCT_EXPORT void _XCTIsimPopExpectedFailure(id scope) NS_SWIFT_NAME(_XCTIsimPopExpectedFailure(_:));

NS_ASSUME_NONNULL_END
