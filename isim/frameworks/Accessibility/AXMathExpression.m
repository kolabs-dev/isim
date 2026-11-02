/* isim Accessibility: math expressions (ARC). Each class can say itself (_isim_spoken), which isim's VoiceOver reads for
   an AXMathExpressionProvider element: "x squared plus 1", "start fraction, a over b, end fraction", "square root of 2". */
#import <Accessibility/Accessibility.h>
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the framework builds for iOS 15 */

@interface AXMathExpression (IsimSpoken)
- (NSString *)_isim_spoken;
@end
static NSString *say_all(NSArray<AXMathExpression *> *a) {
    NSMutableArray *parts = [NSMutableArray array];
    for (AXMathExpression *e in a) { NSString *s = [e _isim_spoken]; if (s.length) [parts addObject:s]; }
    return [parts componentsJoinedByString:@" "];
}
static NSString *operator_words(NSString *op) {
    static NSDictionary *words;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        words = @{ @"+": @"plus", @"-": @"minus", @"−": @"minus", @"=": @"equals", @"×": @"times", @"*": @"times", @"·": @"times",
                   @"÷": @"divided by", @"/": @"divided by", @"<": @"is less than", @">": @"is greater than", @"≤": @"is less than or equal to",
                   @"≥": @"is greater than or equal to", @"≠": @"is not equal to", @"±": @"plus or minus", @"≈": @"is approximately equal to",
                   @"∑": @"sum", @"∫": @"integral", @"∏": @"product", @"→": @"approaches", @"∞": @"infinity", @"′": @"prime" };
    });
    return words[op] ?: op;
}
static NSString *ordinal(NSString *n) {
    if ([n isEqualToString:@"2"]) return @"square";
    if ([n isEqualToString:@"3"]) return @"cube";
    return [n stringByAppendingString:@"th"];
}

@implementation AXMathExpression
- (instancetype)_isim_init { return [super init]; }
- (NSString *)_isim_spoken { return @""; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass([self class]), [self _isim_spoken]]; }
@end

#define CONTENT_CLASS(Name, Spoken) \
@implementation Name \
- (instancetype)initWithContent:(NSString *)content { if ((self = [super _isim_init])) _content = [content copy] ?: @""; return self; } \
- (NSString *)_isim_spoken { return Spoken; } \
@end
CONTENT_CLASS(AXMathExpressionNumber, _content)
CONTENT_CLASS(AXMathExpressionIdentifier, _content)
CONTENT_CLASS(AXMathExpressionOperator, operator_words(_content))
CONTENT_CLASS(AXMathExpressionText, _content)

@implementation AXMathExpressionRow
- (instancetype)initWithExpressions:(NSArray *)expressions { if ((self = [super _isim_init])) _expressions = [expressions copy] ?: @[]; return self; }
- (NSString *)_isim_spoken { return say_all(_expressions); }
@end
@implementation AXMathExpressionTableCell
- (instancetype)initWithExpressions:(NSArray *)expressions { if ((self = [super _isim_init])) _expressions = [expressions copy] ?: @[]; return self; }
- (NSString *)_isim_spoken { return say_all(_expressions); }
@end
@implementation AXMathExpressionTableRow
- (instancetype)initWithExpressions:(NSArray *)expressions { if ((self = [super _isim_init])) _expressions = [expressions copy] ?: @[]; return self; }
- (NSString *)_isim_spoken {
    NSMutableArray *cells = [NSMutableArray array];
    for (AXMathExpression *e in _expressions) [cells addObject:[e _isim_spoken]];
    return [cells componentsJoinedByString:@", "];
}
@end
@implementation AXMathExpressionTable
- (instancetype)initWithExpressions:(NSArray *)expressions { if ((self = [super _isim_init])) _expressions = [expressions copy] ?: @[]; return self; }
- (NSString *)_isim_spoken {
    NSMutableArray *rows = [NSMutableArray array];
    [_expressions enumerateObjectsUsingBlock:^(AXMathExpression *e, NSUInteger i, BOOL *stop) {
        [rows addObject:[NSString stringWithFormat:@"row %lu: %@", (unsigned long)i + 1, [e _isim_spoken]]];
    }];
    return [NSString stringWithFormat:@"table, %lu rows, %@, end table", (unsigned long)_expressions.count, [rows componentsJoinedByString:@"; "]];
}
@end
@implementation AXMathExpressionFenced
- (instancetype)initWithExpressions:(NSArray *)expressions openString:(NSString *)open closeString:(NSString *)close {
    if ((self = [super _isim_init])) { _expressions = [expressions copy] ?: @[]; _openString = [open copy] ?: @""; _closeString = [close copy] ?: @""; }
    return self;
}
- (instancetype)initWithExpressions:(NSArray *)expressions open:(NSString *)open close:(NSString *)close {
    return [self initWithExpressions:expressions openString:open closeString:close];
}
static NSString *fence_word(NSString *f, BOOL open) {
    if ([f isEqualToString:@"("] || [f isEqualToString:@")"]) return open ? @"open paren" : @"close paren";
    if ([f isEqualToString:@"["] || [f isEqualToString:@"]"]) return open ? @"open bracket" : @"close bracket";
    if ([f isEqualToString:@"{"] || [f isEqualToString:@"}"]) return open ? @"open brace" : @"close brace";
    if ([f isEqualToString:@"|"]) return open ? @"absolute value of" : @"end absolute value";
    return f;
}
- (NSString *)_isim_spoken {
    NSMutableArray *p = [NSMutableArray array];
    if (_openString.length) [p addObject:fence_word(_openString, YES)];
    NSString *inner = say_all(_expressions);
    if (inner.length) [p addObject:inner];
    if (_closeString.length) [p addObject:fence_word(_closeString, NO)];
    return [p componentsJoinedByString:@" "];
}
@end
@implementation AXMathExpressionFraction
- (instancetype)initWithNumeratorExpression:(AXMathExpression *)n denimonatorExpression:(AXMathExpression *)d {
    if ((self = [super _isim_init])) { _numeratorExpression = n; _denimonatorExpression = d; }
    return self;
}
- (NSString *)_isim_spoken {
    return [NSString stringWithFormat:@"start fraction, %@ over %@, end fraction", [_numeratorExpression _isim_spoken], [_denimonatorExpression _isim_spoken]];
}
@end
@implementation AXMathExpressionRoot
- (instancetype)initWithRadicandExpressions:(NSArray *)radicand rootIndexExpression:(AXMathExpression *)index {
    if ((self = [super _isim_init])) { _radicandExpressions = [radicand copy] ?: @[]; _rootIndexExpression = index; }
    return self;
}
- (NSString *)_isim_spoken {
    NSString *idx = [_rootIndexExpression _isim_spoken];
    return [NSString stringWithFormat:@"%@ root of %@, end root", idx.length ? ordinal(idx) : @"square", say_all(_radicandExpressions)];
}
@end
@implementation AXMathExpressionSubSuperscript
- (instancetype)initWithBaseExpression:(NSArray *)base subscriptExpressions:(NSArray *)sub superscriptExpressions:(NSArray *)sup {
    if ((self = [super _isim_init])) {
        _baseExpression = base.count == 1 ? base.firstObject : [[AXMathExpressionRow alloc] initWithExpressions:base ?: @[]];
        _subscriptExpressions = [sub copy] ?: @[]; _superscriptExpressions = [sup copy] ?: @[];
    }
    return self;
}
- (NSString *)_isim_spoken {
    NSMutableString *s = [NSMutableString stringWithString:[_baseExpression _isim_spoken]];
    if (_subscriptExpressions.count) [s appendFormat:@" sub %@", say_all(_subscriptExpressions)];
    if (_superscriptExpressions.count) {
        NSString *sup = say_all(_superscriptExpressions);
        if ([sup isEqualToString:@"2"]) [s appendString:@" squared"];
        else if ([sup isEqualToString:@"3"]) [s appendString:@" cubed"];
        else [s appendFormat:@" to the %@ power", sup];
    }
    return s;
}
@end
@implementation AXMathExpressionUnderOver
- (instancetype)initWithBaseExpression:(AXMathExpression *)base underExpression:(AXMathExpression *)under overExpression:(AXMathExpression *)over {
    if ((self = [super _isim_init])) { _baseExpression = base; _underExpression = under; _overExpression = over; }
    return self;
}
- (NSString *)_isim_spoken {
    return [NSString stringWithFormat:@"%@ from %@ to %@", [_baseExpression _isim_spoken], [_underExpression _isim_spoken], [_overExpression _isim_spoken]];
}
@end
@implementation AXMathExpressionMultiscript
- (instancetype)initWithBaseExpression:(AXMathExpression *)base prescriptExpressions:(NSArray *)pre postscriptExpressions:(NSArray *)post {
    if ((self = [super _isim_init])) { _baseExpression = base; _prescriptExpressions = [pre copy] ?: @[]; _postscriptExpressions = [post copy] ?: @[]; }
    return self;
}
- (NSString *)_isim_spoken {
    NSMutableArray *p = [NSMutableArray array];
    for (AXMathExpressionSubSuperscript *s in _prescriptExpressions) [p addObject:[NSString stringWithFormat:@"prescript %@", [s _isim_spoken]]];
    [p addObject:[_baseExpression _isim_spoken]];
    for (AXMathExpressionSubSuperscript *s in _postscriptExpressions) [p addObject:[s _isim_spoken]];
    return [p componentsJoinedByString:@" "];
}
@end
