#pragma once
/* isim SDK (self-authored): math expressions an element gives VoiceOver (AXMathExpressionProvider), which isim's VoiceOver
 * reads as speech ("x squared plus 1, over 2"). */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(18.2))
@interface AXMathExpression : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(18.2))
@protocol AXMathExpressionProvider <NSObject>
- (nullable AXMathExpression *)accessibilityMathExpression;
@end

API_AVAILABLE(ios(18.2)) @interface AXMathExpressionNumber : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly, copy) NSString *content;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionIdentifier : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly, copy) NSString *content;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionOperator : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly, copy) NSString *content;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionText : AXMathExpression
- (instancetype)initWithContent:(NSString *)content;
@property (nonatomic, readonly, copy) NSString *content;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionRow : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *expressions;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionTable : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *expressions;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionTableRow : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *expressions;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionTableCell : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *expressions;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionFenced : AXMathExpression
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions openString:(NSString *)openString closeString:(NSString *)closeString;
- (instancetype)initWithExpressions:(NSArray<AXMathExpression *> *)expressions open:(NSString *)openString close:(NSString *)closeString;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *expressions;
@property (nonatomic, readonly, copy) NSString *openString;
@property (nonatomic, readonly, copy) NSString *closeString;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionFraction : AXMathExpression
- (instancetype)initWithNumeratorExpression:(AXMathExpression *)numeratorExpression denimonatorExpression:(AXMathExpression *)denimonatorExpression;
@property (nonatomic, readonly, strong) AXMathExpression *numeratorExpression;
@property (nonatomic, readonly, strong) AXMathExpression *denimonatorExpression;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionRoot : AXMathExpression
- (instancetype)initWithRadicandExpressions:(NSArray<AXMathExpression *> *)radicandExpressions rootIndexExpression:(AXMathExpression *)rootIndexExpression;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *radicandExpressions;
@property (nonatomic, readonly, strong) AXMathExpression *rootIndexExpression;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionSubSuperscript : AXMathExpression
- (instancetype)initWithBaseExpression:(NSArray<AXMathExpression *> *)baseExpression subscriptExpressions:(NSArray<AXMathExpression *> *)subscriptExpressions
                superscriptExpressions:(NSArray<AXMathExpression *> *)superscriptExpressions;
@property (nonatomic, readonly, strong) AXMathExpression *baseExpression;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *subscriptExpressions;
@property (nonatomic, readonly, copy) NSArray<AXMathExpression *> *superscriptExpressions;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionUnderOver : AXMathExpression
- (instancetype)initWithBaseExpression:(AXMathExpression *)baseExpression underExpression:(AXMathExpression *)underExpression overExpression:(AXMathExpression *)overExpression;
@property (nonatomic, readonly, strong) AXMathExpression *baseExpression;
@property (nonatomic, readonly, strong) AXMathExpression *underExpression;
@property (nonatomic, readonly, strong) AXMathExpression *overExpression;
@end
API_AVAILABLE(ios(18.2)) @interface AXMathExpressionMultiscript : AXMathExpression
- (instancetype)initWithBaseExpression:(AXMathExpression *)baseExpression prescriptExpressions:(NSArray<AXMathExpressionSubSuperscript *> *)prescriptExpressions
                 postscriptExpressions:(NSArray<AXMathExpressionSubSuperscript *> *)postscriptExpressions;
@property (nonatomic, readonly, strong) AXMathExpression *baseExpression;
@property (nonatomic, readonly, copy) NSArray<AXMathExpressionSubSuperscript *> *prescriptExpressions;
@property (nonatomic, readonly, copy) NSArray<AXMathExpressionSubSuperscript *> *postscriptExpressions;
@end

NS_ASSUME_NONNULL_END
