#import "GRTStyle.h"

@implementation GRTStyle
+ (NSString *)decorate:(NSString *)text { return [NSString stringWithFormat:@"«%@»", text]; }
@end
