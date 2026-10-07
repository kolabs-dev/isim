#pragma once
#import <XCTest/XCTestRun.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCTestSuite : XCTest
+ (instancetype)defaultTestSuite;
+ (instancetype)testSuiteWithName:(NSString *)name;
+ (instancetype)testSuiteForTestCaseClass:(Class)testCaseClass;
- (instancetype)initWithName:(NSString *)name;
- (void)addTest:(XCTest *)test;
@property (readonly, copy) NSArray<__kindof XCTest *> *tests;
@end

NS_ASSUME_NONNULL_END
