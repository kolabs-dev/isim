#import <Foundation/Foundation.h>

/* MathKit: a static library target (libMathKit.a); its public header is copied to include/MathKit */
@interface MKCalculator : NSObject
+ (NSInteger)add:(NSInteger)a to:(NSInteger)b;
@end
