/* isim XCTest: issues (XCTIssue, XCTMutableIssue), their source code context (locations, call stack frames, symbols)
 * and expected failures (XCTExpectedFailure, its options). Self-authored for isim; XCTest.m records them. */
#import <XCTest/XCTest.h>
#include <dlfcn.h>
#import "XCTIsimInternal.h"

/* ================= source code context ================= */
@implementation XCTSourceCodeLocation
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithFileURL:(NSURL *)fileURL lineNumber:(NSInteger)lineNumber {
    if ((self = [super init])) { _fileURL = [fileURL copy]; _lineNumber = lineNumber; }
    return self;
}
- (instancetype)initWithFilePath:(NSString *)filePath lineNumber:(NSInteger)lineNumber {
    return [self initWithFileURL:[NSURL fileURLWithPath:filePath] lineNumber:lineNumber];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithFileURL:[c decodeObjectOfClass:[NSURL class] forKey:@"fileURL"] ?: [NSURL fileURLWithPath:@"/"]
                      lineNumber:[c decodeIntegerForKey:@"lineNumber"]];
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_fileURL forKey:@"fileURL"]; [c encodeInteger:_lineNumber forKey:@"lineNumber"]; }
- (NSString *)description { return [NSString stringWithFormat:@"%@:%ld", _fileURL.path, (long)_lineNumber]; }
@end

@implementation XCTSourceCodeSymbolInfo
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithImageName:(NSString *)imageName symbolName:(NSString *)symbolName location:(XCTSourceCodeLocation *)location {
    if ((self = [super init])) { _imageName = [imageName copy]; _symbolName = [symbolName copy]; _location = location; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithImageName:[c decodeObjectOfClass:[NSString class] forKey:@"imageName"] ?: @""
                        symbolName:[c decodeObjectOfClass:[NSString class] forKey:@"symbolName"] ?: @""
                          location:[c decodeObjectOfClass:[XCTSourceCodeLocation class] forKey:@"location"]];
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_imageName forKey:@"imageName"]; [c encodeObject:_symbolName forKey:@"symbolName"]; [c encodeObject:_location forKey:@"location"];
}
@end

@implementation XCTSourceCodeFrame { BOOL _symbolicated; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithAddress:(uint64_t)address symbolInfo:(XCTSourceCodeSymbolInfo *)symbolInfo {
    if ((self = [super init])) { _address = address; _symbolInfo = symbolInfo; _symbolicated = symbolInfo != nil; }
    return self;
}
- (instancetype)initWithAddress:(uint64_t)address { return [self initWithAddress:address symbolInfo:nil]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithAddress:(uint64_t)[c decodeInt64ForKey:@"address"]
                      symbolInfo:[c decodeObjectOfClass:[XCTSourceCodeSymbolInfo class] forKey:@"symbolInfo"]];
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInt64:(int64_t)_address forKey:@"address"]; [c encodeObject:_symbolInfo forKey:@"symbolInfo"]; }
/* adapted: the image and the nearest exported symbol (dladdr); no file and line (isim reads no debug info here) */
- (XCTSourceCodeSymbolInfo *)symbolInfoWithError:(NSError **)outError {
    if (!_symbolicated) {
        _symbolicated = YES;
        Dl_info info;
        if (dladdr((const void *)(uintptr_t)_address, &info) && info.dli_sname)
            _symbolInfo = [[XCTSourceCodeSymbolInfo alloc] initWithImageName:info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?"
                                                                   symbolName:@(info.dli_sname) location:nil];
        else
            _symbolicationError = [NSError errorWithDomain:@"XCTSourceCodeFrameErrorDomain" code:1
                                                  userInfo:@{ NSLocalizedDescriptionKey: @"no symbol for this address" }];
    }
    if (!_symbolInfo && outError) *outError = _symbolicationError;
    return _symbolInfo;
}
@end

@implementation XCTSourceCodeContext
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCallStack:(NSArray<XCTSourceCodeFrame *> *)callStack location:(XCTSourceCodeLocation *)location {
    if ((self = [super init])) { _callStack = [callStack copy] ?: @[]; _location = location; }
    return self;
}
- (instancetype)initWithLocation:(XCTSourceCodeLocation *)location {
    NSMutableArray *frames = [NSMutableArray array];
    for (NSNumber *a in [NSThread callStackReturnAddresses]) [frames addObject:[[XCTSourceCodeFrame alloc] initWithAddress:a.unsignedLongLongValue]];
    return [self initWithCallStack:frames location:location];
}
- (instancetype)init { return [self initWithLocation:nil]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [XCTSourceCodeFrame class], nil];
    return [self initWithCallStack:[c decodeObjectOfClasses:classes forKey:@"callStack"] ?: @[]
                          location:[c decodeObjectOfClass:[XCTSourceCodeLocation class] forKey:@"location"]];
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_callStack forKey:@"callStack"]; [c encodeObject:_location forKey:@"location"]; }
@end

/* ================= issues ================= */
@interface XCTIssue ()
@property (readwrite) XCTIssueType type;
@property (readwrite, copy) NSString *compactDescription;
@property (readwrite, copy, nullable) NSString *detailedDescription;
@property (readwrite, strong) XCTSourceCodeContext *sourceCodeContext;
@property (readwrite, strong, nullable) NSError *associatedError;
@property (readwrite, copy) NSArray<XCTAttachment *> *attachments;
@end

@implementation XCTIssue
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithType:(XCTIssueType)type compactDescription:(NSString *)compactDescription detailedDescription:(NSString *)detailedDescription
           sourceCodeContext:(XCTSourceCodeContext *)sourceCodeContext associatedError:(NSError *)associatedError attachments:(NSArray<XCTAttachment *> *)attachments {
    if ((self = [super init])) {
        _type = type; _compactDescription = [compactDescription copy] ?: @""; _detailedDescription = [detailedDescription copy];
        _sourceCodeContext = sourceCodeContext ?: [[XCTSourceCodeContext alloc] initWithCallStack:@[] location:nil];
        _associatedError = associatedError; _attachments = [attachments copy] ?: @[];
    }
    return self;
}
- (instancetype)initWithType:(XCTIssueType)type compactDescription:(NSString *)compactDescription {
    return [self initWithType:type compactDescription:compactDescription detailedDescription:nil
            sourceCodeContext:[XCTSourceCodeContext new] associatedError:nil attachments:@[]];
}
- (id)copyWithZone:(NSZone *)zone {
    if ([self isMemberOfClass:[XCTIssue class]]) return self;
    return [[XCTIssue alloc] initWithType:_type compactDescription:_compactDescription detailedDescription:_detailedDescription
                        sourceCodeContext:_sourceCodeContext associatedError:_associatedError attachments:_attachments];
}
- (id)mutableCopyWithZone:(NSZone *)zone {
    return [[XCTMutableIssue alloc] initWithType:_type compactDescription:_compactDescription detailedDescription:_detailedDescription
                               sourceCodeContext:_sourceCodeContext associatedError:_associatedError attachments:_attachments];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithType:[c decodeIntegerForKey:@"type"]
           compactDescription:[c decodeObjectOfClass:[NSString class] forKey:@"compactDescription"] ?: @""
          detailedDescription:[c decodeObjectOfClass:[NSString class] forKey:@"detailedDescription"]
            sourceCodeContext:[c decodeObjectOfClass:[XCTSourceCodeContext class] forKey:@"sourceCodeContext"]
              associatedError:[c decodeObjectOfClass:[NSError class] forKey:@"associatedError"] attachments:@[]];
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:_type forKey:@"type"]; [c encodeObject:_compactDescription forKey:@"compactDescription"];
    [c encodeObject:_detailedDescription forKey:@"detailedDescription"]; [c encodeObject:_sourceCodeContext forKey:@"sourceCodeContext"];
    [c encodeObject:_associatedError forKey:@"associatedError"];
}
- (NSString *)description {
    static NSString *const names[] = { @"Assertion Failure", @"Thrown Error", @"Uncaught Exception", @"Performance Regression",
                                       @"System Error", @"Unmatched Expected Failure" };
    NSString *kind = (NSUInteger)_type < 6 ? names[_type] : @"Issue";
    XCTSourceCodeLocation *l = _sourceCodeContext.location;
    return l ? [NSString stringWithFormat:@"%@ at %@:%ld: %@", kind, l.fileURL.lastPathComponent, (long)l.lineNumber, _compactDescription]
             : [NSString stringWithFormat:@"%@: %@", kind, _compactDescription];
}
@end

@implementation XCTMutableIssue
@dynamic type, compactDescription, detailedDescription, sourceCodeContext, associatedError, attachments;
- (void)addAttachment:(XCTAttachment *)attachment { if (attachment) self.attachments = [self.attachments arrayByAddingObject:attachment]; }
@end

/* ================= expected failures ================= */
@implementation XCTExpectedFailureOptions
+ (instancetype)nonStrictOptions { XCTExpectedFailureOptions *o = [self new]; o.strict = NO; return o; }
- (instancetype)init {
    if ((self = [super init])) { _enabled = YES; _strict = YES; _issueMatcher = ^BOOL(XCTIssue *issue) { return YES; }; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    XCTExpectedFailureOptions *o = [XCTExpectedFailureOptions new];
    o.enabled = _enabled; o.strict = _strict; o.issueMatcher = _issueMatcher;
    return o;
}
@end

@implementation XCTExpectedFailure
- (instancetype)initIsimWithReason:(NSString *)reason issue:(XCTIssue *)issue {
    if ((self = [super init])) { _failureReason = [reason copy]; _issue = [issue copy]; }
    return self;
}
- (NSString *)description { return [NSString stringWithFormat:@"Expected failure (%@): %@", _failureReason ?: @"no reason", _issue]; }
@end
