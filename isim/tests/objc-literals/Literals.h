// Objective-C side of ObjCLiteralsTest: compiled with -fobjc-constant-literals (clang >= 23), so every literal in
// Literals.m is a static constant object (NSConstantArray, NSConstantDictionary, NSConstantIntegerNumber, ...).
// Collections are returned as `id`, so Swift receives the objects themselves (as Any) and bridges them with as?/as!.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Runs the Objective-C checks (PASS/FAIL lines on stdout); returns the number of failures.
int LitRunObjCTests(int *checks);
id LitPayload(void);                  // nested dictionary literal
id LitRuntimePayload(void);           // the same content, built at run time
id LitNumbers(void);                  // @[@1, @2, @3]
id LitStrings(void);                  // @[@"a", @"b"]
id LitEmptyArray(void);               // @[]
id LitEmptyDictionary(void);          // @{}
NSNumber *LitInt(void);               // @42
NSNumber *LitDouble(void);            // @2.5
NSNumber *LitFloat(void);             // @0.5f
NSNumber *LitBool(BOOL value);        // @YES / @NO
NSString *LitClassName(id object);
NS_ASSUME_NONNULL_END
