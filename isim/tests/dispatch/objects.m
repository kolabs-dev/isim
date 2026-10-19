// DispatchTest: dispatch objects and os_log_t as Objective-C objects (Apple's default, OS_OBJECT_USE_OBJC; #459):
// ARC retains and releases them, `strong` properties, collections and blocks hold them, the last release frees them.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <os/log.h>
#include <string.h>

extern int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } fflush(stdout); } while (0)

static int finalized;
static void onFinalize(void *ctx) { (void)ctx; finalized++; }

/* dispatch objects and os_log_t are Objective-C objects in Objective-C, as in Apple's SDK (OS_OBJECT_USE_OBJC, #459):
   ARC retains and releases them, `strong` properties, collections and blocks hold them, and the last release frees
   them (dispatch_release under the hood) */
@interface QueueOwner : NSObject
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_group_t group;
@end
@implementation QueueOwner
@end

void testObjects(void) {
    @autoreleasepool {
        dispatch_queue_t queue = dispatch_queue_create("dispatch.test.arc", NULL);
        CHECK(strcmp(object_getClassName(queue), "OS_dispatch_queue") == 0);
        CHECK([queue isKindOfClass:NSClassFromString(@"OS_dispatch_object")]);
        CHECK([queue isKindOfClass:NSClassFromString(@"OS_object")]);
        CHECK([queue conformsToProtocol:@protocol(NSObject)]);
        CHECK([[queue description] containsString:@"dispatch.test.arc"]);
        NSArray<dispatch_queue_t> *queues = @[queue, queue];                 // retained twice by the array (ARC)
        CHECK(queues[1] == queue);
        dispatch_queue_main_t main = dispatch_get_main_queue();
        CHECK([main isKindOfClass:NSClassFromString(@"OS_dispatch_queue")]);
        dispatch_queue_t asQueue = main;                                     // the main queue type is a queue
        CHECK(asQueue == main);
    }
    @autoreleasepool {                                                       // a strong property owns its queue
        __block int ran = 0;
        QueueOwner *owner = [QueueOwner new];
        owner.queue = dispatch_queue_create("dispatch.test.owned", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(owner.queue, ^{ ran = 1; });
        CHECK(ran == 1);
        dispatch_queue_t captured = owner.queue;                             // a block keeps it alive
        dispatch_block_t later = ^{ dispatch_sync(captured, ^{ ran = 2; }); };
        owner = nil;
        later();
        CHECK(ran == 2);
    }
    finalized = 0;
    @autoreleasepool {
        dispatch_group_t g = dispatch_group_create();
        dispatch_set_finalizer_f(g, onFinalize);
        CHECK(strcmp(object_getClassName(g), "OS_dispatch_group") == 0);
        NSMutableArray *holder = [NSMutableArray arrayWithObject:g];         // +1 through -retain = dispatch_retain
        QueueOwner *owner = [QueueOwner new];
        owner.group = g;
        g = nil;                                                             // -release: the others still own it
        owner = nil;
        CHECK(finalized == 0);
        dispatch_group_t inArray = holder[0];
        dispatch_group_enter(inArray);
        dispatch_group_leave(inArray);
        CHECK(dispatch_group_wait(inArray, DISPATCH_TIME_NOW) == 0);
        inArray = nil;
        [holder removeAllObjects];                                           // last reference: dispatch_release frees it
        CHECK(finalized == 1);
    }
    @autoreleasepool {
        dispatch_semaphore_t s = dispatch_semaphore_create(1);
        CHECK(strcmp(object_getClassName(s), "OS_dispatch_semaphore") == 0);
        CHECK(dispatch_semaphore_wait(s, DISPATCH_TIME_NOW) == 0);
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, dispatch_get_global_queue(0, 0));
        CHECK(strcmp(object_getClassName(source), "OS_dispatch_source") == 0);
        dispatch_data_t data = dispatch_data_create("abc", 3, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
        CHECK([data isKindOfClass:NSClassFromString(@"OS_dispatch_data")]);
        CHECK(dispatch_data_get_size(data) == 3);
        CHECK(dispatch_data_get_size(dispatch_data_empty) == 0);
        NSDictionary *byName = @{ @"source": source, @"data": data };        // any dispatch object in a collection
        CHECK(byName[@"data"] == data);
    }

    // os_log_t: immortal objects of class OS_os_log; ARC retains and releases are no-ops, hashing and equality work
    @autoreleasepool {
        os_log_t log = os_log_create("com.isim.dispatchtest", "arc");
        os_log_t d = OS_LOG_DEFAULT;
        CHECK(strcmp(object_getClassName(log), "OS_os_log") == 0);
        CHECK(strcmp(object_getClassName(d), "OS_os_log") == 0);
        NSArray *logs = @[log, d, log];
        CHECK([logs indexOfObject:d] == 1);
        CHECK([logs[2] isEqual:log] && ![log isEqual:d]);
        CHECK([[NSSet setWithArray:logs] count] == 2);
        logs = nil;
        os_log(log, "os_log_t still usable after ARC released it");
        CHECK(os_log_type_enabled(log, OS_LOG_TYPE_DEFAULT));
    }
}
