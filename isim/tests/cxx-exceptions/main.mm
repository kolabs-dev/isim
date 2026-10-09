// C++ exceptions self-test for isim (Objective-C++, -fexceptions, libc++/libc++abi): throw / try / catch by type,
// base class, pointer and catch (...), rethrow, destructors while unwinding, exceptions thrown by libc++ itself
// (vector::at, stoi, bad_cast, bad_variant_access, bad_alloc), exception_ptr, nested exceptions, other threads,
// and mixing with Objective-C exceptions in both directions. Prints PASS/FAIL per check; exit code = failures.
// `CxxExceptionsTest uncaught` throws a C++ exception nothing catches (std::terminate's report, SIGABRT).
#import <Foundation/Foundation.h>
#include <cstdio>
#include <cstring>
#include <exception>
#include <memory>
#include <new>
#include <optional>
#include <stdexcept>
#include <string>
#include <system_error>
#include <thread>
#include <typeinfo>
#include <variant>
#include <vector>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } } while (0)

// ---------------------------------------------------------------- C++ only
struct AppError : std::runtime_error {
    int code;
    AppError(const char *m, int c) : std::runtime_error(m), code(c) {}
};
struct Derived : AppError { Derived() : AppError("derived", 9) {} };
struct Plain { int v; };

static std::vector<std::string> trail;
struct Guard {                                  // destructors run while the stack unwinds
    std::string name;
    explicit Guard(std::string n) : name(std::move(n)) {}
    ~Guard() { trail.push_back("~" + name + (std::uncaught_exceptions() ? "!" : "")); }
};

__attribute__((noinline)) static void thrower(int kind) {
    Guard g("thrower");
    switch (kind) {
    case 1: throw 42;
    case 2: throw AppError("app failed", 7);
    case 3: throw Derived();
    case 4: throw Plain{5};
    case 5: throw std::string("a string");
    case 6: { static Plain p{6}; throw &p; }
    case 7: throw 2.5;
    }
}
__attribute__((noinline)) static int frames(int depth, int kind) {
    Guard g("frame" + std::to_string(depth));
    if (depth == 0) { thrower(kind); return 0; }
    return frames(depth - 1, kind) + 1;
}
static std::string catchKind(int kind) {
    try { frames(3, kind); return "none"; }
    catch (int v) { return "int " + std::to_string(v); }
    catch (const Derived &e) { return std::string("Derived ") + e.what() + " " + std::to_string(e.code); }
    catch (const AppError &e) { return std::string("AppError ") + e.what() + " " + std::to_string(e.code); }
    catch (Plain p) { return "Plain " + std::to_string(p.v); }
    catch (const std::string &s) { return "string " + s; }
    catch (Plain *p) { return "Plain* " + std::to_string(p->v); }
    catch (...) { return "other"; }
}

static void testBasics() {
    CHECK(catchKind(0) == "none");
    CHECK(catchKind(1) == "int 42");
    CHECK(catchKind(2) == "AppError app failed 7");
    CHECK(catchKind(3) == "Derived derived 9");
    CHECK(catchKind(4) == "Plain 5");
    CHECK(catchKind(5) == "string a string");
    CHECK(catchKind(6) == "Plain* 6");
    CHECK(catchKind(7) == "other");

    // every frame's destructor ran, innermost first, while the exception was in flight
    trail.clear();
    catchKind(2);
    CHECK(trail.size() == 5 && trail[0] == "~thrower!" && trail[1] == "~frame0!" && trail[4] == "~frame3!");

    // catching through a base class: std::exception& sees what()
    try { thrower(3); } catch (const std::exception &e) { CHECK(!strcmp(e.what(), "derived")); }
    try { thrower(2); } catch (const std::runtime_error &e) { CHECK(!strcmp(e.what(), "app failed")); }

    // rethrow: `throw;` keeps the same object
    const void *first = nullptr, *again = nullptr;
    try {
        try { thrower(2); }
        catch (AppError &e) { first = &e; e.code = 11; throw; }
    } catch (AppError &e) { again = &e; CHECK(e.code == 11); }
    CHECK(first && first == again);

    // nested try blocks: the inner handler does not match, the outer one does
    std::string where;
    try {
        try { thrower(1); } catch (const std::string &) { where = "inner"; }
    } catch (int) { where = "outer"; }
    CHECK(where == "outer");

    // throwing from a handler replaces the exception; both handlers ran
    where.clear();
    try {
        try { thrower(1); } catch (int) { where += "first,"; throw std::logic_error("second"); }
    } catch (const std::logic_error &e) { where += e.what(); }
    CHECK(where == "first,second");

    // function-try-block on a constructor rethrows automatically
    struct Fails { Fails() try { throw std::invalid_argument("ctor"); } catch (...) { trail.push_back("ctor handler"); } };
    trail.clear();
    try { Fails f; (void)f; } catch (const std::invalid_argument &e) { trail.push_back(e.what()); }
    CHECK(trail.size() == 2 && trail[0] == "ctor handler" && trail[1] == "ctor");

    // std::uncaught_exceptions() and current_exception() outside handlers
    CHECK(std::uncaught_exceptions() == 0);
    CHECK(!std::current_exception());
}

// ---------------------------------------------------------------- thrown by libc++
struct Base { virtual ~Base() = default; };
static char *volatile sink;           // allocations that escape (unused ones may be elided)
struct Other : Base {};
static void testLibrary() {
    std::vector<int> v{1, 2, 3};
    try { (void)v.at(10); CHECK(!"vector::at did not throw"); } catch (const std::out_of_range &e) { CHECK(strstr(e.what(), "vector") != nullptr); }
    try { (void)std::stoi("not a number"); CHECK(!"stoi did not throw"); } catch (const std::invalid_argument &e) { CHECK(!strcmp(e.what(), "stoi: no conversion")); }
    try { (void)std::stoi("99999999999999999999"); CHECK(!"stoi did not throw"); } catch (const std::out_of_range &) { CHECK(true); }
    try { (void)std::string("abc").substr(5); CHECK(!"substr did not throw"); } catch (const std::out_of_range &) { CHECK(true); }

    Base b; Base &rb = b;
    try { (void)dynamic_cast<Other &>(rb); CHECK(!"dynamic_cast did not throw"); } catch (const std::bad_cast &e) { CHECK(typeid(e) == typeid(std::bad_cast)); }
    std::variant<int, std::string> var = 3;
    try { (void)std::get<std::string>(var); CHECK(!"get did not throw"); } catch (const std::bad_variant_access &) { CHECK(true); }
    std::optional<int> none;
    try { (void)none.value(); CHECK(!"value() did not throw"); } catch (const std::bad_optional_access &) { CHECK(true); }
    try { std::shared_ptr<int> p(std::weak_ptr<int>{}); CHECK(!"shared_ptr did not throw"); } catch (const std::bad_weak_ptr &) { CHECK(true); }
    try { throw std::system_error(std::make_error_code(std::errc::invalid_argument), "op"); }
    catch (const std::system_error &e) { CHECK(e.code() == std::errc::invalid_argument && strncmp(e.what(), "op:", 3) == 0); }
    volatile size_t huge = (size_t)1 << 62;
    try { sink = new char[huge]; CHECK(!"new did not throw"); } catch (const std::bad_alloc &) { CHECK(true); }
    sink = new (std::nothrow) char[huge];
    CHECK(sink == nullptr);

    // RTTI: typeid names and polymorphic typeid
    Other o; Base &ro = o;
    CHECK(typeid(ro) == typeid(Other));
    CHECK(!strcmp(typeid(int).name(), "i"));
    CHECK(dynamic_cast<Other *>(&ro) == &o);
}

// ---------------------------------------------------------------- exception_ptr, nested
static void testExceptionPtr() {
    std::exception_ptr ep;
    try { thrower(2); } catch (...) { ep = std::current_exception(); }
    CHECK(ep != nullptr);
    try { std::rethrow_exception(ep); } catch (const AppError &e) { CHECK(e.code == 7); }
    auto made = std::make_exception_ptr(std::length_error("made"));
    try { std::rethrow_exception(made); } catch (const std::length_error &e) { CHECK(!strcmp(e.what(), "made")); }

    try {
        try { thrower(2); }
        catch (...) { std::throw_with_nested(std::runtime_error("outer")); }
    } catch (const std::runtime_error &e) {
        CHECK(!strcmp(e.what(), "outer"));
        try { std::rethrow_if_nested(e); CHECK(!"no nested exception"); }
        catch (const AppError &inner) { CHECK(inner.code == 7); }
    }
}

// ---------------------------------------------------------------- threads
struct Local { int *count; ~Local() { ++*count; } };
__attribute__((noinline)) static void threadThrower(int i, int *destroyed) { Local l{destroyed}; throw i; }
static void testThreads() {
    std::string seen[4];
    int ints[4] = {}, destroyed[4] = {};
    std::vector<std::thread> ts;
    for (int i = 0; i < 4; i++)
        ts.emplace_back([i, &seen, &ints, &destroyed] {
            for (int k = 0; k < 50; k++) {
                try { if (k % 2) throw AppError("t", i); else threadThrower(i, &destroyed[i]); }
                catch (const AppError &e) { seen[i] = "AppError " + std::to_string(e.code); }
                catch (int v) { ints[i] += v == i; }
            }
        });
    for (auto &t : ts) t.join();
    CHECK(seen[0] == "AppError 0" && seen[3] == "AppError 3");
    CHECK(ints[0] == 25 && ints[3] == 25 && destroyed[1] == 25 && destroyed[2] == 25);

    // an exception_ptr carried to another thread
    std::exception_ptr ep;
    std::thread([&ep] { try { throw std::domain_error("from thread"); } catch (...) { ep = std::current_exception(); } }).join();
    try { std::rethrow_exception(ep); } catch (const std::domain_error &e) { CHECK(!strcmp(e.what(), "from thread")); }
}

// ---------------------------------------------------------------- with Objective-C
@interface Thrower : NSObject
- (void)throwCxx:(int)kind;
- (void)throwObjC;
@end
@implementation Thrower
- (void)throwCxx:(int)kind { Guard g("method"); thrower(kind); }
- (void)throwObjC { Guard g("objc"); [NSException raise:@"ObjCError" format:@"from %@", @"objc"]; }
@end

static void testMixed() {
    Thrower *t = [Thrower new];

    // a C++ exception through an Objective-C method (objc_msgSend frame) to a C++ handler
    trail.clear();
    try { [t throwCxx:2]; } catch (const AppError &e) { CHECK(e.code == 7); }
    CHECK(trail.size() == 2 && trail[1] == "~method!");

    // an Objective-C exception through C++ frames: destructors run, catch (...) catches it, @catch gets the object
    trail.clear();
    bool cxxCatchAll = false;
    try { [t throwObjC]; } catch (...) { cxxCatchAll = true; }
    // (std::uncaught_exceptions() does not count it: libc++abi sees it as a foreign exception, unlike iOS)
    CHECK(cxxCatchAll && trail.size() == 1 && trail[0] == "~objc");
    NSString *name = nil;
    @try { [t throwObjC]; } @catch (NSException *e) { name = e.name; }
    CHECK([name isEqualToString:@"ObjCError"]);

    // a C++ exception passes @catch (NSException *) and @catch (id), runs @finally, reaches the C++ handler
    NSMutableArray *log = [NSMutableArray array];
    try {
        @try { [t throwCxx:1]; }
        @catch (NSException *e) { [log addObject:@"NSException"]; }
        @catch (id e) { [log addObject:@"id"]; }
        @finally { [log addObject:@"finally"]; }
    } catch (int v) { [log addObject:[NSString stringWithFormat:@"int %d", v]]; }
    CHECK([[log componentsJoinedByString:@","] isEqualToString:@"finally,int 42"]);

    // @catch (...) catches a C++ exception too (as on iOS); C++ handlers in an Objective-C++ function next to @catch
    BOOL objcCatchAll = NO;
    @try { thrower(5); } @catch (...) { objcCatchAll = YES; }
    CHECK(objcCatchAll);
    CHECK(std::uncaught_exceptions() == 0 && !std::current_exception());
    std::string which;
    try { @try { thrower(2); } @catch (...) { @throw; } } catch (const AppError &e) { which = e.what(); }
    CHECK(which == "app failed");     // @throw; inside @catch (...) rethrows the C++ exception
    which.clear();
    @try {
        try { [t throwObjC]; }
        catch (const std::exception &) { which = "std::exception"; }
    } @catch (NSException *e) { which = std::string("NSException ") + e.reason.UTF8String; }
    CHECK(which == "NSException from objc");
    which.clear();
    @try {
        try { thrower(2); }
        catch (const std::exception &e) { which = e.what(); }
    } @catch (NSException *e) { which = "NSException"; }
    CHECK(which == "app failed");
}

static void uncaught() {
    printf("throwing\n"); fflush(stdout);
    thrower(2);
    printf("NOT REACHED\n");
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc > 1 && !strcmp(argv[1], "uncaught")) { uncaught(); return 0; }
        testBasics();
        testLibrary();
        testExceptionPtr();
        testThreads();
        testMixed();
        NSLog(@"C++ exceptions test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
