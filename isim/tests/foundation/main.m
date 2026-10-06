// Foundation self-test for the isim runtime. Prints PASS/FAIL per check; exit code = failures.
#import <Foundation/Foundation.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } } while (0)

static int deallocs;
@interface Tracked : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, weak) Tracked *peer;
@property (nonatomic, strong) NSMutableArray *items;
@end
@implementation Tracked
- (void)dealloc { deallocs++; }
@end

static int initialized;
@interface Lazy : NSObject @end
@implementation Lazy
+ (void)initialize { if (self == [Lazy class]) initialized++; }
+ (int)value { return 7; }
@end

@interface NSString (Shout)
- (NSString *)shout;
@end
@implementation NSString (Shout)
- (NSString *)shout { return [[self uppercaseString] stringByAppendingString:@"!"]; }
@end

@interface Base : NSObject
- (NSString *)who;
@end
@implementation Base { int _baseIvar; }
- (instancetype)init { if ((self = [super init])) _baseIvar = 11; return self; }
- (NSString *)who { return [NSString stringWithFormat:@"base%d", _baseIvar]; }
@end
@interface Derived : Base { @public int _mine; }
@end
@implementation Derived
- (instancetype)init { if ((self = [super init])) _mine = 22; return self; }
- (NSString *)who { return [[super who] stringByAppendingFormat:@"+derived%d", _mine]; }
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // strings & formatting
        NSString *s = [NSString stringWithFormat:@"%@ %d %.2f %s %ld %05x %@", @"hi", 42, 3.14159, "c", (long)-7, 255, @[@1, @2]];
        CHECK([s hasPrefix:@"hi 42 3.14 c -7 000ff ("]);
        CHECK([@"héllo wörld" length] == 11);
        CHECK([[@"héllo" uppercaseString] isEqualToString:@"HÉLLO"] && [[@"ÇA VA" lowercaseString] isEqualToString:@"ça va"]);
        CHECK([@"a,b,,c" componentsSeparatedByString:@","].count == 4);
        CHECK([[@"/a/b/c.txt" lastPathComponent] isEqualToString:@"c.txt"]);
        CHECK([[@"/a/b/c.txt" pathExtension] isEqualToString:@"txt"]);
        CHECK([[@"Hello World" substringWithRange:NSMakeRange(6, 5)] isEqualToString:@"World"]);
        CHECK([@"emoji 😀!" length] == 9);
        NSMutableString *m = [NSMutableString stringWithString:@"abc"];
        [m appendFormat:@"-%d", 5]; [m insertString:@">" atIndex:0];
        CHECK([m isEqualToString:@">abc-5"]);
        CHECK([@"42" integerValue] == 42 && [@"2.5" doubleValue] == 2.5);
        CHECK([[@"shout" shout] isEqualToString:@"SHOUT!"]);               // category on a framework class
        CHECK([[@"straße" uppercaseString] isEqualToString:@"STRASSE"] && [[@"hello wide world" capitalizedString] isEqualToString:@"Hello Wide World"]);
        CHECK([@"Crème Brûlée" localizedStandardContainsString:@"creme brulee"] && [@"ABC" localizedCaseInsensitiveContainsString:@"b"]);
        CHECK([@"a-b-c" rangeOfString:@"-" options:NSBackwardsSearch range:NSMakeRange(0, 5)].location == 3);
        CHECK([[@"a.b.c" stringByReplacingOccurrencesOfString:@"." withString:@"/" options:0 range:NSMakeRange(2, 3)] isEqualToString:@"a.b/c"]);
        __block NSMutableArray *lines = [NSMutableArray array];
        [@"one\ntwo\r\nthree" enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) { [lines addObject:line]; }];
        CHECK([lines isEqualToArray:(@[@"one", @"two", @"three"])]);
        __block NSMutableArray *words = [NSMutableArray array];
        [@"Hi, it's a test." enumerateSubstringsInRange:NSMakeRange(0, 16) options:NSStringEnumerationByWords usingBlock:^(NSString *w, NSRange r, NSRange e, BOOL *stop) { [words addObject:w]; }];
        CHECK([words isEqualToArray:(@[@"Hi", @"it's", @"a", @"test"])]);

        // regular expressions (NSRegularExpression on the host's PCRE2)
        NSError *rerr = nil;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"(\\w+)@(?<host>\\w+)\\.com" options:NSRegularExpressionCaseInsensitive error:&rerr];
        NSString *mail = @"Mail ANA@Example.com or bob@test.com — é@x.com";
        CHECK(re && !rerr && re.numberOfCaptureGroups == 2);
        NSArray<NSTextCheckingResult *> *ms = [re matchesInString:mail options:0 range:NSMakeRange(0, mail.length)];
        CHECK(ms.count == 3 && [[mail substringWithRange:[ms[0] rangeAtIndex:1]] isEqualToString:@"ANA"]);
        CHECK([[mail substringWithRange:[ms[1] rangeWithName:@"host"]] isEqualToString:@"test"]);
        CHECK(ms[2].range.location == 39 && ms[2].range.length == 7);             // UTF-16 indices after a non-ASCII dash
        CHECK([[re stringByReplacingMatchesInString:mail options:0 range:NSMakeRange(0, mail.length) withTemplate:@"<$2:$1>"] isEqualToString:@"Mail <Example:ANA> or <test:bob> — <x:é>"]);
        CHECK([re numberOfMatchesInString:mail options:0 range:NSMakeRange(5, 10)] == 0);
        CHECK([NSRegularExpression regularExpressionWithPattern:@"(unclosed" options:0 error:&rerr] == nil && rerr.code == 2048);
        NSRegularExpression *empty = [NSRegularExpression regularExpressionWithPattern:@"x*" options:0 error:NULL];
        CHECK([empty numberOfMatchesInString:@"axxb" options:0 range:NSMakeRange(0, 4)] == 4);
        NSMutableString *mm = [@"2024-10-05" mutableCopy];
        [[NSRegularExpression regularExpressionWithPattern:@"(\\d+)-(\\d+)-(\\d+)" options:0 error:NULL] replaceMatchesInString:mm options:0 range:NSMakeRange(0, mm.length) withTemplate:@"$3/$2/$1 \\$1"];
        CHECK([mm isEqualToString:@"05/10/2024 $1"]);
        CHECK([@"Version 12.3" rangeOfString:@"\\d+\\.\\d+" options:NSRegularExpressionSearch].location == 8);
        CHECK([[NSRegularExpression escapedPatternForString:@"a.b*c"] isEqualToString:@"a\\.b\\*c"]);
        NSRegularExpression *ml = [NSRegularExpression regularExpressionWithPattern:@"^\\w+$" options:NSRegularExpressionAnchorsMatchLines error:NULL];
        CHECK([ml numberOfMatchesInString:@"ab\ncd\nef" options:0 range:NSMakeRange(0, 8)] == 3);
        NSDataDetector *dd = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber | NSTextCheckingTypeDate error:NULL];
        NSString *note = @"See https://isim.dev/docs, write to me@kolabs.dev or call +1 (555) 123-4567 on 2026-10-05.";
        NSArray<NSTextCheckingResult *> *found = [dd matchesInString:note options:0 range:NSMakeRange(0, note.length)];
        CHECK(found.count == 4 && found[0].resultType == NSTextCheckingTypeLink && [found[0].URL.absoluteString isEqualToString:@"https://isim.dev/docs"]);
        CHECK(found.count == 4 && [found[1].URL.absoluteString isEqualToString:@"mailto:me@kolabs.dev"] && [found[2].phoneNumber isEqualToString:@"+1 (555) 123-4567"]);
        CHECK(found.count == 4 && found[3].resultType == NSTextCheckingTypeDate && found[3].date != nil);

        // numbers & collections
        NSArray *arr = @[@3, @1, @2];
        NSArray *sorted = [arr sortedArrayUsingSelector:@selector(compare:)];
        CHECK([sorted isEqualToArray:(@[@1, @2, @3])]);
        NSDictionary *d = @{@"a": @1, @"b": @"two", @"c": @[@3]};
        CHECK([d[@"b"] isEqualToString:@"two"] && [d[@"a"] intValue] == 1 && d.count == 3);
        NSMutableDictionary *md = [d mutableCopy];
        md[@"a"] = nil; md[@"z"] = @26;
        CHECK(md.count == 3 && md[@"a"] == nil && [md[@"z"] intValue] == 26);
        int sum = 0; for (NSNumber *n in arr) sum += n.intValue;
        CHECK(sum == 6);
        NSUInteger keys = 0; for (NSString *k in d) keys += k.length;
        CHECK(keys == 3);
        CHECK(@[].count == 0 && @{}.count == 0);
        NSSet *set = [NSSet setWithArray:@[@1, @1, @2]];
        CHECK(set.count == 2 && [set containsObject:@2]);
        CHECK([@(3.5) doubleValue] == 3.5 && [@YES boolValue]);

        // ARC lifetimes, weak references, dealloc
        __weak Tracked *weakRef;
        @autoreleasepool {
            Tracked *a = [Tracked new], *b = [Tracked new];
            a.name = @"a"; a.peer = b; b.peer = a; a.items = [NSMutableArray arrayWithObject:b];
            weakRef = a;
            CHECK(weakRef != nil && a.peer == b);
        }
        CHECK(weakRef == nil);
        CHECK(deallocs == 2);

        // blocks
        __block int counter = 0;
        void (^inc)(int) = ^(int by) { counter += by; };
        NSMutableArray *blocks = [NSMutableArray array];
        for (int i = 1; i <= 3; i++) [blocks addObject:[^{ inc(i); } copy]];
        for (void (^b)(void) in blocks) b();
        CHECK(counter == 6);
        [arr enumerateObjectsUsingBlock:^(NSNumber *obj, NSUInteger idx, BOOL *stop) { counter += obj.intValue; }];
        CHECK(counter == 12);

        // +initialize, inheritance with ivar sliding, super calls
        CHECK(initialized == 0 && [Lazy value] == 7 && initialized == 1);
        Derived *dv = [Derived new];
        CHECK([[dv who] isEqualToString:@"base11+derived22"]);
        CHECK([dv isKindOfClass:[Base class]] && ![dv isMemberOfClass:[Base class]] && [dv respondsToSelector:@selector(who)]);
        CHECK(NSClassFromString(@"Derived") == [Derived class] && [NSStringFromClass([dv class]) isEqualToString:@"Derived"]);

        // run loop: timers, delayed performs, dispatch_after + main queue
        __block int fired = 0;
        [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer *t) { if (++fired == 3) [t invalidate]; }];
        __block BOOL afterRan = NO, asyncRan = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ afterRan = YES; });
        dispatch_async(dispatch_get_global_queue(0, 0), ^{ dispatch_async(dispatch_get_main_queue(), ^{ asyncRan = YES; }); });
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        CHECK(fired == 3 && afterRan && asyncRan);

        // bundle + Info.plist
        NSBundle *mb = NSBundle.mainBundle;
        CHECK([mb.bundleIdentifier isEqualToString:@"dev.kolabs.isim.foundation-test"]);
        CHECK([[mb objectForInfoDictionaryKey:@"UIRequiredDeviceCapabilities"] containsObject:@"arm64"]);
        CHECK([[mb.infoDictionary[@"Nested"][@"Flag"] description] isEqualToString:@"1"]);

        NSLog(@"foundation test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
