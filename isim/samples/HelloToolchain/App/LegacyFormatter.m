#import "LegacyFormatter.h"
#import "HelloToolchain-Swift.h"

@implementation LegacyFormatter
+ (NSString *)describeScore { return [NSString stringWithFormat:@"objc score %ld", (long)[TCScorer score]]; }
@end
