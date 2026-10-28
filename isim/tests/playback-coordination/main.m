// Coordinated playback from Objective-C (PlaybackCoordinationTest.app, issue #392): AVPlayer's playbackCoordinator and
// its delegate's item identifiers, two players kept in step by an AVPlaybackCoordinationMedium, suspensions and their
// reasons, participant limits, the notifications, and an AVDelegatingPlaybackCoordinator issuing play, pause and seek
// commands (CMTime through the categories) to an Objective-C delegate.
#import <AVFoundation/AVFoundation.h>
#include <stdio.h>
#include <math.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static void spin(NSTimeInterval seconds) {
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}
static BOOL wait_until(BOOL (^cond)(void)) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!cond() && [end timeIntervalSinceNow] > 0) spin(0.02);
    return cond();
}

@interface Namer : NSObject <AVPlayerPlaybackCoordinatorDelegate>
@end
@implementation Namer
- (NSString *)playbackCoordinator:(AVPlayerPlaybackCoordinator *)coordinator identifierForPlayerItem:(AVPlayerItem *)playerItem { return @"movie"; }
@end

@interface Controller : NSObject <AVPlaybackCoordinatorPlaybackControlDelegate>
@property NSMutableArray<NSString *> *commands;
@end
@implementation Controller
- (instancetype)init { if ((self = [super init])) _commands = [NSMutableArray array]; return self; }
- (void)playbackCoordinator:(AVDelegatingPlaybackCoordinator *)c didIssuePlayCommand:(AVDelegatingPlaybackCoordinatorPlayCommand *)cmd completionHandler:(void (^)(void))done {
    [_commands addObject:[NSString stringWithFormat:@"play %.1f at %.1f item %@ host %d", cmd.rate, CMTimeGetSeconds(cmd.itemTime),
                          cmd.expectedCurrentItemIdentifier, CMTIME_IS_NUMERIC(cmd.hostClockTime)]];
    done();
}
- (void)playbackCoordinator:(AVDelegatingPlaybackCoordinator *)c didIssuePauseCommand:(AVDelegatingPlaybackCoordinatorPauseCommand *)cmd completionHandler:(void (^)(void))done {
    [_commands addObject:[NSString stringWithFormat:@"pause item %@", cmd.expectedCurrentItemIdentifier]];
    done();
}
- (void)playbackCoordinator:(AVDelegatingPlaybackCoordinator *)c didIssueSeekCommand:(AVDelegatingPlaybackCoordinatorSeekCommand *)cmd completionHandler:(void (^)(void))done {
    [_commands addObject:[NSString stringWithFormat:@"seek %.1f", CMTimeGetSeconds(cmd.itemTime)]];
    done();
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"movie" withExtension:@"mp4"];
        CHECK(url != nil, "the movie is in the bundle");

        // two players, one medium
        AVPlayer *a = [AVPlayer playerWithURL:url], *b = [AVPlayer playerWithURL:url];
        AVPlayerPlaybackCoordinator *ca = a.playbackCoordinator, *cb = b.playbackCoordinator;
        CHECK(ca != nil && ca == a.playbackCoordinator && ca.player == a, "AVPlayer.playbackCoordinator is the player's");
        Namer *namer = [Namer new];
        ca.delegate = namer; cb.delegate = namer;
        CHECK(ca.delegate == namer, "the coordinator's delegate");
        __block int others = 0;
        id obs = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlaybackCoordinatorOtherParticipantsDidChangeNotification object:ca
                                                                    queue:nil usingBlock:^(NSNotification *n) { others++; }];
        AVPlaybackCoordinationMedium *medium = [AVPlaybackCoordinationMedium new];
        NSError *error = nil;
        CHECK([ca coordinateUsingPlaybackCoordinationMedium:medium error:&error] && error == nil, "a joins the medium");
        CHECK([cb coordinateUsingPlaybackCoordinationMedium:medium error:&error] && error == nil, "b joins the medium");
        CHECK(medium.connectedPlaybackCoordinators.count == 2 && ca.playbackCoordinationMedium == medium, "the medium connects %lu",
              (unsigned long)medium.connectedPlaybackCoordinators.count);
        CHECK(ca.otherParticipants.count == 1 && ca.otherParticipants[0].identifier != nil && ca.otherParticipants[0].isReadyToPlay,
              "a has %lu other participant", (unsigned long)ca.otherParticipants.count);
        CHECK(others >= 1, "the other-participants notification (%d)", others);
        [[NSNotificationCenter defaultCenter] removeObserver:obs];

        [a play];
        CHECK(wait_until(^{ return (BOOL)(b.rate == 1); }), "b plays when a plays (rate %.1f)", b.rate);
        spin(1.5);
        [a pause];
        CHECK(wait_until(^{ return (BOOL)(b.rate == 0); }), "b pauses when a pauses");
        double ta = CMTimeGetSeconds(a.currentTime), tb = CMTimeGetSeconds(b.currentTime);
        CHECK(ta > 1 && fabs(ta - tb) < 0.3, "paused together: a %.2f b %.2f", ta, tb);

        // suspensions: while b is suspended it neither follows nor leads
        __block int reasonChanges = 0;
        obs = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification object:cb
                                                                 queue:nil usingBlock:^(NSNotification *n) { reasonChanges++; }];
        AVCoordinatedPlaybackSuspension *s = [cb beginSuspensionForReason:AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime];
        CHECK([s.reason isEqualToString:AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime] && s.beginDate != nil, "suspension reason %s",
              s.reason.UTF8String);
        CHECK([cb.suspensionReasons isEqualToArray:@[AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime]], "suspension reasons");
        [a play];
        spin(0.5);
        CHECK(b.rate == 0, "a suspended b does not follow");
        [s endProposingNewTime:CMTimeMakeWithSeconds(5, 600)];
        CHECK(cb.suspensionReasons.count == 0 && reasonChanges == 2, "the suspension ended (%d changes)", reasonChanges);
        CHECK(wait_until(^{ return (BOOL)(fabs(CMTimeGetSeconds(a.currentTime) - 5) < 0.6); }), "ending it proposes 5 s to the group: a at %.2f",
              CMTimeGetSeconds(a.currentTime));
        [a pause];
        [[NSNotificationCenter defaultCenter] removeObserver:obs];

        cb.suspensionReasonsThatTriggerWaiting = @[AVCoordinatedPlaybackSuspensionReasonStallRecovery, AVCoordinatedPlaybackSuspensionReasonPlayingInterstitial];
        CHECK(cb.suspensionReasonsThatTriggerWaiting.count == 2, "reasons that trigger waiting");
        [cb setParticipantLimit:3 forWaitingOutSuspensionsWithReason:AVCoordinatedPlaybackSuspensionReasonStallRecovery];
        CHECK([cb participantLimitForWaitingOutSuspensionsWithReason:AVCoordinatedPlaybackSuspensionReasonStallRecovery] == 3, "participant limit");
        cb.pauseSnapsToMediaTimeOfOriginator = NO;
        CHECK(!cb.pauseSnapsToMediaTimeOfOriginator, "pauseSnapsToMediaTimeOfOriginator");
        CMTime expected = [ca expectedItemTimeAtHostTime:kCMTimeInvalid];
        CHECK(CMTIME_IS_NUMERIC(expected) && CMTimeGetSeconds(expected) > 4, "expected item time %.2f", CMTimeGetSeconds(expected));
        CHECK([ca coordinateUsingPlaybackCoordinationMedium:nil error:&error] && medium.connectedPlaybackCoordinators.count == 1, "a leaves the medium");

        // a delegating coordinator: the app plays; commands go to its delegate
        Controller *ctl = [Controller new];
        AVDelegatingPlaybackCoordinator *d = [[AVDelegatingPlaybackCoordinator alloc] initWithPlaybackControlDelegate:ctl];
        CHECK(d.playbackControlDelegate == ctl, "the playback control delegate");
        [d transitionToItemWithIdentifier:@"clip" proposingInitialTimingBasedOnTimebase:NULL];
        CHECK([d.currentItemIdentifier isEqualToString:@"clip"], "current item %s", d.currentItemIdentifier.UTF8String);
        [d coordinateRateChangeToRate:1 options:AVDelegatingPlaybackCoordinatorRateChangeOptionPlayImmediately];
        CHECK(ctl.commands.count == 1 && [ctl.commands[0] isEqualToString:@"play 1.0 at 0.0 item clip host 1"], "%s", ctl.commands.lastObject.UTF8String);
        [d coordinateSeekToTime:CMTimeMake(3, 1) options:AVDelegatingPlaybackCoordinatorSeekOptionResumeImmediately];
        CHECK([ctl.commands containsObject:@"seek 3.0"] && [ctl.commands.lastObject hasPrefix:@"play 1.0 at 3.0"], "%s", [ctl.commands componentsJoinedByString:@", "].UTF8String);
        [d coordinateRateChangeToRate:0 options:0];
        CHECK([ctl.commands.lastObject isEqualToString:@"pause item clip"], "%s", ctl.commands.lastObject.UTF8String);
        NSUInteger n = ctl.commands.count;
        [d reapplyCurrentItemStateToPlaybackControlDelegate];
        CHECK(ctl.commands.count > n, "reapplying issues the state again");

        printf("playback coordination: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
