// ObjCPlugin.framework: loaded at run time by DlopenTest (not linked). Exercises initializers, +load, categories,
// thread-local variables, a dependency of its own (libPluginHelper.dylib) and resources in its bundle.
#import <Foundation/Foundation.h>

int helper_value(void);
int plugin_constructor_runs;
static __thread int plugin_tls = 5;

__attribute__((constructor)) static void plugin_init(void) { plugin_constructor_runs++; }

int plugin_value(void) { return helper_value() + 2; }
int *plugin_tls_address(void) { return &plugin_tls; }

@interface ObjCPluginPrincipal : NSObject
+ (int)loads;
- (NSString *)greeting;
@end
static int load_calls;
@implementation ObjCPluginPrincipal
+ (void)load { load_calls++; }
+ (int)loads { return load_calls; }
- (NSString *)greeting {
    NSBundle *b = [NSBundle bundleForClass:[self class]];
    NSString *path = [b pathForResource:@"greeting" ofType:@"txt"];
    return [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
@end
@interface ObjCPluginOther : NSObject @end
@implementation ObjCPluginOther @end

@implementation NSString (ObjCPlugin)
- (NSString *)plugin_shout { return [self uppercaseString]; }
@end
