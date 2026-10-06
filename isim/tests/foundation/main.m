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

@interface Person : NSObject { NSString *_hidden; }
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSInteger age;
@property (nonatomic) double score;
@property (nonatomic, strong) Person *friend;
@end
@implementation Person
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_name forKey:@"name"]; [c encodeInteger:_age forKey:@"age"]; [c encodeObject:_friend forKey:@"friend"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) { _name = [c decodeObjectForKey:@"name"]; _age = [c decodeIntegerForKey:@"age"]; _friend = [c decodeObjectForKey:@"friend"]; }
    return self;
}
@end
@interface AgeWatcher : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *changes;
@end
@implementation AgeWatcher
- (instancetype)init { if ((self = [super init])) _changes = [NSMutableArray array]; return self; }
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [_changes addObject:[NSString stringWithFormat:@"%@->%@", change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]]];
}
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

        // formatters (explicit locales; the device region drives the defaults)
        NSLocale *enUS = [NSLocale localeWithLocaleIdentifier:@"en_US"], *ptBR = [NSLocale localeWithLocaleIdentifier:@"pt_BR"];
        NSDate *when = [NSDate dateWithTimeIntervalSince1970:1791212645];       // 2026-10-05 15:04:05 UTC
        NSDateFormatter *dfm = [NSDateFormatter new]; dfm.locale = enUS; dfm.timeZone = [NSTimeZone timeZoneWithName:@"America/Los_Angeles"];
        dfm.dateStyle = NSDateFormatterMediumStyle; dfm.timeStyle = NSDateFormatterShortStyle;
        CHECK([[dfm stringFromDate:when] isEqualToString:@"Oct 5, 2026, 8:04 AM"]);
        dfm.locale = ptBR; dfm.dateStyle = NSDateFormatterLongStyle; dfm.timeStyle = NSDateFormatterNoStyle;
        CHECK([[dfm stringFromDate:when] isEqualToString:@"5 de outubro de 2026"]);
        [dfm setLocalizedDateFormatFromTemplate:@"MMMMd"];
        CHECK([dfm.dateFormat isEqualToString:@"d 'de' MMMM"]);
        NSNumberFormatter *nfm = [NSNumberFormatter new]; nfm.locale = ptBR; nfm.numberStyle = NSNumberFormatterCurrencyStyle;
        CHECK([[nfm stringFromNumber:@1234.5] isEqualToString:@"R$ 1.234,50"] && [[nfm numberFromString:@"R$ 10,25"] doubleValue] == 10.25);
        nfm.locale = enUS; nfm.numberStyle = NSNumberFormatterSpellOutStyle;
        CHECK([[nfm stringFromNumber:@42] isEqualToString:@"forty-two"]);
        nfm.numberStyle = NSNumberFormatterOrdinalStyle;
        CHECK([[nfm stringFromNumber:@23] isEqualToString:@"23rd"]);
        CHECK([[[NSISO8601DateFormatter new] stringFromDate:when] isEqualToString:@"2026-10-05T15:04:05Z"]);
        NSByteCountFormatter *bcf = [NSByteCountFormatter new];
        CHECK([[bcf stringFromByteCount:999] isEqualToString:@"999 bytes"] && [[bcf stringFromByteCount:2500000000] isEqualToString:@"2.5 GB"]);
        NSListFormatter *lfm = [NSListFormatter new]; lfm.locale = ptBR;
        CHECK([[lfm stringFromItems:(@[@"a", @"b", @"c"])] isEqualToString:@"a, b e c"]);

        // key-value coding & observing
        Person *ada = [Person new]; ada.name = @"Ada"; ada.age = 36;
        Person *bob = [Person new]; bob.name = @"Bob"; bob.age = 25;
        CHECK([[ada valueForKey:@"name"] isEqualToString:@"Ada"] && [[ada valueForKey:@"age"] integerValue] == 36);
        [ada setValue:@37 forKey:@"age"]; [ada setValue:@"Ada L." forKey:@"name"]; [ada setValue:@2.5 forKey:@"score"];
        CHECK(ada.age == 37 && [ada.name isEqualToString:@"Ada L."] && ada.score == 2.5);
        [ada setValue:@"secret" forKey:@"hidden"];                                   // ivar access (_hidden)
        CHECK([[ada valueForKey:@"hidden"] isEqualToString:@"secret"]);
        ada.friend = bob;
        CHECK([[ada valueForKeyPath:@"friend.name"] isEqualToString:@"Bob"]);
        NSArray *people = @[ada, bob];
        CHECK([[people valueForKey:@"name"] isEqualToArray:(@[@"Ada L.", @"Bob"])] && [[people valueForKeyPath:@"@sum.age"] integerValue] == 62 && [[people valueForKeyPath:@"@max.age"] integerValue] == 37);
        CHECK([[@{@"k": @1} valueForKey:@"k"] intValue] == 1);
        AgeWatcher *watcher = [AgeWatcher new];
        [bob addObserver:watcher forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
        bob.age = 26; [bob setValue:@27 forKey:@"age"];
        CHECK(watcher.changes.count == 2 && [watcher.changes[0] isEqualToString:@"25->26"] && [watcher.changes[1] isEqualToString:@"26->27"]);
        [bob removeObserver:watcher forKeyPath:@"age"];
        bob.age = 30;
        CHECK(watcher.changes.count == 2);

        // more collections, sorting, predicates
        NSMutableIndexSet *is = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 3)];
        [is addIndex:9]; [is addIndex:5]; [is removeIndex:3];
        CHECK(is.count == 4 && is.firstIndex == 2 && is.lastIndex == 9 && [is containsIndex:5] && ![is containsIndex:3] && [is indexGreaterThanIndex:5] == 9);
        CHECK(([[@[@"a", @"b", @"c", @"d"] objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)]] isEqualToArray:(@[@"b", @"c"])]));
        NSMutableOrderedSet *os = [NSMutableOrderedSet orderedSetWithArray:@[@"x", @"y", @"x", @"z"]];
        [os insertObject:@"w" atIndex:0]; [os addObject:@"y"];
        CHECK(os.count == 4 && [os.array isEqualToArray:(@[@"w", @"x", @"y", @"z"])] && [os indexOfObject:@"y"] == 2);
        NSCountedSet *cs = [[NSCountedSet alloc] initWithArray:@[@"a", @"b", @"a"]];
        CHECK(cs.count == 2 && [cs countForObject:@"a"] == 2);
        NSCache *cache = [NSCache new]; cache.countLimit = 2;
        [cache setObject:@1 forKey:@"one"]; [cache setObject:@2 forKey:@"two"]; [cache setObject:@3 forKey:@"three"];
        CHECK([cache objectForKey:@"one"] == nil && [[cache objectForKey:@"three"] intValue] == 3);
        NSHashTable *weakTable = [NSHashTable weakObjectsHashTable];
        @autoreleasepool { NSObject *tmp = [NSObject new]; [weakTable addObject:tmp]; [weakTable addObject:ada]; CHECK(weakTable.count == 2); }
        CHECK(weakTable.count == 1);
        NSArray *byAge = [people sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"age" ascending:YES]]];
        CHECK(byAge.firstObject == bob);
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"age > %d AND name BEGINSWITH[c] %@", 28, @"b"];
        CHECK([pred evaluateWithObject:bob] && ![pred evaluateWithObject:ada]);
        CHECK([[people filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name CONTAINS 'L.' OR age IN {1, 2, 30}"]] count] == 2);
        CHECK(([[@[@"apple", @"Banana", @"cherry"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF LIKE[c] '*an*'"]] isEqualToArray:(@[@"Banana"])]));
        CHECK(([[NSPredicate predicateWithFormat:@"SELF MATCHES '[0-9]{3}'"] evaluateWithObject:@"123"] && [[NSPredicate predicateWithFormat:@"%K BETWEEN {20, 40}", @"age"] evaluateWithObject:ada]));
        CHECK([[NSPredicate predicateWithFormat:@"friend.name == 'Bob' && NOT (age < 30)"] evaluateWithObject:ada]);
        CHECK([[NSPredicate predicateWithFormat:@"age == $AGE"] evaluateWithObject:bob substitutionVariables:@{@"AGE": @30}]);

        // data, property lists, keyed archives, UUID, undo
        NSData *bytes = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
        CHECK(bytes.length == 5 && [[bytes base64EncodedStringWithOptions:0] isEqualToString:@"aGVsbG8="] && [[[NSData alloc] initWithBase64EncodedString:@"aGVsbG8=" options:0] isEqualToData:bytes]);
        CHECK([[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] isEqualToString:@"hello"]);
        NSDictionary *plist = @{ @"name": @"isim", @"n": @42, @"pi": @3.5, @"yes": @YES, @"blob": bytes, @"list": @[@1, @"two"], @"when": [NSDate dateWithTimeIntervalSince1970:0] };
        for (NSNumber *fmtNum in @[@(NSPropertyListBinaryFormat_v1_0), @(NSPropertyListXMLFormat_v1_0)]) {
            NSError *perr = nil; NSPropertyListFormat got = 0;
            NSData *pd = [NSPropertyListSerialization dataWithPropertyList:plist format:fmtNum.unsignedIntegerValue options:0 error:&perr];
            NSDictionary *pback = [NSPropertyListSerialization propertyListWithData:pd options:NSPropertyListImmutable format:&got error:&perr];
            CHECK(pd && got == fmtNum.unsignedIntegerValue && [pback isEqualToDictionary:plist]);
        }
        CHECK([[NSPropertyListSerialization propertyListWithData:[@"{ a = 1; b = (x, \"y z\"); }" dataUsingEncoding:NSUTF8StringEncoding] options:0 format:NULL error:NULL][@"b"] count] == 2);
        NSDictionary *graph = @{ @"people": people, @"tags": [NSSet setWithObjects:@"a", @"b", nil], @"uuid": [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"] };
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:graph requiringSecureCoding:NO error:NULL];
        NSDictionary *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        CHECK([[unarchived[@"people"] valueForKey:@"name"] isEqualToArray:(@[@"Ada L.", @"Bob"])] && [unarchived[@"tags"] count] == 2 && [[unarchived[@"uuid"] UUIDString] isEqualToString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"]);
        CHECK([[unarchived[@"people"][0] valueForKeyPath:@"friend.name"] isEqualToString:@"Bob"] && [unarchived[@"people"][0] friend] == [unarchived[@"people"] lastObject]);   // shared references survive
        NSUndoManager *um = [NSUndoManager new]; um.groupsByEvent = NO;
        NSMutableArray *stack = [NSMutableArray arrayWithObject:@"a"];
        [um registerUndoWithTarget:stack selector:@selector(removeObject:) object:@"b"]; [stack addObject:@"b"];
        [um undo];
        CHECK(stack.count == 1 && !um.canUndo);

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

        // NSFileHandle, streams, NSScanner, NSProcessInfo device facts
        NSString *fhPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"fh-test.txt"];
        [[NSData data] writeToFile:fhPath atomically:NO];
        NSFileHandle *wh = [NSFileHandle fileHandleForWritingAtPath:fhPath];
        [wh writeData:[@"hello world" dataUsingEncoding:NSUTF8StringEncoding]];
        CHECK(wh.offsetInFile == 11);
        [wh truncateFileAtOffset:5]; [wh closeFile];
        NSFileHandle *rh = [NSFileHandle fileHandleForReadingAtPath:fhPath];
        CHECK([[[NSString alloc] initWithData:[rh readDataToEndOfFile] encoding:NSUTF8StringEncoding] isEqualToString:@"hello"]);
        [rh seekToFileOffset:1];
        CHECK([[rh readDataOfLength:2] isEqualToData:[@"el" dataUsingEncoding:NSUTF8StringEncoding]]);
        CHECK([NSFileHandle fileHandleForReadingAtPath:@"/no/such/file"] == nil);
        NSOutputStream *ostr = [NSOutputStream outputStreamToMemory]; [ostr open];
        CHECK([ostr write:(const uint8_t *)"abc" maxLength:3] == 3);
        NSData *written = [ostr propertyForKey:NSStreamDataWrittenToMemoryStreamKey]; [ostr close];
        NSInputStream *istr = [NSInputStream inputStreamWithData:written]; [istr open];
        uint8_t ibuf[8]; NSInteger n1 = [istr read:ibuf maxLength:2], n2 = [istr read:ibuf + 2 maxLength:8], n3 = [istr read:ibuf maxLength:8];
        CHECK(n1 == 2 && n2 == 1 && n3 == 0 && memcmp(ibuf, "abc", 3) == 0 && istr.streamStatus == NSStreamStatusAtEnd);
        NSScanner *sc = [NSScanner scannerWithString:@"  width = 42, ratio 0x1F 3.5e2 rest"];
        NSString *word = nil; NSInteger ival = 0; unsigned hex = 0; double dval = 0;
        CHECK([sc scanUpToString:@" =" intoString:&word] && [word isEqualToString:@"width"]);
        CHECK([sc scanString:@"=" intoString:NULL] && [sc scanInteger:&ival] && ival == 42);
        CHECK([sc scanString:@"," intoString:NULL] && [sc scanCharactersFromSet:NSCharacterSet.letterCharacterSet intoString:&word] && [word isEqualToString:@"ratio"]);
        CHECK([sc scanHexInt:&hex] && hex == 31 && [sc scanDouble:&dval] && dval == 350 && !sc.atEnd);
        CHECK(![sc scanInteger:&ival] && [sc scanUpToCharactersFromSet:NSCharacterSet.newlineCharacterSet intoString:&word] && [word isEqualToString:@"rest"] && sc.atEnd);
        NSProcessInfo *pi = NSProcessInfo.processInfo;
        CHECK(pi.thermalState == NSProcessInfoThermalStateNominal && !pi.lowPowerModeEnabled && pi.physicalMemory >= (1ULL << 30));
        CHECK(pi.processorCount > 0 && pi.activeProcessorCount == pi.processorCount && pi.operatingSystemVersion.majorVersion >= 15);
        NSOperatingSystemVersion v15 = {15, 0, 0}, v99 = {99, 0, 0};
        CHECK([pi isOperatingSystemAtLeastVersion:v15] && ![pi isOperatingSystemAtLeastVersion:v99]);
        CHECK([pi.operatingSystemVersionString hasPrefix:@"Version "] && pi.globallyUniqueString.length > 30 && pi.environment[@"HOME"] != nil);

        NSLog(@"foundation test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
