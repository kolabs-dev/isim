#import "FPGreeter.h"

@implementation FPGreeter
+ (NSString *)greeting {
    NSBundle *fw = [NSBundle bundleForClass:self];
    NSString *path = [fw pathForResource:@"FramePodResources" ofType:@"bundle"];
    NSString *file = path ? [[NSBundle bundleWithPath:path] pathForResource:@"greeting" ofType:@"txt"] : nil;
    NSString *text = file ? [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:NULL] : nil;
    NSString *where = [fw.bundlePath.lastPathComponent stringByAppendingString:@""];
    return [NSString stringWithFormat:@"%@ (%@)", text ? [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"(no bundle)", where];
}
@end
