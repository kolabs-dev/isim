// Dispatch C API self-test for isim (DispatchTest.app): dispatch_data_t (create with each destructor, concat,
// subrange, map, apply, copy_region), dispatch_io_t (path / descriptor / derived channels, random offsets relative to
// the starting position, stream reads with low / high water marks and a strict interval, writes, barriers, close with
// and without DISPATCH_IO_STOP, open errors, dispatch_read / dispatch_write, the _f variants) and the sources whose
// events come from the host: write sources' free space, a listening socket's pending connections, Mach receive and
// send (dead name) sources on isim's ports, and process fork / exec / exit of a process the test driver started
// (DISPATCH_TEST_PID, DISPATCH_TEST_GO). Prints PASS/FAIL per check; exit code = failures.
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } fflush(stdout); } while (0)

/* waits (polling) until cond holds or `seconds` pass */
#define WAIT_FOR(seconds, cond) ({ int _ok = 0; for (int _i = 0; _i < (int)((seconds) * 100) && !(_ok = !!(cond)); _i++) usleep(10000); _ok || !!(cond); })

static dispatch_queue_t q;
static NSString *dir;

static NSString *str(dispatch_data_t d) {
    const void *p; size_t n;
    dispatch_data_t m = dispatch_data_create_map(d, &p, &n);
    NSString *s = [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding];
    dispatch_release(m);
    return s ?: @"";
}

static void testData(void) {
    CHECK(dispatch_data_get_size(dispatch_data_empty) == 0);
    char stackbuf[] = "hello";
    dispatch_data_t a = dispatch_data_create(stackbuf, 5, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);   // copied
    stackbuf[0] = 'J';
    CHECK(dispatch_data_get_size(a) == 5 && [str(a) isEqualToString:@"hello"]);
    char *heap = strdup(", world");
    dispatch_data_t b = dispatch_data_create(heap, 7, NULL, DISPATCH_DATA_DESTRUCTOR_FREE);          // adopted
    __block int destroyed = 0;
    static char custom[] = "!!";
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_data_t c = dispatch_data_create(custom, 2, q, ^{ destroyed++; dispatch_semaphore_signal(sem); });
    dispatch_data_t ab = dispatch_data_create_concat(a, b);
    dispatch_data_t abc = dispatch_data_create_concat(ab, c);
    dispatch_release(a); dispatch_release(b); dispatch_release(ab);
    CHECK(dispatch_data_get_size(abc) == 14 && [str(abc) isEqualToString:@"hello, world!!"]);

    __block int regions = 0; __block size_t offsets = 0;
    CHECK(dispatch_data_apply(abc, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
        regions++; offsets += offset;
        return dispatch_data_get_size(region) == size;
    }));
    CHECK(regions == 3 && offsets == 0 + 5 + 12);
    __block int visited = 0;
    CHECK(!dispatch_data_apply(abc, ^bool(dispatch_data_t r, size_t o, const void *p, size_t n) { return ++visited < 2; }) && visited == 2);

    dispatch_data_t sub = dispatch_data_create_subrange(abc, 3, 6);          // spans two regions
    CHECK([str(sub) isEqualToString:@"lo, wo"]);
    __block int subRegions = 0;
    dispatch_data_apply(sub, ^bool(dispatch_data_t r, size_t o, const void *p, size_t n) { subRegions++; return true; });
    CHECK(subRegions == 2);
    CHECK(dispatch_data_get_size(dispatch_data_create_subrange(abc, 20, 3)) == 0);
    dispatch_data_t tail = dispatch_data_create_subrange(abc, 10, 100);       // clamped
    CHECK([str(tail) isEqualToString:@"ld!!"]);

    size_t off = 99;
    dispatch_data_t region = dispatch_data_copy_region(abc, 7, &off);
    CHECK(off == 5 && [str(region) isEqualToString:@", world"]);
    dispatch_release(region);
    region = dispatch_data_copy_region(abc, 14, &off);
    CHECK(off == 14 && dispatch_data_get_size(region) == 0);

    const void *p = NULL; size_t n = 0;
    dispatch_data_t map = dispatch_data_create_map(abc, &p, &n);
    CHECK(n == 14 && memcmp(p, "hello, world!!", 14) == 0);
    dispatch_release(map);
    CHECK(destroyed == 0);
    dispatch_release(sub); dispatch_release(tail);
    dispatch_release(c);
    CHECK(destroyed == 0);                                                   // abc still uses the buffer
    dispatch_release(abc);
    CHECK(dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0 && destroyed == 1);

    // a zero-length buffer: dispatch_data_empty, the destructor runs at once
    __block int ranEmpty = 0;
    dispatch_data_t e = dispatch_data_create("", 0, NULL, ^{ ranEmpty = 1; });
    CHECK(e == dispatch_data_empty && ranEmpty == 1);
}

static void testIO(void) {
    NSString *path = [dir stringByAppendingPathComponent:@"io.bin"];
    [@"PREFIX" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    int fd = open(path.UTF8String, O_RDWR);
    lseek(fd, 6, SEEK_SET);                                                  // random offsets count from here
    __block int cleanups = 0;
    dispatch_io_t io = dispatch_io_create(DISPATCH_IO_RANDOM, fd, q, ^(int error) { cleanups++; });
    CHECK(io != NULL && dispatch_io_get_descriptor(io) == fd);
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block int werr = -1; __block size_t wleft = 1;
    dispatch_data_t payload = dispatch_data_create("0123456789", 10, NULL, NULL);
    dispatch_io_write(io, 2, payload, q, ^(bool done, dispatch_data_t rest, int error) {
        if (done) { werr = error; wleft = rest ? dispatch_data_get_size(rest) : 0; dispatch_semaphore_signal(sem); }
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    CHECK(werr == 0 && wleft == 0);
    __block NSMutableString *got = [NSMutableString string]; __block int rerr = -1;
    dispatch_io_read(io, 4, 3, q, ^(bool done, dispatch_data_t data, int error) {
        if (data) [got appendString:str(data)];
        if (done) { rerr = error; dispatch_semaphore_signal(sem); }
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    CHECK(rerr == 0 && [got isEqualToString:@"234"]);                        // file offset 6 + 4 = 10: "PREFIX\0\0" + "01234..."
    __block int order = 0, barrierAt = -1;
    dispatch_io_read(io, 0, 2, q, ^(bool done, dispatch_data_t d, int e) { if (done) order++; });
    dispatch_io_barrier(io, ^{ barrierAt = order; CHECK(dispatch_io_get_descriptor(io) == fd); dispatch_semaphore_signal(sem); });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    CHECK(barrierAt == 0 || barrierAt == 1);                                // the read ran first; its handler may not yet
    dispatch_io_close(io, 0);
    CHECK(WAIT_FOR(2, cleanups == 1));
    __block int lateErr = 0;
    dispatch_io_read(io, 0, 1, q, ^(bool done, dispatch_data_t d, int e) { lateErr = e; dispatch_semaphore_signal(sem); });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    CHECK(lateErr == ECANCELED && dispatch_io_get_descriptor(io) == -1);
    dispatch_release(io);
    CHECK(fcntl(fd, F_GETFD) != -1);                                        // not the channel's descriptor: still open
    close(fd);

    NSData *contents = [NSData dataWithContentsOfFile:path];
    CHECK(contents.length == 18 && memcmp((const char *)contents.bytes + 8, "0123456789", 10) == 0);

    // path channels: absolute paths only; an open error goes to the handlers and the cleanup handler
    CHECK(dispatch_io_create_with_path(DISPATCH_IO_STREAM, "relative.txt", O_RDONLY, 0, q, ^(int e) {}) == NULL);
    __block int cleanupErr = -1, missingErr = -1;
    NSString *missing = [dir stringByAppendingPathComponent:@"missing.txt"];
    dispatch_io_t bad = dispatch_io_create_with_path(DISPATCH_IO_STREAM, missing.UTF8String, O_RDONLY, 0, q, ^(int e) { cleanupErr = e; });
    CHECK(bad != NULL);
    dispatch_io_read(bad, 0, SIZE_MAX, q, ^(bool done, dispatch_data_t d, int e) { missingErr = e; dispatch_semaphore_signal(sem); });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    dispatch_io_close(bad, 0);
    CHECK(missingErr == ENOENT && WAIT_FOR(2, cleanupErr == ENOENT));
    dispatch_release(bad);

    // a path channel owns its descriptor; a derived channel (create_with_io) reads through it
    __block int pathCleanup = -1;
    dispatch_io_t owner = dispatch_io_create_with_path(DISPATCH_IO_RANDOM, path.UTF8String, O_RDONLY, 0, q, ^(int e) { pathCleanup = e; });
    dispatch_io_t derived = dispatch_io_create_with_io(DISPATCH_IO_RANDOM, owner, q, ^(int e) {});
    __block NSString *viaDerived = nil;
    dispatch_io_read(derived, 0, 6, q, ^(bool done, dispatch_data_t d, int e) { if (done) { viaDerived = str(d); dispatch_semaphore_signal(sem); } });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    CHECK([viaDerived isEqualToString:@"PREFIX"]);
    int ownedFD = dispatch_io_get_descriptor(owner);
    dispatch_io_close(derived, 0); dispatch_release(derived);
    dispatch_io_close(owner, 0); dispatch_release(owner);
    CHECK(WAIT_FOR(2, pathCleanup == 0) && fcntl(ownedFD, F_GETFD) == -1);   // closed by the channel

    // stream reads from a pipe: low-water partial results, high-water pieces
    int fds[2]; pipe(fds);
    int r0 = fds[0], w1 = fds[1];
    dispatch_io_t rio = dispatch_io_create(DISPATCH_IO_STREAM, r0, q, ^(int e) { close(r0); });
    dispatch_io_set_low_water(rio, 1);
    dispatch_io_set_high_water(rio, 4);
    __block NSMutableArray<NSString *> *pieces = [NSMutableArray array]; __block int streamDone = 0;
    dispatch_io_read(rio, 0, SIZE_MAX, q, ^(bool done, dispatch_data_t d, int e) {
        if (d && dispatch_data_get_size(d)) [pieces addObject:str(d)];
        if (done) streamDone = 1;
    });
    write(w1, "abcdefghij", 10);
    CHECK(WAIT_FOR(2, [[pieces componentsJoinedByString:@""] isEqualToString:@"abcdefghij"]));
    BOOL small = YES; for (NSString *s in pieces) if (s.length > 4) small = NO;
    CHECK(small && pieces.count >= 3);                                       // at most 4 bytes per handler call
    CHECK(streamDone == 0);                                                  // still reading: no end of file yet
    close(fds[1]);
    CHECK(WAIT_FOR(2, streamDone == 1));
    dispatch_io_close(rio, 0); dispatch_release(rio);

    // a strict interval delivers what arrived although it is below the low-water mark
    pipe(fds); r0 = fds[0]; w1 = fds[1];
    dispatch_io_t iio = dispatch_io_create(DISPATCH_IO_STREAM, r0, q, ^(int e) { close(r0); });
    dispatch_io_set_low_water(iio, 1000);
    dispatch_io_set_interval(iio, 20 * NSEC_PER_MSEC, DISPATCH_IO_STRICT_INTERVAL);
    __block int partials = 0, intervalDone = 0;
    dispatch_io_read(iio, 0, SIZE_MAX, q, ^(bool done, dispatch_data_t d, int e) { if (!done && d) partials++; if (done) intervalDone = 1; });
    for (int i = 0; i < 6 && partials == 0; i++) { write(fds[1], "x", 1); usleep(30000); }
    CHECK(partials >= 1);
    // DISPATCH_IO_STOP: the pending read ends with ECANCELED
    __block int stopErr = 0;
    dispatch_io_read(iio, 0, SIZE_MAX, q, ^(bool done, dispatch_data_t d, int e) { if (done) stopErr = e; });
    dispatch_io_close(iio, DISPATCH_IO_STOP);
    write(fds[1], "y", 1);                                                   // wakes the blocked read
    CHECK(WAIT_FOR(2, intervalDone == 1 && stopErr == ECANCELED));
    close(fds[1]); dispatch_release(iio);

    // dispatch_read / dispatch_write and the function variants
    pipe(fds); r0 = fds[0]; w1 = fds[1];
    dispatch_data_t big = dispatch_data_create(calloc(1, 3000), 3000, NULL, DISPATCH_DATA_DESTRUCTOR_FREE);
    __block int wrote = -1;
    dispatch_write(w1, big, q, ^(dispatch_data_t rest, int e) { wrote = e == 0 && !rest; close(w1); });
    __block size_t readSize = 0; __block int readErr = -1;
    dispatch_read(r0, SIZE_MAX, q, ^(dispatch_data_t d, int e) { readSize = dispatch_data_get_size(d); readErr = e; close(r0); });
    CHECK(WAIT_FOR(2, wrote == 1 && readErr == 0) && readSize == 3000);
    dispatch_release(big);
}

static int fCleanups;
static size_t fRead;
static void f_cleanup(void *ctx, int error) { fCleanups += ctx == (void *)7; }
static void f_read(void *ctx, bool done, dispatch_data_t data, int error) { if (data) fRead += dispatch_data_get_size(data); if (done) dispatch_semaphore_signal(ctx); }
static bool f_apply(void *ctx, dispatch_data_t region, size_t offset, const void *buffer, size_t size) { *(size_t *)ctx += size; return true; }
static void testFunctions(void) {
    NSString *path = [dir stringByAppendingPathComponent:@"f.txt"];
    [@"function variants" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_io_t io = dispatch_io_create_with_path_f(DISPATCH_IO_RANDOM, path.UTF8String, O_RDONLY, 0, q, (void *)7, f_cleanup);
    dispatch_io_read_f(io, 9, 8, q, sem, f_read);
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    CHECK(fRead == 8);
    dispatch_io_close(io, 0); dispatch_release(io);
    CHECK(WAIT_FOR(2, fCleanups == 1));
    dispatch_data_t d = dispatch_data_create_concat(dispatch_data_create("ab", 2, NULL, NULL), dispatch_data_create("cde", 3, NULL, NULL));
    size_t total = 0;
    CHECK(dispatch_data_apply_f(d, &total, f_apply) && total == 5);
}

typedef struct { mach_msg_header_t header; int value; } Msg;
typedef struct { mach_msg_header_t header; int value; mach_msg_trailer_t trailer; } MsgRcv;
static void testSources(void) {
    // write source: data = the pipe's free space (its capacity minus what is queued)
    int fds[2]; pipe(fds);
    write(fds[1], "12345", 5);
    __block unsigned long space = 0;
    dispatch_source_t w = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, fds[1], 0, q);
    dispatch_source_set_event_handler(w, ^{ space = dispatch_source_get_data(w); dispatch_source_cancel(w); });
    dispatch_resume(w);
    CHECK(WAIT_FOR(2, space > 0));
    CHECK(space > 4096 && space % 4096 == 4096 - 5);                         // e.g. 65536 - 5
    printf("      write source free space: %lu\n", space);
    dispatch_release(w); close(fds[0]); close(fds[1]);

    // read source on a listening socket: data = pending connections
    int ls = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in sa = { .sin_len = sizeof sa, .sin_family = AF_INET, .sin_addr.s_addr = htonl(INADDR_LOOPBACK) };
    socklen_t len = sizeof sa;
    CHECK(bind(ls, (struct sockaddr *)&sa, sizeof sa) == 0 && listen(ls, 8) == 0 && getsockname(ls, (struct sockaddr *)&sa, &len) == 0);
    int c1 = socket(AF_INET, SOCK_STREAM, 0), c2 = socket(AF_INET, SOCK_STREAM, 0);
    connect(c1, (struct sockaddr *)&sa, sizeof sa); connect(c2, (struct sockaddr *)&sa, sizeof sa);
    __block unsigned long pending = 0;
    dispatch_source_t acc = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, ls, 0, q);
    dispatch_source_set_event_handler(acc, ^{ pending = dispatch_source_get_data(acc); dispatch_source_cancel(acc); });
    dispatch_resume(acc);
    CHECK(WAIT_FOR(2, pending == 2));
    dispatch_release(acc); close(c1); close(c2); close(ls);

    // Mach receive source: fires while messages are queued (the handler receives one per call)
    mach_port_t task = mach_task_self(), port;
    mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &port);
    mach_port_insert_right(task, port, port, MACH_MSG_TYPE_MAKE_SEND);
    __block int received = 0, sum = 0;
    dispatch_source_t recv = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_RECV, port, 0, q);
    CHECK(recv != NULL && dispatch_source_get_handle(recv) == port);
    dispatch_source_set_event_handler(recv, ^{
        MsgRcv in = {0};
        if (mach_msg(&in.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof in, port, 0, MACH_PORT_NULL) == MACH_MSG_SUCCESS) { received++; sum += in.value; }
    });
    dispatch_resume(recv);
    for (int i = 1; i <= 3; i++) {
        Msg m = { .header = { .msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0), .msgh_size = sizeof m, .msgh_remote_port = port, .msgh_id = i }, .value = i };
        mach_msg(&m.header, MACH_SEND_MSG, sizeof m, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    }
    CHECK(WAIT_FOR(2, received == 3) && sum == 6);
    mach_port_status_t st; mach_msg_type_number_t cnt = MACH_PORT_RECEIVE_STATUS_COUNT;
    CHECK(mach_port_get_attributes(task, port, MACH_PORT_RECEIVE_STATUS, (mach_port_info_t)&st, &cnt) == KERN_SUCCESS &&
          st.mps_msgcount == 0 && st.mps_qlimit == MACH_PORT_QLIMIT_DEFAULT && st.mps_srights);
    dispatch_source_cancel(recv); dispatch_release(recv);

    // Mach send source: DISPATCH_MACH_SEND_DEAD once the receive right is destroyed
    __block unsigned long dead = 0;
    dispatch_source_t send = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_SEND, port, DISPATCH_MACH_SEND_DEAD, q);
    dispatch_source_set_event_handler(send, ^{ dead = dispatch_source_get_data(send); });
    dispatch_resume(send);
    usleep(20000);
    CHECK(dead == 0);
    mach_port_mod_refs(task, port, MACH_PORT_RIGHT_RECEIVE, -1);
    CHECK(WAIT_FOR(2, dead == DISPATCH_MACH_SEND_DEAD));
    dispatch_source_cancel(send); dispatch_release(send);

    // process source on a process the driver started: it forks, execs, then exits when we create DISPATCH_TEST_GO
    const char *pidEnv = getenv("DISPATCH_TEST_PID"), *go = getenv("DISPATCH_TEST_GO");
    if (pidEnv && go) {
        pid_t pid = atoi(pidEnv);
        __block unsigned long events = 0;
        dispatch_source_t proc = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, pid, DISPATCH_PROC_FORK | DISPATCH_PROC_EXEC | DISPATCH_PROC_EXIT, q);
        dispatch_source_set_event_handler(proc, ^{ events |= dispatch_source_get_data(proc); });
        dispatch_resume(proc);
        usleep(100000);                                                      // let the source take its first snapshot
        close(open(go, O_CREAT | O_WRONLY, 0644));
        CHECK(WAIT_FOR(10, (events & DISPATCH_PROC_EXIT) != 0));
        CHECK(events & DISPATCH_PROC_FORK);
        CHECK(events & DISPATCH_PROC_EXEC);
        printf("      process events: 0x%lx\n", events);
        dispatch_source_cancel(proc); dispatch_release(proc);
    } else CHECK(!"DISPATCH_TEST_PID / DISPATCH_TEST_GO not set");
}

int main(int argc, char **argv) {
    @autoreleasepool {
        q = dispatch_queue_create("dispatch.test", NULL);
        dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"dispatch-test-%d", getpid()]];
        [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        testData();
        testIO();
        testFunctions();
        testSources();
        [NSFileManager.defaultManager removeItemAtPath:dir error:NULL];
        NSLog(@"dispatch test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
