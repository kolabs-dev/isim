#pragma once
#import <XCTest/XCTestDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class XCTAttachment;

/* Where in source code something happened: a file and a line. */
@interface XCTSourceCodeLocation : NSObject <NSSecureCoding>
- (instancetype)initWithFileURL:(NSURL *)fileURL lineNumber:(NSInteger)lineNumber NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFilePath:(NSString *)filePath lineNumber:(NSInteger)lineNumber;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (readonly) NSURL *fileURL;
@property (readonly) NSInteger lineNumber;
@end

/* The symbol of a call stack frame. */
@interface XCTSourceCodeSymbolInfo : NSObject <NSSecureCoding>
- (instancetype)initWithImageName:(NSString *)imageName symbolName:(NSString *)symbolName location:(nullable XCTSourceCodeLocation *)location NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (readonly, copy) NSString *imageName;
@property (readonly, copy) NSString *symbolName;
@property (readonly, nullable) XCTSourceCodeLocation *location;
@end

/* One frame of a call stack: its address and, once symbolicated, its symbol (isim: dladdr). */
@interface XCTSourceCodeFrame : NSObject <NSSecureCoding>
- (instancetype)initWithAddress:(uint64_t)address symbolInfo:(nullable XCTSourceCodeSymbolInfo *)symbolInfo NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithAddress:(uint64_t)address;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (readonly) uint64_t address;
@property (readonly, nullable) XCTSourceCodeSymbolInfo *symbolInfo;
@property (readonly, nullable) NSError *symbolicationError;
- (nullable XCTSourceCodeSymbolInfo *)symbolInfoWithError:(NSError **)outError;
@end

/* Where an issue happened: a call stack and a source location. -init captures the current call stack. */
@interface XCTSourceCodeContext : NSObject <NSSecureCoding>
- (instancetype)initWithCallStack:(NSArray<XCTSourceCodeFrame *> *)callStack location:(nullable XCTSourceCodeLocation *)location NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithLocation:(nullable XCTSourceCodeLocation *)location;
- (instancetype)init;
@property (readonly, copy) NSArray<XCTSourceCodeFrame *> *callStack;
@property (readonly, nullable) XCTSourceCodeLocation *location;
@end

typedef NS_ENUM(NSInteger, XCTIssueType) {
    XCTIssueTypeAssertionFailure = 0,
    XCTIssueTypeThrownError = 1,
    XCTIssueTypeUncaughtException = 2,
    XCTIssueTypePerformanceRegression = 3,
    XCTIssueTypeSystem = 4,
    XCTIssueTypeUnmatchedExpectedFailure = 5,
} NS_SWIFT_NAME(XCTIssueReference.IssueType);

/* Something wrong in a test: a failed assertion, a thrown error, an uncaught exception. Recorded with
 * XCTestCase -recordIssue: (Swift: record(_:), with the XCTIssue struct, bridged to this class). */
NS_SWIFT_NAME(XCTIssueReference)
@interface XCTIssue : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
- (instancetype)initWithType:(XCTIssueType)type compactDescription:(NSString *)compactDescription
         detailedDescription:(nullable NSString *)detailedDescription sourceCodeContext:(XCTSourceCodeContext *)sourceCodeContext
             associatedError:(nullable NSError *)associatedError attachments:(NSArray<XCTAttachment *> *)attachments NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithType:(XCTIssueType)type compactDescription:(NSString *)compactDescription;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (readonly) XCTIssueType type;
@property (readonly, copy) NSString *compactDescription;
@property (readonly, copy, nullable) NSString *detailedDescription;
@property (readonly, strong) XCTSourceCodeContext *sourceCodeContext;
@property (readonly, strong, nullable) NSError *associatedError;
@property (readonly, copy) NSArray<XCTAttachment *> *attachments;
@end

/* An issue that can be changed before it is recorded (in an override of -recordIssue:). */
NS_SWIFT_UNAVAILABLE("Use the XCTIssue struct, which is mutable")
@interface XCTMutableIssue : XCTIssue
@property (readwrite) XCTIssueType type;
@property (readwrite, copy) NSString *compactDescription;
@property (readwrite, copy, nullable) NSString *detailedDescription;
@property (readwrite, strong) XCTSourceCodeContext *sourceCodeContext;
@property (readwrite, strong, nullable) NSError *associatedError;
@property (readwrite, copy) NSArray<XCTAttachment *> *attachments;
- (void)addAttachment:(XCTAttachment *)attachment;
@end

NS_ASSUME_NONNULL_END
