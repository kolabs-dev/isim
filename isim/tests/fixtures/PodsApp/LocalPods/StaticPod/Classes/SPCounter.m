#import "SPCounter.h"

@implementation SPCounter
- (void)increment { _value += 1; }
+ (NSString *)resourceText {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"StaticPodResources" ofType:@"bundle"];
    NSBundle *bundle = path ? [NSBundle bundleWithPath:path] : nil;
    NSString *file = [bundle pathForResource:@"counter" ofType:@"txt"];
    NSString *text = file ? [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:NULL] : nil;
    return text ? [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"(no bundle)";
}
@end
