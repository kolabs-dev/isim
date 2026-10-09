// Mach self-test for isim: <mach/mach.h> and <mach/mach_time.h> as apps use them — time, the task's memory and CPU
// (task_info), threads (task_threads, thread_info, pthread_mach_thread_np), the host (host_info, host_statistics,
// host_processor_info, page sizes), virtual memory (vm_allocate / vm_protect / vm_read_overwrite), ports and
// in-process messages (mach_msg), semaphores, clocks and error strings; then the Swift side (mach.swift).
// Prints PASS/FAIL per check; exit code = failures.
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } } while (0)

int swift_mach_checks(void);       // mach.swift: failures
int swift_mach_check_count(void);

static void testTime(void) {
    mach_timebase_info_data_t tb;
    CHECK(mach_timebase_info(&tb) == KERN_SUCCESS && tb.numer == 1 && tb.denom == 1);
    uint64_t a = mach_absolute_time();
    usleep(20000);
    uint64_t b = mach_absolute_time();
    CHECK(b - a >= 20000000ull && b - a < 2000000000ull);         // nanoseconds
    uint64_t abs = mach_absolute_time();
    CHECK(mach_continuous_time() >= abs);                          // also counts sleep
    CHECK(mach_approximate_time() > 0 && mach_continuous_approximate_time() > 0);
    uint64_t deadline = mach_absolute_time() + 30000000ull;
    CHECK(mach_wait_until(deadline) == KERN_SUCCESS && mach_absolute_time() >= deadline);

    clock_serv_t clk; mach_timespec_t ts;
    CHECK(host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &clk) == KERN_SUCCESS);
    CHECK(clock_get_time(clk, &ts) == KERN_SUCCESS && labs((long)ts.tv_sec - (long)time(NULL)) <= 1);
    CHECK(mach_port_deallocate(mach_task_self(), clk) == KERN_SUCCESS);
    CHECK(host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &clk) == KERN_SUCCESS && clock_get_time(clk, &ts) == KERN_SUCCESS);
    CHECK(host_get_clock_service(mach_host_self(), 7, &clk) == KERN_INVALID_ARGUMENT);
}

static char *volatile dirty;
static void testTask(void) {
    // memory: the classic "memory used" snippets
    struct mach_task_basic_info basic;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    CHECK(MACH_TASK_BASIC_INFO_COUNT == 12 && TASK_BASIC_INFO_64_COUNT == 10 && TASK_VM_INFO_REV0_COUNT == 36);
    CHECK(TASK_VM_INFO_REV1_COUNT == TASK_VM_INFO_REV0_COUNT + 2 && TASK_VM_INFO_REV2_COUNT == TASK_VM_INFO_REV1_COUNT + 4);
    CHECK(task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&basic, &count) == KERN_SUCCESS && count == MACH_TASK_BASIC_INFO_COUNT);
    CHECK(basic.resident_size > 1000000 && basic.virtual_size > basic.resident_size && basic.resident_size_max >= basic.resident_size);
    CHECK(basic.policy == POLICY_TIMESHARE && basic.suspend_count == 0);

    task_vm_info_data_t vm;
    count = TASK_VM_INFO_COUNT;
    CHECK(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vm, &count) == KERN_SUCCESS && count == TASK_VM_INFO_COUNT);
    CHECK(vm.phys_footprint > 0 && vm.phys_footprint <= vm.resident_size + vm.compressed + (64ull << 20));
    CHECK(vm.page_size == (int)vm_page_size && vm.region_count > 10 && vm.min_address < vm.max_address);
    CHECK(vm.ledger_phys_footprint_peak >= (int64_t)vm.phys_footprint);
    // footprint follows dirty memory
    size_t big = 64 << 20;
    char *p = malloc(big);
    memset(p, 1, big);
    dirty = p;                                                            // (an unused allocation could be elided)
    task_vm_info_data_t vm2; count = TASK_VM_INFO_REV1_COUNT;           // an older caller: rev1 is what it gets
    CHECK(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vm2, &count) == KERN_SUCCESS && count == TASK_VM_INFO_REV1_COUNT);
    CHECK(vm2.phys_footprint >= vm.phys_footprint + big / 2);
    free(p);
    count = TASK_VM_INFO_REV0_COUNT - 1;
    CHECK(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vm2, &count) == KERN_INVALID_ARGUMENT);

    // CPU time: live threads (TASK_THREAD_TIMES_INFO) + terminated ones (MACH_TASK_BASIC_INFO)
    volatile double x = 0;
    for (int i = 0; i < 30000000; i++) x += i * 0.5;
    task_thread_times_info_data_t times;
    count = TASK_THREAD_TIMES_INFO_COUNT;
    CHECK(task_info(mach_task_self(), TASK_THREAD_TIMES_INFO, (task_info_t)&times, &count) == KERN_SUCCESS);
    CHECK(times.user_time.seconds * 1000000 + times.user_time.microseconds > 10000);

    task_basic_info_data_t legacy; count = TASK_BASIC_INFO_COUNT;
    CHECK(task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&legacy, &count) == KERN_SUCCESS && legacy.resident_size > 0);
    task_events_info_data_t events; count = TASK_EVENTS_INFO_COUNT;
    CHECK(task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&events, &count) == KERN_SUCCESS && events.faults > 0 && events.csw > 0);
    CHECK(task_info(mach_task_self(), 9999, (task_info_t)&events, &count) == KERN_INVALID_ARGUMENT);
    CHECK(task_info(12345, MACH_TASK_BASIC_INFO, (task_info_t)&basic, &count) == MACH_SEND_INVALID_DEST);   // only this task
}

static volatile int spin_stop;
static void *spinner(void *arg) {
    pthread_setname_np("mach-spinner");
    *(mach_port_t *)arg = mach_thread_self();
    volatile double x = 0;
    while (!spin_stop) x += 1;
    return NULL;
}

static void testThreads(void) {
    mach_port_t self = mach_thread_self();
    CHECK(MACH_PORT_VALID(self) && self == pthread_mach_thread_np(pthread_self()));
    CHECK(pthread_from_mach_thread_np(self) == pthread_self());
    uint64_t tid = 0, tid2 = 0;
    CHECK(pthread_threadid_np(NULL, &tid) == 0 && pthread_threadid_np(pthread_self(), &tid2) == 0 && tid && tid == tid2);

    mach_port_t spinPort = 0;
    pthread_t t; pthread_create(&t, NULL, spinner, &spinPort);
    while (!spinPort) usleep(1000);
    CHECK(pthread_mach_thread_np(t) == spinPort && pthread_from_mach_thread_np(spinPort) == t);
    thread_extended_info_data_t ext; mach_msg_type_number_t c;
    for (int i = 0; i < 1000; i++) {                               // wait until the spinner has run for 50 ms of CPU
        c = THREAD_EXTENDED_INFO_COUNT;
        if (thread_info(spinPort, THREAD_EXTENDED_INFO, (thread_info_t)&ext, &c) == KERN_SUCCESS && ext.pth_user_time >= 50000000ull) break;
        usleep(10000);
    }

    // the CPU monitor loop: every thread's usage
    thread_act_array_t list; mach_msg_type_number_t n;
    CHECK(task_threads(mach_task_self(), &list, &n) == KERN_SUCCESS && n >= 2);
    BOOL foundSelf = NO, foundSpinner = NO; int spinnerUsage = 0;
    for (mach_msg_type_number_t i = 0; i < n; i++) {
        thread_basic_info_data_t info; mach_msg_type_number_t c = THREAD_BASIC_INFO_COUNT;
        if (thread_info(list[i], THREAD_BASIC_INFO, (thread_info_t)&info, &c) != KERN_SUCCESS) continue;
        if (list[i] == self) foundSelf = info.run_state == TH_STATE_RUNNING;
        if (list[i] == spinPort) { foundSpinner = YES; spinnerUsage = info.cpu_usage; }
        mach_port_deallocate(mach_task_self(), list[i]);
    }
    CHECK(vm_deallocate(mach_task_self(), (vm_address_t)list, n * sizeof(thread_act_t)) == KERN_SUCCESS);
    CHECK(foundSelf && foundSpinner);
    CHECK(spinnerUsage > 0 && spinnerUsage <= TH_USAGE_SCALE);    // a busy thread (at most one CPU)

    thread_identifier_info_data_t ident; c = THREAD_IDENTIFIER_INFO_COUNT;
    uint64_t spinTid = 0; pthread_threadid_np(t, &spinTid);
    CHECK(thread_info(spinPort, THREAD_IDENTIFIER_INFO, (thread_info_t)&ident, &c) == KERN_SUCCESS &&
          ident.thread_id == spinTid && ident.thread_handle == (uint64_t)(uintptr_t)t);
    c = THREAD_EXTENDED_INFO_COUNT;
    CHECK(thread_info(spinPort, THREAD_EXTENDED_INFO, (thread_info_t)&ext, &c) == KERN_SUCCESS &&
          !strcmp(ext.pth_name, "mach-spinner") && ext.pth_user_time >= 50000000ull);
    thread_basic_info_data_t mine; c = THREAD_BASIC_INFO_COUNT;
    CHECK(thread_info(self, THREAD_BASIC_INFO, (thread_info_t)&mine, &c) == KERN_SUCCESS && c == THREAD_BASIC_INFO_COUNT &&
          mine.user_time.seconds * 1000000 + mine.user_time.microseconds > 10000);
    c = 2;
    CHECK(thread_info(self, THREAD_BASIC_INFO, (thread_info_t)&mine, &c) == KERN_INVALID_ARGUMENT);
    thread_extended_policy_data_t pol = { .timeshare = 0 };
    CHECK(thread_policy_set(self, THREAD_EXTENDED_POLICY, (thread_policy_t)&pol, THREAD_EXTENDED_POLICY_COUNT) == KERN_SUCCESS);

    spin_stop = 1;
    pthread_join(t, NULL);
    kern_return_t gone = KERN_SUCCESS;                             // the exited thread's port is invalid (once Linux reaped it)
    for (int i = 0; i < 2000 && gone == KERN_SUCCESS; i++) {
        c = THREAD_BASIC_INFO_COUNT;
        if ((gone = thread_info(spinPort, THREAD_BASIC_INFO, (thread_info_t)&mine, &c)) == KERN_SUCCESS) usleep(1000);
    }
    CHECK(gone == MACH_SEND_INVALID_DEST);
    CHECK(mach_port_deallocate(mach_task_self(), self) == KERN_SUCCESS);
}

static void testHost(void) {
    host_basic_info_data_t hb; mach_msg_type_number_t c = HOST_BASIC_INFO_COUNT;
    CHECK(host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hb, &c) == KERN_SUCCESS && c == HOST_BASIC_INFO_COUNT);
    CHECK(hb.max_mem == NSProcessInfo.processInfo.physicalMemory);
    CHECK(hb.avail_cpus == (int)NSProcessInfo.processInfo.processorCount && hb.cpu_type == CPU_TYPE_X86_64);

    vm_size_t page = 0;
    CHECK(host_page_size(mach_host_self(), &page) == KERN_SUCCESS && page == vm_page_size && page == (vm_size_t)getpagesize());
    CHECK(vm_page_mask == page - 1 && (1ul << vm_page_shift) == page && vm_kernel_page_size == page);

    // the "free memory" snippet: counts add up to (at most) the device's memory
    vm_statistics64_data_t vs; c = HOST_VM_INFO64_COUNT;
    CHECK(HOST_VM_INFO64_COUNT == 38);
    CHECK(host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vs, &c) == KERN_SUCCESS && c == HOST_VM_INFO64_COUNT);
    uint64_t used = ((uint64_t)vs.active_count + vs.inactive_count + vs.wire_count) * page, freeb = (uint64_t)vs.free_count * page;
    CHECK(used > 0 && used + freeb <= hb.max_mem + hb.max_mem / 50);
    vm_statistics_data_t vs32; c = HOST_VM_INFO_COUNT;
    CHECK(host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vs32, &c) == KERN_SUCCESS && c == HOST_VM_INFO_COUNT && vs32.free_count > 0);

    host_cpu_load_info_data_t load1, load2; c = HOST_CPU_LOAD_INFO_COUNT;
    CHECK(host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&load1, &c) == KERN_SUCCESS);
    volatile double x = 0; for (int i = 0; i < 20000000; i++) x += i;
    usleep(50000);
    c = HOST_CPU_LOAD_INFO_COUNT;
    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&load2, &c);
    natural_t delta = 0; for (int i = 0; i < CPU_STATE_MAX; i++) delta += load2.cpu_ticks[i] - load1.cpu_ticks[i];
    CHECK(delta > 0);

    natural_t ncpu; processor_info_array_t info; mach_msg_type_number_t infoCount;
    CHECK(host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &ncpu, &info, &infoCount) == KERN_SUCCESS);
    CHECK(ncpu == (natural_t)hb.avail_cpus && infoCount == ncpu * CPU_STATE_MAX);
    processor_cpu_load_info_t cpus = (processor_cpu_load_info_t)info;
    CHECK(cpus[0].cpu_ticks[CPU_STATE_IDLE] + cpus[0].cpu_ticks[CPU_STATE_USER] > 0);
    CHECK(vm_deallocate(mach_task_self(), (vm_address_t)info, infoCount * sizeof(integer_t)) == KERN_SUCCESS);
    CHECK(host_info(mach_task_self(), HOST_BASIC_INFO, (host_info_t)&hb, &c) == MACH_SEND_INVALID_DEST);
}

static void testVM(void) {
    vm_address_t addr = 0;
    CHECK(vm_allocate(mach_task_self(), &addr, 3 * vm_page_size + 1, VM_FLAGS_ANYWHERE) == KERN_SUCCESS && addr && !(addr & vm_page_mask));
    CHECK(((char *)addr)[0] == 0 && ((char *)addr)[4 * vm_page_size - 1] == 0);       // zero-filled, rounded to pages
    memset((void *)addr, 7, vm_page_size);
    vm_address_t fixed = addr + 8 * vm_page_size;
    vm_address_t want = fixed;
    kern_return_t kr = vm_allocate(mach_task_self(), &want, vm_page_size, VM_FLAGS_FIXED);
    CHECK((kr == KERN_SUCCESS && want == fixed) || kr == KERN_NO_SPACE);
    if (kr == KERN_SUCCESS) {
        vm_address_t again = fixed;
        CHECK(vm_allocate(mach_task_self(), &again, vm_page_size, VM_FLAGS_FIXED) == KERN_NO_SPACE);
        vm_deallocate(mach_task_self(), fixed, vm_page_size);
    }

    // reading memory that may be unmapped, without faulting (crash reporters, debuggers)
    char buf[16] = {0}; vm_size_t got = 0;
    CHECK(vm_read_overwrite(mach_task_self(), addr, 16, (vm_address_t)buf, &got) == KERN_SUCCESS && got == 16 && buf[15] == 7);
    CHECK(vm_protect(mach_task_self(), addr, vm_page_size, FALSE, VM_PROT_READ) == KERN_SUCCESS);
    CHECK(vm_read_overwrite(mach_task_self(), addr, 16, (vm_address_t)buf, &got) == KERN_SUCCESS);
    CHECK(vm_protect(mach_task_self(), addr, vm_page_size, FALSE, VM_PROT_DEFAULT) == KERN_SUCCESS);
    CHECK(vm_deallocate(mach_task_self(), addr, 4 * vm_page_size) == KERN_SUCCESS);
    CHECK(vm_read_overwrite(mach_task_self(), addr, 16, (vm_address_t)buf, &got) == KERN_INVALID_ADDRESS);
    mach_vm_size_t got64 = 0; int value = 42, copy = 0;
    CHECK(mach_vm_read_overwrite(mach_task_self(), (mach_vm_address_t)&value, sizeof value, (mach_vm_address_t)&copy, &got64) == KERN_SUCCESS && copy == 42);
    CHECK(mach_vm_read_overwrite(mach_task_self(), 8, 8, (mach_vm_address_t)&copy, &got64) == KERN_INVALID_ADDRESS);
    mach_vm_address_t a64 = 0;
    CHECK(mach_vm_allocate(mach_task_self(), &a64, 1 << 20, VM_FLAGS_ANYWHERE) == KERN_SUCCESS && mach_vm_deallocate(mach_task_self(), a64, 1 << 20) == KERN_SUCCESS);
}

// ports: a server thread answers requests on a port; replies come back on a send-once reply port
typedef struct { mach_msg_header_t header; int value; char text[32]; } Request;
typedef struct { mach_msg_header_t header; int value; char text[32]; mach_msg_trailer_t trailer; } RequestRcv;
static mach_port_t serverPort;
static void *server(void *arg) {
    for (;;) {
        RequestRcv in = {0};
        if (mach_msg(&in.header, MACH_RCV_MSG, 0, sizeof in, serverPort, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL) != MACH_MSG_SUCCESS) return NULL;
        if (in.header.msgh_id == 99) return NULL;
        Request out = {0};
        out.header.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(in.header.msgh_bits), 0);
        out.header.msgh_remote_port = in.header.msgh_remote_port;
        out.header.msgh_size = sizeof out; out.header.msgh_id = in.header.msgh_id + 100;
        out.value = in.value * 2; snprintf(out.text, sizeof out.text, "re: %s", in.text);
        mach_msg(&out.header, MACH_SEND_MSG, sizeof out, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    }
}

static void testPorts(void) {
    mach_port_t task = mach_task_self(), port;
    CHECK(mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &port) == KERN_SUCCESS && MACH_PORT_VALID(port));
    CHECK(mach_port_insert_right(task, port, port, MACH_MSG_TYPE_MAKE_SEND) == KERN_SUCCESS);
    mach_port_urefs_t refs = 0; mach_port_type_t type = 0;
    CHECK(mach_port_get_refs(task, port, MACH_PORT_RIGHT_SEND, &refs) == KERN_SUCCESS && refs == 1);
    CHECK(mach_port_type(task, port, &type) == KERN_SUCCESS && type == MACH_PORT_TYPE_SEND_RECEIVE);

    // one message to ourselves, the trailer after it
    Request msg = {0};
    msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    msg.header.msgh_remote_port = port; msg.header.msgh_size = sizeof msg; msg.header.msgh_id = 7;
    msg.value = 21; strcpy(msg.text, "hello");
    CHECK(mach_msg(&msg.header, MACH_SEND_MSG, sizeof msg, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL) == MACH_MSG_SUCCESS);
    RequestRcv in = {0};
    CHECK(mach_msg(&in.header, MACH_RCV_MSG, 0, sizeof in, port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL) == MACH_MSG_SUCCESS);
    CHECK(in.header.msgh_id == 7 && in.value == 21 && !strcmp(in.text, "hello") && in.header.msgh_local_port == port);
    CHECK(in.header.msgh_size == sizeof msg && in.trailer.msgh_trailer_size == MACH_MSG_TRAILER_MINIMUM_SIZE);

    // nothing queued: a receive with a timeout times out; a too-small buffer
    CHECK(mach_msg(&in.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof in, port, 20, MACH_PORT_NULL) == MACH_RCV_TIMED_OUT);
    mach_msg(&msg.header, MACH_SEND_MSG, sizeof msg, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    mach_msg_empty_rcv_t small = {0};
    CHECK(mach_msg(&small.header, MACH_RCV_MSG | MACH_RCV_LARGE | MACH_RCV_TIMEOUT, 0, sizeof small, port, 0, MACH_PORT_NULL) == MACH_RCV_TOO_LARGE &&
          small.header.msgh_size == sizeof msg);
    CHECK(mach_msg(&in.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof in, port, 0, MACH_PORT_NULL) == MACH_MSG_SUCCESS && in.value == 21);

    // the queue limit (MACH_PORT_QLIMIT_DEFAULT): a sender with a timeout gives up when the queue is full
    int sent = 0;
    while (sent < 10 && mach_msg(&msg.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof msg, 0, MACH_PORT_NULL, 0, MACH_PORT_NULL) == MACH_MSG_SUCCESS) sent++;
    CHECK(sent == MACH_PORT_QLIMIT_DEFAULT);
    CHECK(mach_msg(&msg.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof msg, 0, MACH_PORT_NULL, 10, MACH_PORT_NULL) == MACH_SEND_TIMED_OUT);
    while (mach_msg(&in.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof in, port, 0, MACH_PORT_NULL) == MACH_MSG_SUCCESS) sent--;
    CHECK(sent == 0);

    // RPC: a server thread, requests with a send-once reply right
    CHECK(mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &serverPort) == KERN_SUCCESS);
    mach_port_insert_right(task, serverPort, serverPort, MACH_MSG_TYPE_MAKE_SEND);
    pthread_t t; pthread_create(&t, NULL, server, NULL);
    mach_port_t reply = mach_reply_port();
    BOOL allOK = YES;
    for (int i = 1; i <= 20; i++) {
        union { Request req; RequestRcv rcv; } m = {0};
        m.req.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
        m.req.header.msgh_remote_port = serverPort; m.req.header.msgh_local_port = reply;
        m.req.header.msgh_size = sizeof m.req; m.req.header.msgh_id = i; m.req.value = i;
        snprintf(m.req.text, sizeof m.req.text, "req %d", i);
        mach_msg_return_t r = mach_msg(&m.req.header, MACH_SEND_MSG | MACH_RCV_MSG, sizeof m.req, sizeof m.rcv, reply, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        char want[32]; snprintf(want, sizeof want, "re: req %d", i);
        if (r != MACH_MSG_SUCCESS || m.rcv.header.msgh_id != i + 100 || m.rcv.value != 2 * i || strcmp(m.rcv.text, want)) allOK = NO;
    }
    CHECK(allOK);
    Request stop = {0};
    stop.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    stop.header.msgh_remote_port = serverPort; stop.header.msgh_size = sizeof stop; stop.header.msgh_id = 99;
    CHECK(mach_msg_send(&stop.header) == MACH_MSG_SUCCESS);
    pthread_join(t, NULL);

    // a receiver blocked on a port whose receive right is destroyed wakes with MACH_RCV_PORT_DIED
    mach_port_t doomed;
    mach_port_options_t opts = { .flags = MPO_INSERT_SEND_RIGHT };
    CHECK(mach_port_construct(task, &opts, 0, &doomed) == KERN_SUCCESS);
    __block mach_msg_return_t died = 0;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        RequestRcv r;
        died = mach_msg(&r.header, MACH_RCV_MSG, 0, sizeof r, doomed, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        dispatch_semaphore_signal(done);
    });
    usleep(50000);
    CHECK(mach_port_destruct(task, doomed, 0, 0) == KERN_SUCCESS);
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    CHECK(died == MACH_RCV_PORT_DIED);
    // the send right left behind is a dead name now; sends to it fail
    CHECK(mach_port_type(task, doomed, &type) == KERN_SUCCESS && type == MACH_PORT_TYPE_DEAD_NAME);
    msg.header.msgh_remote_port = doomed;
    CHECK(mach_msg_send(&msg.header) == MACH_SEND_INVALID_DEST);
    CHECK(mach_port_deallocate(task, doomed) == KERN_SUCCESS && mach_port_type(task, doomed, &type) == KERN_INVALID_NAME);

    // rights accounting and errors
    CHECK(mach_port_mod_refs(task, port, MACH_PORT_RIGHT_RECEIVE, -1) == KERN_SUCCESS);
    CHECK(mach_port_deallocate(task, port) == KERN_SUCCESS);                // the remaining send right (a dead name)
    CHECK(mach_port_deallocate(task, port) == KERN_INVALID_NAME);
    CHECK(mach_msg(&in.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof in, port, 0, MACH_PORT_NULL) == MACH_RCV_INVALID_NAME);
    CHECK(mach_port_allocate(task, MACH_PORT_RIGHT_PORT_SET, &port) == KERN_INVALID_VALUE);
    msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) | MACH_MSGH_BITS_COMPLEX;
    msg.header.msgh_remote_port = reply;
    CHECK(mach_msg_send(&msg.header) == MACH_SEND_INVALID_TYPE);        // descriptors: not supported
    CHECK(mach_port_mod_refs(task, reply, MACH_PORT_RIGHT_RECEIVE, -1) == KERN_SUCCESS);
}

static semaphore_t sem;
static void *sem_poster(void *arg) { usleep(30000); semaphore_signal(sem); return NULL; }
static void testSemaphores(void) {
    CHECK(semaphore_create(mach_task_self(), &sem, SYNC_POLICY_FIFO, 1) == KERN_SUCCESS);
    CHECK(semaphore_wait(sem) == KERN_SUCCESS);                           // takes the initial count
    mach_timespec_t shortWait = { 0, 20000000 };
    uint64_t t0 = mach_absolute_time();
    CHECK(semaphore_timedwait(sem, shortWait) == KERN_OPERATION_TIMED_OUT && mach_absolute_time() - t0 >= 15000000ull);
    pthread_t t; pthread_create(&t, NULL, sem_poster, NULL);
    mach_timespec_t longWait = { 5, 0 };
    CHECK(semaphore_timedwait(sem, longWait) == KERN_SUCCESS);           // woken by another thread
    pthread_join(t, NULL);
    CHECK(semaphore_signal(sem) == KERN_SUCCESS && semaphore_signal(sem) == KERN_SUCCESS);
    CHECK(semaphore_wait(sem) == KERN_SUCCESS && semaphore_wait(sem) == KERN_SUCCESS);
    CHECK(semaphore_signal_all(sem) == KERN_SUCCESS);                     // no waiters: no count
    CHECK(semaphore_timedwait(sem, (mach_timespec_t){ 0, 1000000 }) == KERN_OPERATION_TIMED_OUT);
    CHECK(semaphore_destroy(mach_task_self(), sem) == KERN_SUCCESS);
    CHECK(semaphore_signal(sem) == KERN_INVALID_ARGUMENT);
}

static void testErrors(void) {
    CHECK(!strcmp(mach_error_string(KERN_SUCCESS), "(os/kern) successful"));
    CHECK(!strcmp(mach_error_string(KERN_INVALID_ARGUMENT), "(os/kern) invalid argument"));
    CHECK(!strcmp(mach_error_string(MACH_RCV_TIMED_OUT), "(ipc/rcv) timed out"));
    CHECK(!strcmp(mach_error_string(MACH_SEND_INVALID_DEST), "(ipc/send) invalid destination port"));
}

int main(int argc, char **argv) {
    @autoreleasepool {
        testTime();
        testTask();
        testThreads();
        testHost();
        testVM();
        testPorts();
        testSemaphores();
        testErrors();
        failures += swift_mach_checks();
        checks += swift_mach_check_count();
        NSLog(@"mach test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
