/* Minimal ObjC without Foundation/SDK: self-declared root class. */
int printf(const char *, ...);
typedef struct objc_class *Class;
typedef struct objc_object { Class isa; } *id;
id objc_alloc(Class); /* not used directly; clang may emit calls to it */

__attribute__((objc_root_class))
@interface Root { Class isa; }
+ (id)alloc;
- (id)init;
@end

@interface Counter : Root { int _value; }
- (void)increment;
- (int)value;
@end

@implementation Root
+ (id)alloc { extern void *calloc(unsigned long, unsigned long); id o = calloc(1, 64); *(Class *)o = (Class)self; return o; }
- (id)init { return self; }
@end

@implementation Counter
- (void)increment { _value++; }
- (int)value { return _value; }
@end

int main(void) {
    Counter *c = [[Counter alloc] init];
    for (int i = 0; i < 3; i++) [c increment];
    printf("counter value = %d\n", [c value]);
    return [c value] == 3 ? 42 : 1;
}
