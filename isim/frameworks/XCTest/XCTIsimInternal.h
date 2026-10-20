/* isim XCTest: declarations shared by the framework's sources (not installed). */
#pragma once
#import <XCTest/XCTest.h>

@interface XCTExpectedFailure ()
- (instancetype)initIsimWithReason:(NSString *)reason issue:(XCTIssue *)issue;
@end
