// Objective-C literal checks for isim, compiled with -fobjc-constant-literals: clang emits @[...], @{...}, @42,
// @2.5, @2.5f, @YES/@NO, @[] and @{} as static objects that isim's Foundation must treat as ordinary NSArray,
// NSDictionary and NSNumber instances. Prints PASS/FAIL per check.
#import "Literals.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <string.h>

CF_EXPORT CFTypeRef CFAutorelease(CFTypeRef cf);

static int failures, checks;
#define CHECK(...) do { checks++; if (__VA_ARGS__) printf("PASS  %s\n", #__VA_ARGS__); else { failures++; printf("FAIL  %s  (%s:%d)\n", #__VA_ARGS__, __FILE__, __LINE__); } } while (0)
// identity of objects (clang warns about == on literals)
static BOOL same(id a, id b) { return a == b; }

NSString *LitClassName(id o) { return NSStringFromClass(object_getClass(o)); }

// file-scope constant literals: only possible when the compiler emits them as static objects
static NSArray *gTable = @[@"zero", @"one", @"two"];
static NSDictionary *gConfig = @{@"retries": @3, @"ratio": @0.25, @"debug": @NO, @"tags": @[@"a", @"b"]};
static NSNumber *gAnswer = @42;

id LitNumbers(void) { return @[@1, @2, @3]; }
id LitStrings(void) { return @[@"a", @"b"]; }
NSNumber *LitInt(void) { return @42; }
NSNumber *LitDouble(void) { return @2.5; }
NSNumber *LitFloat(void) { return @0.5f; }
NSNumber *LitBool(BOOL v) { return v ? @YES : @NO; }
id LitEmptyArray(void) { return @[]; }
id LitEmptyDictionary(void) { return @{}; }

id LitPayload(void) {
    return @{
        @"name": @"isim", @"n": @42, @"neg": @-7, @"big": @18446744073709551615ull, @"pi": @2.5, @"f": @0.5f,
        @"yes": @YES, @"no": @NO, @"list": @[@1, @"two", @3.5, @[]], @"nested": @{@"z": @[@2.0, @{}]}, @"empty": @{},
    };
}
id LitRuntimePayload(void) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[[NSString stringWithFormat:@"%@", @"name"]] = [NSString stringWithUTF8String:"isim"];
    d[@"n"] = [NSNumber numberWithInt:42];
    d[@"neg"] = [NSNumber numberWithLong:-7];
    d[@"big"] = [NSNumber numberWithUnsignedLongLong:18446744073709551615ull];
    d[@"pi"] = [NSNumber numberWithDouble:2.5];
    d[@"f"] = [NSNumber numberWithFloat:0.5f];
    d[@"yes"] = [NSNumber numberWithBool:YES];
    d[@"no"] = [NSNumber numberWithBool:NO];
    id one = [NSNumber numberWithInt:1], two = [@"tw" stringByAppendingString:@"o"], f35 = [NSNumber numberWithDouble:3.5];
    id list[] = { one, two, f35, [NSArray array] };
    d[@"list"] = [NSArray arrayWithObjects:list count:4];
    NSArray *z = [NSArray arrayWithObjects:[NSNumber numberWithDouble:2.0], [NSDictionary dictionary], nil];
    d[@"nested"] = [NSDictionary dictionaryWithObject:z forKey:@"z"];
    d[@"empty"] = [NSDictionary dictionary];
    return [d copy];
}

static NSUInteger retainCountOf(id o) { return ((NSUInteger (*)(id, SEL))objc_msgSend)(o, sel_registerName("retainCount")); }
static BOOL raises(void (^block)(void)) { @try { block(); } @catch (NSException *e) { return YES; } return NO; }

static void testClasses(void) {
    // the compiler really emitted constant objects (otherwise this binary does not test anything)
    CHECK([LitClassName(@[@1]) isEqual:@"NSConstantArray"]);
    CHECK([LitClassName(@{@"k": @1}) isEqual:@"NSConstantDictionary"]);
    CHECK([LitClassName(@42) isEqual:@"NSConstantIntegerNumber"]);
    CHECK([LitClassName(@2.5) isEqual:@"NSConstantDoubleNumber"]);
    CHECK([LitClassName(@2.5f) isEqual:@"NSConstantFloatNumber"]);
    CHECK([LitClassName(@YES) isEqual:@"__NSCFBoolean"]);
    CHECK([LitClassName(@[]) isEqual:@"__NSArray0"]);
    CHECK([LitClassName(@{}) isEqual:@"__NSDictionary0"]);
    // ... and they are ordinary Foundation objects
    CHECK([@[@1] isKindOfClass:[NSArray class]] && ![@[@1] isKindOfClass:[NSMutableArray class]]);
    CHECK([@{@"k": @1} isKindOfClass:[NSDictionary class]] && ![@{@"k": @1} isKindOfClass:[NSMutableDictionary class]]);
    CHECK([@42 isKindOfClass:[NSNumber class]] && [@42 isKindOfClass:[NSValue class]]);
    CHECK([@2.5 isKindOfClass:[NSNumber class]] && [@2.5f isKindOfClass:[NSNumber class]] && [@YES isKindOfClass:[NSNumber class]]);
    CHECK([@[] isKindOfClass:[NSArray class]] && [@{} isKindOfClass:[NSDictionary class]]);
    CHECK([@[@1] respondsToSelector:@selector(objectAtIndex:)] && [@[@1] conformsToProtocol:@protocol(NSFastEnumeration)]);
    // singletons
    CHECK(same(@YES, (__bridge id)kCFBooleanTrue) && same(@NO, (__bridge id)kCFBooleanFalse));
    CHECK(same(@YES, [NSNumber numberWithBool:YES]) && same(@NO, [NSNumber numberWithBool:NO]));
    CHECK(same([[NSNumber alloc] initWithBool:YES], @YES));
    CHECK(CFBooleanGetValue(kCFBooleanTrue) && !CFBooleanGetValue(kCFBooleanFalse));
    CHECK(same(@[], LitEmptyArray()) && same(@{}, LitEmptyDictionary()));
    CHECK(same(LitNumbers(), LitNumbers()));    // the same static object every time
}

static void testArrays(void) {
    NSArray *a = @[@"b", @"a", @"c"];
    CHECK(a.count == 3 && [a[0] isEqual:@"b"] && [[a objectAtIndex:2] isEqual:@"c"]);
    CHECK([a.firstObject isEqual:@"b"] && [a.lastObject isEqual:@"c"]);
    CHECK([a indexOfObject:@"a"] == 1 && [a indexOfObject:@"zz"] == NSNotFound && [a containsObject:@"c"]);
    CHECK([[a componentsJoinedByString:@","] isEqual:@"b,a,c"]);
    CHECK([[a sortedArrayUsingSelector:@selector(compare:)] isEqual:@[@"a", @"b", @"c"]]);
    CHECK([[a subarrayWithRange:NSMakeRange(1, 2)] isEqual:@[@"a", @"c"]]);
    CHECK([[a arrayByAddingObject:@"d"] count] == 4 && [[a arrayByAddingObjectsFromArray:@[@"x", @"y"]] count] == 5);
    CHECK(raises(^{ (void)[a objectAtIndex:3]; }));
    CHECK(raises(^{ [(NSMutableArray *)a addObject:@"x"]; }));     // immutable: unrecognized selector
    __block NSMutableString *seen = [NSMutableString string];
    [a enumerateObjectsUsingBlock:^(id o, NSUInteger i, BOOL *stop) { [seen appendFormat:@"%@%lu", o, (unsigned long)i]; }];
    CHECK([seen isEqual:@"b0a1c2"]);
    CHECK([[a.reverseObjectEnumerator allObjects] isEqual:@[@"c", @"a", @"b"]]);
    CHECK([[a.objectEnumerator allObjects] isEqual:a]);
    CHECK([[a filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != 'a'"]] isEqual:@[@"b", @"c"]]);
    CHECK([[@[@"a", @"bb", @"ccc"] valueForKey:@"length"] isEqual:@[@1, @2, @3]]);
    CHECK([[@[@1, @2, @3] valueForKeyPath:@"@sum.self"] intValue] == 6);
    CHECK([[@[@4, @9, @2] valueForKeyPath:@"@max.self"] intValue] == 9);
    CHECK([gTable[2] isEqual:@"two"] && gTable.count == 3);
    // fast enumeration, including break and nesting
    NSMutableString *s = [NSMutableString string];
    for (NSString *x in a) [s appendString:x];
    CHECK([s isEqual:@"bac"]);
    int n = 0; for (id x in @[@1, @2, @3, @4]) { (void)x; if (++n == 2) break; }
    CHECK(n == 2);
    int sum = 0; for (NSArray *row in @[@[@1, @2], @[@3], @[]]) for (NSNumber *v in row) sum += v.intValue;
    CHECK(sum == 6);
    int none = 0; for (id x in @[]) { (void)x; none++; }
    CHECK(none == 0 && @[].count == 0 && @[].firstObject == nil);
}

static void testDictionaries(void) {
    NSDictionary *d = @{@"b": @2, @"a": @1, @"c": @3, @"é": @4};
    CHECK(d.count == 4 && [d[@"a"] isEqual:@1] && [d[@"c"] intValue] == 3 && [d[@"é"] intValue] == 4);
    NSString *runtimeKey = [@"" stringByAppendingFormat:@"%c", 'b'];      // a different object than the literal key
    CHECK([[d objectForKey:runtimeKey] isEqual:@2]);
    CHECK(d[@"zz"] == nil && [d objectForKey:@"A"] == nil);
    CHECK([[[d allKeys] sortedArrayUsingSelector:@selector(compare:)] isEqual:@[@"a", @"b", @"c", @"é"]]);
    CHECK([[[d allValues] sortedArrayUsingSelector:@selector(compare:)] isEqual:@[@1, @2, @3, @4]]);
    __block int total = 0, keys = 0;
    [d enumerateKeysAndObjectsUsingBlock:^(id k, NSNumber *v, BOOL *stop) { total += v.intValue; keys++; }];
    CHECK(total == 10 && keys == 4);
    NSMutableSet *ks = [NSMutableSet set];
    for (NSString *k in d) [ks addObject:k];
    CHECK(ks.count == 4 && [ks containsObject:@"é"]);
    CHECK([[[d keyEnumerator] allObjects] count] == 4 && [[[d objectEnumerator] allObjects] count] == 4);
    CHECK([[d keysSortedByValueUsingSelector:@selector(compare:)] isEqual:@[@"a", @"b", @"c", @"é"]]);
    CHECK([[d valueForKey:@"b"] isEqual:@2]);
    CHECK([[@{@"a": @{@"b": @{@"c": @"deep"}}} valueForKeyPath:@"a.b.c"] isEqual:@"deep"]);
    CHECK([gConfig[@"retries"] intValue] == 3 && [gConfig[@"ratio"] doubleValue] == 0.25 && ![gConfig[@"debug"] boolValue] && [gConfig[@"tags"] count] == 2);
    CHECK(@{}.count == 0 && @{}[@"x"] == nil && [@{}.allKeys count] == 0);
    int none = 0; for (id k in @{}) { (void)k; none++; }
    CHECK(none == 0);
}

static void testNumbers(void) {
    CHECK([@42 intValue] == 42 && [@42 integerValue] == 42 && [@42 doubleValue] == 42.0 && [@42 boolValue]);
    CHECK([@-7 intValue] == -7 && [@-7 longLongValue] == -7 && strcmp([@-7 objCType], "i") == 0);
    CHECK([@18446744073709551615ull unsignedLongLongValue] == 18446744073709551615ull && strcmp([@18446744073709551615ull objCType], "Q") == 0);
    CHECK([[@18446744073709551615ull description] isEqual:@"18446744073709551615"]);
    CHECK([@'c' intValue] == 99 && strcmp([@'c' objCType], "c") == 0);
    CHECK(strcmp([@((short)3) objCType], "s") == 0 && strcmp([@((unsigned char)3) objCType], "C") == 0 && strcmp([@42l objCType], "q") == 0);
    CHECK(strcmp([@42u objCType], "I") == 0 && [@42u unsignedIntValue] == 42);
    CHECK([@2.5 doubleValue] == 2.5 && [@2.5 intValue] == 2 && strcmp([@2.5 objCType], "d") == 0);
    CHECK([@0.5f floatValue] == 0.5f && strcmp([@0.5f objCType], "f") == 0);
    CHECK([[@0.1f description] isEqual:@"0.1"] && [[@2.5 description] isEqual:@"2.5"] && [[@42 description] isEqual:@"42"]);
    CHECK([[@YES description] isEqual:@"1"] && [[@NO stringValue] isEqual:@"0"] && [@YES boolValue] && ![@NO boolValue] && [@YES intValue] == 1);
    CHECK(strcmp([@YES objCType], "c") == 0);
    CHECK([[NSString stringWithFormat:@"%@ %@ %@", @42, @2.5, @YES] isEqual:@"42 2.5 1"]);
    // ordering against runtime-created numbers
    CHECK([@1 compare:@2.5] == NSOrderedAscending && [@2.5 compare:[NSNumber numberWithInt:2]] == NSOrderedDescending);
    CHECK([@-1 compare:@18446744073709551615ull] == NSOrderedAscending && [@18446744073709551615ull compare:@-1] == NSOrderedDescending);
    CHECK([@0.5f compare:@0.5] == NSOrderedSame && [@NO compare:@1] == NSOrderedAscending);
    CHECK([gAnswer isEqual:@42] && same(gAnswer, LitInt()));
    NSNumberFormatter *f = [NSNumberFormatter new]; f.numberStyle = NSNumberFormatterDecimalStyle; f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    CHECK([[f stringFromNumber:@1234] isEqual:@"1,234"] && [[f stringFromNumber:@2.5] isEqual:@"2.5"]);
}

static void testEquality(void) {
    NSDictionary *lit = LitPayload(), *rt = LitRuntimePayload();
    CHECK([lit isEqual:rt] && [rt isEqual:lit] && [lit isEqualToDictionary:rt]);
    CHECK(lit.hash == rt.hash);
    NSArray *la = @[@1, @"two", @3.5, @[]], *ra = rt[@"list"];
    CHECK([la isEqual:ra] && [ra isEqual:la] && [la isEqualToArray:ra] && la.hash == ra.hash);
    CHECK(![@[@1, @2] isEqual:@[@2, @1]] && ![@{@"a": @1} isEqual:@{@"a": @2}]);
    struct { NSNumber *lit, *rt; } nums[] = {
        { @42, [NSNumber numberWithInt:42] }, { @42, [NSNumber numberWithLongLong:42] }, { @-7, [NSNumber numberWithInteger:-7] },
        { @2.5, [NSNumber numberWithDouble:2.5] }, { @0.5f, [NSNumber numberWithFloat:0.5f] }, { @2.0, [NSNumber numberWithInt:2] },
        { @YES, [NSNumber numberWithInt:1] }, { @NO, [NSNumber numberWithDouble:0] }, { @'c', [NSNumber numberWithChar:'c'] },
        { @18446744073709551615ull, [NSNumber numberWithUnsignedLongLong:18446744073709551615ull] },
    };
    BOOL allEqual = YES;
    for (size_t i = 0; i < sizeof nums / sizeof *nums; i++) {
        BOOL ok = [nums[i].lit isEqual:nums[i].rt] && [nums[i].rt isEqual:nums[i].lit] && nums[i].lit.hash == nums[i].rt.hash &&
                  [nums[i].lit isEqualToNumber:nums[i].rt] && [nums[i].lit compare:nums[i].rt] == NSOrderedSame;
        if (!ok) { printf("  mismatch: %s vs %s\n", nums[i].lit.description.UTF8String, nums[i].rt.description.UTF8String); allEqual = NO; }
    }
    CHECK(allEqual);
    CHECK(![@42 isEqual:@43] && ![@2.5 isEqual:@2] && ![@42 isEqual:@"42"] && ![@[] isEqual:@{}]);
    CHECK([@[] isEqual:[NSArray array]] && [[NSArray array] isEqual:@[]] && [@{} isEqual:[NSDictionary dictionary]]);
    // as keys and members of runtime collections
    NSMutableDictionary *byNumber = [NSMutableDictionary dictionary];
    byNumber[[NSNumber numberWithInt:42]] = @"runtime key";
    CHECK([byNumber[@42] isEqual:@"runtime key"]);
    byNumber[@7] = @"literal key";
    CHECK([byNumber[[NSNumber numberWithInt:7]] isEqual:@"literal key"]);
    NSSet *set = [NSSet setWithObjects:@1, [NSNumber numberWithInt:1], @2.5, [NSNumber numberWithDouble:2.5], @[@1], [NSArray arrayWithObject:@1], nil];
    CHECK(set.count == 3);
    CHECK([[NSSet setWithArray:@[@"x", @"y", @"x"]] count] == 2);
    NSArray *pair = @[@1, @2]; NSDictionary *one = @{@"a": @1};
    CHECK([[NSArray arrayWithArray:pair] isEqual:pair] && [[NSDictionary dictionaryWithDictionary:one] isEqual:one]);
}

static void testCopies(void) {
    NSArray *a = @[@1, @2];
    NSDictionary *d = @{@"k": @"v"};
    CHECK(same([a copy], a) && same([d copy], d) && same([@42 copy], @42) && same([@[] copy], @[]) && same([@YES copy], @YES));
    NSMutableArray *ma = [a mutableCopy];
    CHECK([ma isKindOfClass:[NSMutableArray class]] && [ma isEqual:a]);
    [ma addObject:@3]; [ma removeObjectAtIndex:0];
    CHECK([ma isEqual:@[@2, @3]] && a.count == 2 && [a[0] isEqual:@1]);
    NSMutableDictionary *md = [d mutableCopy];
    md[@"k2"] = @"v2"; md[@"k"] = @"changed";
    CHECK(md.count == 2 && [md[@"k"] isEqual:@"changed"] && [d[@"k"] isEqual:@"v"]);
    NSMutableArray *me = [@[] mutableCopy]; [me addObject:@1];
    NSMutableDictionary *mde = [@{} mutableCopy]; mde[@"a"] = @1;
    CHECK(me.count == 1 && mde.count == 1 && @[].count == 0 && @{}.count == 0);
    CHECK([[NSArray arrayWithArray:a] isEqual:a] && [[[NSMutableArray alloc] initWithArray:a] count] == 2);
}

static void testSerialization(void) {
    NSDictionary *p = LitPayload();
    // property lists: XML and binary
    for (int i = 0; i < 2; i++) {
        NSPropertyListFormat fmt = i ? NSPropertyListBinaryFormat_v1_0 : NSPropertyListXMLFormat_v1_0;
        NSError *err = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:p format:fmt options:0 error:&err];
        CHECK(data != nil && err == nil);
        NSDictionary *back = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&err];
        CHECK([back isEqual:p] && [back[@"yes"] isEqual:@YES] && [back[@"big"] unsignedLongLongValue] == 18446744073709551615ull);
        if (!i) {
            NSString *xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            CHECK([xml containsString:@"<true/>"] && [xml containsString:@"<false/>"] && [xml containsString:@"<real>2.5</real>"] &&
                  [xml containsString:@"<integer>42</integer>"] && [xml containsString:@"<integer>18446744073709551615</integer>"]);
        }
    }
    // keyed archives: the literals archive as NSDictionary / NSArray / NSNumber, not as their constant classes
    NSError *err = nil;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:p requiringSecureCoding:YES error:&err];
    CHECK(archive != nil && err == nil);
    NSString *plist = [[NSString alloc] initWithData:[NSPropertyListSerialization dataWithPropertyList:
        [NSPropertyListSerialization propertyListWithData:archive options:0 format:NULL error:NULL] format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL]
        encoding:NSUTF8StringEncoding];
    CHECK(![plist containsString:@"NSConstant"] && ![plist containsString:@"__NS"]);
    NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSNumber class], [NSString class], nil];
    NSDictionary *unarchived = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:archive error:&err];
    CHECK([unarchived isEqual:p] && err == nil);
    CHECK([unarchived[@"nested"][@"z"][0] isEqual:@2.0] && [unarchived[@"list"][3] count] == 0);
    // description / debugging output matches runtime-built collections
    CHECK([@[@1, @"a"].description isEqual:[NSArray arrayWithObjects:[NSNumber numberWithInt:1], @"a", nil].description]);
    CHECK([@{@"k": @"v"}.description isEqual:[NSDictionary dictionaryWithObject:@"v" forKey:@"k"].description]);
}

static void testImmortal(void) {
    NSArray *a = LitNumbers();
    NSNumber *n = @42;
    id objects[] = { a, @{@"k": @1}, n, @2.5, @0.5f, @YES, @NO, @[], @{} };
    BOOL ok = YES;
    for (size_t i = 0; i < sizeof objects / sizeof *objects; i++) {
        id o = objects[i];
        if (retainCountOf(o) != NSUIntegerMax || (NSUInteger)CFGetRetainCount((__bridge CFTypeRef)o) != NSUIntegerMax) ok = NO;
        for (int k = 0; k < 1000; k++) CFRetain((__bridge CFTypeRef)o);
        for (int k = 0; k < 5000; k++) CFRelease((__bridge CFTypeRef)o);   // more releases than retains: still alive
        if (retainCountOf(o) != NSUIntegerMax) ok = NO;
        @autoreleasepool { for (int k = 0; k < 100; k++) CFAutorelease(CFRetain((__bridge CFTypeRef)o)); }
    }
    CHECK(ok);
    CHECK(a.count == 3 && [a[2] intValue] == 3 && n.intValue == 42);
    __weak NSArray *weakA;
    @autoreleasepool { NSArray *strong = @[@"w"]; weakA = strong; }
    CHECK(weakA != nil && [weakA[0] isEqual:@"w"]);
    __weak NSNumber *weakYes;
    @autoreleasepool { NSNumber *strong = @YES; weakYes = strong; }
    CHECK(same(weakYes, @YES));
}

int LitRunObjCTests(int *outChecks) {
    @autoreleasepool {
        testClasses();
        testArrays();
        testDictionaries();
        testNumbers();
        testEquality();
        testCopies();
        testSerialization();
        testImmortal();
    }
    fflush(stdout);
    *outChecks = checks;
    return failures;
}
