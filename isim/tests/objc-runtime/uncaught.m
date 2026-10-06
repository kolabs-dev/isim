// Uncaught Objective-C exceptions must terminate the app like iOS does. The mode is the first argument:
//   raise        +[NSException raise:format:] with no handler
//   handler      same, after NSSetUncaughtExceptionHandler (the handler runs before abort)
//   unrecognized message to an object that does not implement it
//   object       @throw of a non-NSException object
//   finally      @finally blocks run while the exception passes, then termination
#import <Foundation/Foundation.h>

static void handler(NSException *e) { printf("HANDLER %s %s\n", e.name.UTF8String, e.reason.UTF8String); fflush(stdout); }
@protocol Missing - (void)notImplemented; @end

int main(int argc, char **argv) {
    @autoreleasepool {
        const char *mode = argc > 1 ? argv[1] : "raise";
        printf("mode %s\n", mode); fflush(stdout);
        if (!strcmp(mode, "handler")) NSSetUncaughtExceptionHandler(handler);
        if (!strcmp(mode, "raise") || !strcmp(mode, "handler"))
            [NSException raise:NSInternalInconsistencyException format:@"state %d is invalid", 3];
        if (!strcmp(mode, "unrecognized")) [(id<Missing>)[NSObject new] notImplemented];
        if (!strcmp(mode, "object")) @throw [NSDate date];
        if (!strcmp(mode, "finally")) {
            @try { [NSException raise:@"FinallyException" format:@"after finally"]; }
            @finally { printf("FINALLY ran\n"); fflush(stdout); }
        }
        printf("NOT REACHED\n");
    }
    return 0;
}
