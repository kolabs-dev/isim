#import "FOOThing.h"

double FooVersionNumber = 1.3;

@implementation FOOThing
+ (NSInteger)answer { return 41 + 1; }
+ (NSString *)origin { return [NSBundle bundleForClass:self].bundlePath.lastPathComponent; }
@end
