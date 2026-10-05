/* inheritance, super calls, class methods, float/many-arg dispatch, nil messaging, threads */
int printf(const char *, ...);
typedef struct objc_class *Class;
typedef struct objc_object { Class isa; } *id;
void *calloc(unsigned long, unsigned long);
typedef struct _opaque_pthread_t *pthread_t;
int pthread_create(pthread_t *, const void *, void *(*)(void *), void *);
int pthread_join(pthread_t, void **);

__attribute__((objc_root_class))
@interface Root { Class isa; }
+ (id)alloc; - (id)init; + (int)tag;
@end
@implementation Root
+ (id)alloc { id o = calloc(1, 64); *(Class *)o = (Class)self; return o; }
- (id)init { return self; }
+ (int)tag { return 1; }
@end

@interface Shape : Root { double _scale; }
- (double)area;
- (double)scaledArea:(double)k;
- (long)sum:(long)a :(long)b :(long)c :(long)d :(long)e :(long)f;
@end
@implementation Shape
- (id)init { if ((self = [super init])) _scale = 1.0; return self; }
- (double)area { return 0; }
- (double)scaledArea:(double)k { return [self area] * _scale * k; }
- (long)sum:(long)a :(long)b :(long)c :(long)d :(long)e :(long)f { return a + b + c + d + e + f; }
@end

@interface Square : Shape { double _side; }
- (id)initWithSide:(double)s;
@end
@implementation Square
+ (int)tag { return [super tag] + 10; }
- (id)initWithSide:(double)s { if ((self = [super init])) _side = s; return self; }
- (double)area { return _side * _side; }
@end

static void *worker(void *arg) {
    long total = 0;
    for (int i = 0; i < 100000; i++) total += [(Shape *)arg sum:1 :2 :3 :4 :5 :i & 1];
    return (void *)total;
}

int main(void) {
    Square *sq = [[Square alloc] initWithSide:3.0];
    double a = [sq scaledArea:2.0];
    long s = [sq sum:1 :2 :3 :4 :5 :6];
    int tag = [Square tag];
    Shape *nilShape = 0;
    double n = [nilShape area];
    pthread_t t[4]; void *r[4]; long total = 0;
    for (int i = 0; i < 4; i++) pthread_create(&t[i], 0, worker, sq);
    for (int i = 0; i < 4; i++) { pthread_join(t[i], &r[i]); total += (long)r[i]; }
    printf("scaledArea=%.1f sum=%ld tag=%d nil=%.1f threaded=%ld\n", a, s, tag, n, total);
    return (a == 18.0 && s == 21 && tag == 11 && n == 0.0 && total == 4 * (100000 * 15 + 50000)) ? 42 : 1;
}
