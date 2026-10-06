#pragma once
#import <XCTest/XCTestObservation.h>

/* Objective-C assertion macros. They report through _XCTIsimRecordFailure with the file and line of the
 * assertion; with continueAfterFailure = NO the runner stops the test after the first failure (an internal
 * exception unwinds to the runner, as in XCTest). XCTAssertThrows* use @try/@catch. */

NS_ASSUME_NONNULL_BEGIN
XCT_EXPORT NSString *_XCTIsimDescribe(const char *objCType, const void *value);
XCT_EXPORT NSString *_XCTIsimFormat(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
NS_ASSUME_NONNULL_END

#define _XCTRegisterFailure(test, condition, ...) \
    _XCTIsimRecordFailure([NSString stringWithFormat:@"%@%@", (condition), _XCTIsimFormat(@"" __VA_ARGS__)], @(__FILE__), __LINE__, YES)

#define XCTFail(...) _XCTIsimRecordFailure([NSString stringWithFormat:@"failed%@", _XCTIsimFormat(@"" __VA_ARGS__)], @(__FILE__), __LINE__, YES)

#define XCTAssert(expression, ...) XCTAssertTrue(expression, __VA_ARGS__)

#define XCTAssertTrue(expression, ...) do { \
    BOOL _xct_v = !!(expression); \
    if (!_xct_v) _XCTRegisterFailure(nil, @"((" #expression ") is true) failed", __VA_ARGS__); \
} while (0)

#define XCTAssertFalse(expression, ...) do { \
    BOOL _xct_v = !!(expression); \
    if (_xct_v) _XCTRegisterFailure(nil, @"((" #expression ") is false) failed", __VA_ARGS__); \
} while (0)

#define XCTAssertNil(expression, ...) do { \
    id _xct_v = (expression); \
    if (_xct_v != nil) _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression ") == nil) failed: \"%@\"", _xct_v]), __VA_ARGS__); \
} while (0)

#define XCTAssertNotNil(expression, ...) do { \
    id _xct_v = (expression); \
    if (_xct_v == nil) _XCTRegisterFailure(nil, @"((" #expression ") != nil) failed", __VA_ARGS__); \
} while (0)

#define XCTAssertEqualObjects(expression1, expression2, ...) do { \
    id _xct_a = (expression1), _xct_b = (expression2); \
    if (!(_xct_a == _xct_b || [_xct_a isEqual:_xct_b])) \
        _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression1 ") equal to (" #expression2 ")) failed: (\"%@\") is not equal to (\"%@\")", _xct_a, _xct_b]), __VA_ARGS__); \
} while (0)

#define XCTAssertNotEqualObjects(expression1, expression2, ...) do { \
    id _xct_a = (expression1), _xct_b = (expression2); \
    if (_xct_a == _xct_b || [_xct_a isEqual:_xct_b]) \
        _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression1 ") not equal to (" #expression2 ")) failed: (\"%@\") is equal to (\"%@\")", _xct_a, _xct_b]), __VA_ARGS__); \
} while (0)

#define _XCTCompare(op, text, failtext, expression1, expression2, ...) do { \
    __typeof__(expression1) _xct_a = (expression1); __typeof__(expression2) _xct_b = (expression2); \
    if (!(_xct_a op _xct_b)) \
        _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression1 ") " text " (" #expression2 ")) failed: (\"%@\") " failtext " (\"%@\")", \
            _XCTIsimDescribe(@encode(__typeof__(_xct_a)), &_xct_a), _XCTIsimDescribe(@encode(__typeof__(_xct_b)), &_xct_b)]), __VA_ARGS__); \
} while (0)

#define XCTAssertEqual(expression1, expression2, ...) _XCTCompare(==, "equal to", "is not equal to", expression1, expression2, __VA_ARGS__)
#define XCTAssertNotEqual(expression1, expression2, ...) _XCTCompare(!=, "not equal to", "is equal to", expression1, expression2, __VA_ARGS__)
#define XCTAssertGreaterThan(expression1, expression2, ...) _XCTCompare(>, "greater than", "is not greater than", expression1, expression2, __VA_ARGS__)
#define XCTAssertGreaterThanOrEqual(expression1, expression2, ...) _XCTCompare(>=, "greater than or equal to", "is less than", expression1, expression2, __VA_ARGS__)
#define XCTAssertLessThan(expression1, expression2, ...) _XCTCompare(<, "less than", "is not less than", expression1, expression2, __VA_ARGS__)
#define XCTAssertLessThanOrEqual(expression1, expression2, ...) _XCTCompare(<=, "less than or equal to", "is greater than", expression1, expression2, __VA_ARGS__)

#define XCTAssertEqualWithAccuracy(expression1, expression2, accuracy, ...) do { \
    double _xct_a = (double)(expression1), _xct_b = (double)(expression2), _xct_acc = (double)(accuracy); \
    if (!(_xct_a == _xct_b || (_xct_a - _xct_b <= _xct_acc && _xct_b - _xct_a <= _xct_acc))) \
        _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression1 ") equal to (" #expression2 ") +/- (" #accuracy ")) failed: (\"%g\") is not equal to (\"%g\") +/- (\"%g\")", _xct_a, _xct_b, _xct_acc]), __VA_ARGS__); \
} while (0)

#define XCTAssertNotEqualWithAccuracy(expression1, expression2, accuracy, ...) do { \
    double _xct_a = (double)(expression1), _xct_b = (double)(expression2), _xct_acc = (double)(accuracy); \
    if (_xct_a == _xct_b || (_xct_a - _xct_b <= _xct_acc && _xct_b - _xct_a <= _xct_acc)) \
        _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression1 ") not equal to (" #expression2 ") +/- (" #accuracy ")) failed: (\"%g\") is equal to (\"%g\") +/- (\"%g\")", _xct_a, _xct_b, _xct_acc]), __VA_ARGS__); \
} while (0)

#define XCTAssertThrows(expression, ...) do { \
    BOOL _xct_threw = NO; \
    @try { (void)(expression); } @catch (id _xct_e) { _xct_threw = YES; } \
    if (!_xct_threw) _XCTRegisterFailure(nil, @"((" #expression ") throws) failed", __VA_ARGS__); \
} while (0)
#define XCTAssertThrowsSpecific(expression, exception_class, ...) do { \
    BOOL _xct_ok = NO; NSString *_xct_got = @"no exception"; \
    @try { (void)(expression); } @catch (id _xct_e) { _xct_ok = [_xct_e isKindOfClass:[exception_class class]]; _xct_got = NSStringFromClass([_xct_e class]); } \
    if (!_xct_ok) _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression ") throws <" #exception_class ">) failed: %@", _xct_got]), __VA_ARGS__); \
} while (0)
#define XCTAssertThrowsSpecificNamed(expression, exception_class, exception_name, ...) do { \
    BOOL _xct_ok = NO; \
    @try { (void)(expression); } @catch (id _xct_e) { _xct_ok = [_xct_e isKindOfClass:[exception_class class]] && [[_xct_e name] isEqualToString:exception_name]; } \
    if (!_xct_ok) _XCTRegisterFailure(nil, @"((" #expression ") throws <" #exception_class ", \"" #exception_name "\">) failed", __VA_ARGS__); \
} while (0)
#define XCTAssertNoThrow(expression, ...) do { \
    @try { (void)(expression); } \
    @catch (id _xct_e) { _XCTRegisterFailure(nil, ([NSString stringWithFormat:@"((" #expression ") does not throw) failed: throwing \"%@\"", [_xct_e reason]]), __VA_ARGS__); } \
} while (0)
#define XCTAssertNoThrowSpecific(expression, exception_class, ...) XCTAssertNoThrow(expression, __VA_ARGS__)
#define XCTAssertNoThrowSpecificNamed(expression, exception_class, exception_name, ...) XCTAssertNoThrow(expression, __VA_ARGS__)

#define XCTSkip(...) _XCTIsimRecordSkip(_XCTIsimFormat(@"" __VA_ARGS__), @(__FILE__), __LINE__)
#define XCTSkipIf(expression, ...) do { if ((expression)) _XCTIsimRecordSkip([NSString stringWithFormat:@"((" #expression ") is true)%@", _XCTIsimFormat(@"" __VA_ARGS__)], @(__FILE__), __LINE__); } while (0)
#define XCTSkipUnless(expression, ...) do { if (!(expression)) _XCTIsimRecordSkip([NSString stringWithFormat:@"((" #expression ") is false)%@", _XCTIsimFormat(@"" __VA_ARGS__)], @(__FILE__), __LINE__); } while (0)
