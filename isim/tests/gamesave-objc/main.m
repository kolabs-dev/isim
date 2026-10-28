// GameSave from Objective-C (GameSaveObjCTest.app, issue #393): GSSyncedDirectory opens a container, reports its state
// through key-value observing, uploads a save, closes; a version another device uploaded meanwhile (written into the
// simulated iCloud, $ISIM_GAMESAVE) conflicts with a local change, and resolving with the iCloud version keeps it.
#import <GameSave/GameSave.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static BOOL wait_until(BOOL (^cond)(void)) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!cond() && [end timeIntervalSinceNow] > 0) [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    return cond();
}

@interface Watcher : NSObject
@property int changes;
@end
@implementation Watcher
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context { self.changes++; }
@end

static NSString *readSave(NSURL *dir) {
    return [NSString stringWithContentsOfURL:[dir URLByAppendingPathComponent:@"save.txt"] encoding:NSUTF8StringEncoding error:NULL];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *container = @"iCloud.dev.isim.gamesave-objc-test";
        CHECK([GameSaveErrorDomain isEqualToString:@"GameSaveErrorDomain"], "GameSaveErrorDomain");

        GSSyncedDirectory *d = [GSSyncedDirectory openForContainerIdentifier:container];
        Watcher *w = [Watcher new];
        [d addObserver:w forKeyPath:@"directoryState" options:0 context:NULL];
        CHECK(wait_until(^{ return (BOOL)(d.directoryState.state == GSSyncStateReady); }), "ready (%s)", d.directoryState.description.UTF8String);
        CHECK(w.changes >= 1, "directoryState is key-value observable (%d)", w.changes);
        NSURL *url = d.directoryState.url;
        CHECK(url != nil && d.directoryState.conflictedVersions == nil && d.directoryState.error == nil, "a local directory");
        [@"level 1" writeToURL:[url URLByAppendingPathComponent:@"save.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        __block int uploaded = -1;
        [d triggerPendingUploadWithCompletionHandler:^(BOOL ok) { uploaded = ok; }];
        CHECK(wait_until(^{ return (BOOL)(uploaded >= 0); }) && uploaded == 1, "upload succeeded");
        __block BOOL finished = NO;
        [d finishSyncingWithCompletionHandler:^{ finished = YES; }];
        CHECK(wait_until(^{ return finished; }), "finished syncing");
        [d removeObserver:w forKeyPath:@"directoryState"];
        [d close];
        CHECK(wait_until(^{ return (BOOL)(d.directoryState.state == GSSyncStateClosed); }), "closed");

        // the simulated iCloud has it; another device uploads version 2 while this one changes its copy
        NSString *cloud = [NSProcessInfo.processInfo.environment[@"ISIM_GAMESAVE"] stringByAppendingPathComponent:container];
        CHECK([[NSString stringWithContentsOfFile:[cloud stringByAppendingPathComponent:@"files/save.txt"] encoding:NSUTF8StringEncoding error:NULL]
               isEqualToString:@"level 1"], "the save is in iCloud");
        [@"level 7" writeToFile:[cloud stringByAppendingPathComponent:@"files/save.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSDictionary *meta = @{@"version": @2, @"modified": @([NSDate date].timeIntervalSince1970), @"device": @"Sam's iPad"};
        [[NSJSONSerialization dataWithJSONObject:meta options:0 error:NULL] writeToFile:[cloud stringByAppendingPathComponent:@"meta.json"] atomically:YES];
        [@"level 2" writeToURL:[url URLByAppendingPathComponent:@"save.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        GSSyncedDirectory *e = [GSSyncedDirectory openForContainerIdentifier:container];
        CHECK(wait_until(^{ return (BOOL)(e.directoryState.state == GSSyncStateConflicted); }), "conflicted (%s)", e.directoryState.description.UTF8String);
        NSArray<GSSyncedDirectoryVersion *> *versions = e.directoryState.conflictedVersions;
        CHECK(versions.count == 2, "two versions");
        GSSyncedDirectoryVersion *local = nil, *remote = nil;
        for (GSSyncedDirectoryVersion *v in versions) { if (v.isLocal) local = v; else remote = v; }
        CHECK(local && [readSave(local.url) isEqualToString:@"level 2"], "the local version: %s", readSave(local.url).UTF8String);
        CHECK(remote && [readSave(remote.url) isEqualToString:@"level 7"] && [remote.localizedNameOfSavingComputer isEqualToString:@"Sam's iPad"]
              && remote.modifiedDate != nil, "the iCloud version from %s", remote.localizedNameOfSavingComputer.UTF8String);
        CHECK([remote.description containsString:@"iCloud"], "%s", remote.description.UTF8String);
        [e resolveConflictsWithVersion:remote];
        CHECK(wait_until(^{ return (BOOL)(e.directoryState.state == GSSyncStateReady); }), "ready after resolving");
        CHECK([readSave(e.directoryState.url) isEqualToString:@"level 7"], "the iCloud version kept: %s", readSave(e.directoryState.url).UTF8String);
        [e close];

        printf("gamesave objc: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
