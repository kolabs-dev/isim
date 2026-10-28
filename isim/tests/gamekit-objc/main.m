// GameKit from Objective-C (GameKitObjCTest.app, issue #559): #import <GameKit/GameKit.h>, -framework GameKit, over
// isim's local Game Center (isim-GameCenter.json next to the app; test players from `isim gamecenter`). Signs in, then
// posts a score and ranks the leaderboard, reports and loads achievements and their descriptions, loads the player's
// photo, shows the access point, saves and fetches a game, plays a turn-based match to its end, and listens (a
// GKLocalPlayerListener) for a challenge. The "dashboard" and "matchmaker" buttons show GKGameCenterViewController and
// GKMatchmakerViewController, whose delegates report when they close. Results go to the log ("GameKitObjC: ...").
#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>

static void say(NSString *s) { NSLog(@"GameKitObjC: %@", s); }
static NSString *const Board = @"dev.isim.gkobjc.high_score";

@interface TestViewController : UIViewController <GKLocalPlayerListener, GKGameCenterControllerDelegate, GKMatchmakerViewControllerDelegate>
@end

@implementation TestViewController

- (void)button:(NSString *)title y:(CGFloat)y action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.frame = CGRectMake(20, y, 200, 44);
    b.accessibilityIdentifier = title;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self button:@"dashboard" y:200 action:@selector(dashboard)];
    [self button:@"matchmaker" y:260 action:@selector(matchmaker)];
    GKLocalPlayer *me = GKLocalPlayer.localPlayer;
    say([NSString stringWithFormat:@"before sign-in authenticated %d same %d", me.isAuthenticated, me == GKLocalPlayer.local]);
    __weak TestViewController *weakSelf = self;
    me.authenticateHandler = ^(UIViewController *vc, NSError *error) {
        GKLocalPlayer *p = GKLocalPlayer.local;
        say([NSString stringWithFormat:@"authenticated %d error %@ player %@ invitable %d underage %d", p.isAuthenticated, error ? error.domain : @"none",
             p.alias, p.isInvitable, p.isUnderage]);
        if (p.isAuthenticated) [weakSelf signedIn];
    };
}

- (void)signedIn {
    GKLocalPlayer *me = GKLocalPlayer.local;
    [me registerListener:self];
    [me loadPhotoForSize:GKPhotoSizeNormal withCompletionHandler:^(UIImage *photo, NSError *error) {
        say([NSString stringWithFormat:@"photo %.0fx%.0f", photo.size.width * photo.scale, photo.size.height * photo.scale]);
    }];
    GKAccessPoint.shared.location = GKAccessPointLocationTopTrailing;
    GKAccessPoint.shared.active = YES;
    say([NSString stringWithFormat:@"access point active %d location %ld", GKAccessPoint.shared.isActive, (long)GKAccessPoint.shared.location]);
    [self leaderboards];
}

- (void)leaderboards {
    GKLocalPlayer *me = GKLocalPlayer.local;
    [GKLeaderboard submitScore:1200 context:7 player:me leaderboardIDs:@[Board] completionHandler:^(NSError *error) {
        [GKLeaderboard loadLeaderboardsWithIDs:@[Board] completionHandler:^(NSArray<GKLeaderboard *> *boards, NSError *e) {
            GKLeaderboard *b = boards.firstObject;
            [b loadEntriesForPlayerScope:GKLeaderboardPlayerScopeGlobal timeScope:GKLeaderboardTimeScopeAllTime range:NSMakeRange(1, 10)
                       completionHandler:^(GKLeaderboardEntry *mine, NSArray<GKLeaderboardEntry *> *entries, NSInteger total, NSError *e2) {
                NSMutableArray *ranks = [NSMutableArray array];
                for (GKLeaderboardEntry *x in entries) [ranks addObject:[NSString stringWithFormat:@"%ld. %@ %@", (long)x.rank, x.player.alias, x.formattedScore]];
                say([NSString stringWithFormat:@"leaderboard %@ \"%@\" type %ld: %@ | me #%ld of %ld context %lu error %@", b.baseLeaderboardID, b.title,
                     (long)b.type, [ranks componentsJoinedByString:@"; "], (long)mine.rank, (long)total, (unsigned long)mine.context,
                     error ? error.domain : @"none"]);
                [self achievements];
            }];
        }];
    }];
}

- (void)achievements {
    GKAchievement *win = [[GKAchievement alloc] initWithIdentifier:@"dev.isim.gkobjc.first_win"];
    win.percentComplete = 100;
    GKAchievement *gems = [[GKAchievement alloc] initWithIdentifier:@"dev.isim.gkobjc.collector"];
    gems.percentComplete = 40;
    [GKAchievement reportAchievements:@[win, gems] withCompletionHandler:^(NSError *error) {
        [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray<GKAchievement *> *list, NSError *e) {
            NSMutableArray *parts = [NSMutableArray array];
            for (GKAchievement *a in [list sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:YES]]])
                [parts addObject:[NSString stringWithFormat:@"%@ %.0f%% completed %d", a.identifier, a.percentComplete, a.isCompleted]];
            say([NSString stringWithFormat:@"achievements reported error %@: %@", error ? error.domain : @"none", [parts componentsJoinedByString:@", "]]);
            [GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray<GKAchievementDescription *> *ds, NSError *e2) {
                NSInteger points = 0;
                for (GKAchievementDescription *d in ds) points += d.maximumPoints;
                say([NSString stringWithFormat:@"descriptions %lu points %ld first \"%@\" hidden %d", (unsigned long)ds.count, (long)points,
                     ds.firstObject.title, ds.firstObject.isHidden]);
                [self savedGames];
            }];
        }];
    }];
}

- (void)savedGames {
    GKLocalPlayer *me = GKLocalPlayer.local;
    [me saveGameData:[@"level 3" dataUsingEncoding:NSUTF8StringEncoding] withName:@"slot1" completionHandler:^(GKSavedGame *saved, NSError *error) {
        [me fetchSavedGamesWithCompletionHandler:^(NSArray<GKSavedGame *> *games, NSError *e) {
            [games.firstObject loadDataWithCompletionHandler:^(NSData *data, NSError *e2) {
                say([NSString stringWithFormat:@"saved %@ on %@ error %@; fetched %lu data \"%@\"", saved.name, saved.deviceName, error ? error.domain : @"none",
                     (unsigned long)games.count, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
                [self turnBased];
            }];
        }];
    }];
}

- (void)turnBased {
    GKMatchRequest *r = [[GKMatchRequest alloc] init];
    r.minPlayers = 2;
    r.maxPlayers = 2;
    say([NSString stringWithFormat:@"max players turn-based %lu peer-to-peer %lu", (unsigned long)[GKMatchRequest maxPlayersAllowedForMatchOfType:GKMatchTypeTurnBased],
         (unsigned long)[GKMatchRequest maxPlayersAllowedForMatchOfType:GKMatchTypePeerToPeer]]);
    [GKTurnBasedMatch findMatchForRequest:r withCompletionHandler:^(GKTurnBasedMatch *match, NSError *error) {
        GKTurnBasedParticipant *mine = match.participants[0], *other = match.participants[1];
        say([NSString stringWithFormat:@"turn-based status %ld participants %lu mine %ld other %ld current is me %d error %@", (long)match.status,
             (unsigned long)match.participants.count, (long)mine.status, (long)other.status, match.currentParticipant == mine,
             error ? error.domain : @"none"]);
        NSData *board = [@"x-o" dataUsingEncoding:NSUTF8StringEncoding];
        [match saveCurrentTurnWithMatchData:board completionHandler:^(NSError *e) {
            [GKTurnBasedMatch loadMatchWithID:match.matchID withCompletionHandler:^(GKTurnBasedMatch *loaded, NSError *e2) {
                [loaded loadMatchDataWithCompletionHandler:^(NSData *data, NSError *e3) {
                    say([NSString stringWithFormat:@"saved turn error %@ loaded %d data \"%@\"", e ? e.domain : @"none", [loaded isEqual:match],
                         [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]);
                    loaded.participants[0].matchOutcome = GKTurnBasedMatchOutcomeWon;
                    [loaded endMatchInTurnWithMatchData:board completionHandler:^(NSError *e4) {
                        say([NSString stringWithFormat:@"ended error %@ status %ld outcome %ld", e4 ? e4.domain : @"none", (long)loaded.status,
                             (long)loaded.participants[0].matchOutcome]);
                        [loaded removeWithCompletionHandler:^(NSError *e5) {
                            [GKTurnBasedMatch loadMatchesWithCompletionHandler:^(NSArray<GKTurnBasedMatch *> *left, NSError *e6) {
                                say([NSString stringWithFormat:@"removed error %@ matches left %lu", e5 ? e5.domain : @"none", (unsigned long)left.count]);
                                [self errors];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)errors {
    GKMatchRequest *bad = [[GKMatchRequest alloc] init];
    bad.minPlayers = 1;
    [GKTurnBasedMatch findMatchForRequest:bad withCompletionHandler:^(GKTurnBasedMatch *match, NSError *error) {
        say([NSString stringWithFormat:@"bad request %@ domain %@ code %ld is invalid %d", match ? @"matched" : @"refused", error.domain, (long)error.code,
             [error.domain isEqualToString:GKErrorDomain] && error.code == GKErrorMatchRequestInvalid]);
        [self more];
    }];
}

// issue #394: challenge definitions, release states, identity verification, queues, voice chat, constants (the iOS 26
// classes are used whatever the emulated version: isim implements them on every version)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
- (void)more {
    [GKChallengeDefinition loadChallengeDefinitionsWithCompletionHandler:^(NSArray<GKChallengeDefinition *> *defs, NSError *error) {
        GKChallengeDefinition *c = defs.firstObject;
        say([NSString stringWithFormat:@"challenge definitions %lu: %@ \"%@\" leaderboard %@ days %ld prereleased %d",
             (unsigned long)defs.count, c.identifier, c.title, c.leaderboard.baseLeaderboardID, (long)c.durationOptions.firstObject.day,
             c.releaseState == GKReleaseStatePrereleased]);
        [GKLeaderboard loadLeaderboardsWithIDs:@[Board] completionHandler:^(NSArray<GKLeaderboard *> *boards, NSError *e2) {
            GKLeaderboard *b = boards.firstObject;
            say([NSString stringWithFormat:@"leaderboard description \"%@\" hidden %d released %d", b.leaderboardDescription, b.isHidden,
                 b.releaseState == GKReleaseStateReleased]);
            [GKLocalPlayer.localPlayer fetchItemsForIdentityVerificationSignature:^(NSURL *url, NSData *signature, NSData *salt, uint64_t timestamp, NSError *e3) {
                say([NSString stringWithFormat:@"identity verification file %d signature %d salt %lu timestamp %d error %@", url.isFileURL,
                     signature.length > 60, (unsigned long)salt.length, timestamp > 1700000000000ULL, e3 ? @"yes" : @"none"]);
                [GKMatchmaker.sharedMatchmaker queryQueueActivity:@"dev.isim.queue" withCompletionHandler:^(NSInteger n, NSError *e4) {
                    say([NSString stringWithFormat:@"queue activity %ld voip %d debug mode %ld no longer available %@ match type %ld",
                         (long)n, [GKVoiceChat isVoIPAllowed], (long)GKErrorDebugMode, GKPlayerIDNoLongerAvailable, (long)GKMatchTypeHosted]);
                    say(@"ready");
                }];
            }];
        }];
    }];
}
#pragma clang diagnostic pop

// MARK: listener

- (void)player:(GKPlayer *)player didReceiveChallenge:(GKChallenge *)challenge {
    say([NSString stringWithFormat:@"challenge received from %@ \"%@\" state %ld score %d", challenge.issuingPlayer.alias, challenge.message,
         (long)challenge.state, [challenge isKindOfClass:[GKScoreChallenge class]]]);
}
- (void)player:(GKPlayer *)player wantsToPlayChallenge:(GKChallenge *)challenge {
    say([NSString stringWithFormat:@"wants to play challenge from %@ on %@", challenge.issuingPlayer.alias, ((GKScoreChallenge *)challenge).leaderboardID]);
}
- (void)player:(GKPlayer *)player matchEnded:(GKTurnBasedMatch *)match {
    say([NSString stringWithFormat:@"listener: match ended status %ld", (long)match.status]);
}

// MARK: view controllers

- (void)dashboard {
    GKGameCenterViewController *gc = [[GKGameCenterViewController alloc] initWithState:GKGameCenterViewControllerStateLeaderboards];
    gc.gameCenterDelegate = self;
    say([NSString stringWithFormat:@"dashboard state %ld", (long)gc.viewState]);
    [self presentViewController:gc animated:YES completion:nil];
}
- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController {
    say(@"dashboard finished");
    [gameCenterViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)matchmaker {
    GKMatchRequest *r = [[GKMatchRequest alloc] init];
    r.minPlayers = 2;
    r.maxPlayers = 2;
    GKMatchmakerViewController *mm = [[GKMatchmakerViewController alloc] initWithMatchRequest:r];
    mm.matchmakerDelegate = self;
    mm.matchmakingMode = GKMatchmakingModeAutomatchOnly;
    say([NSString stringWithFormat:@"matchmaker delegate %d mode %ld players %lu-%lu", mm.matchmakerDelegate == self, (long)mm.matchmakingMode,
         (unsigned long)mm.matchRequest.minPlayers, (unsigned long)mm.matchRequest.maxPlayers]);
    [self presentViewController:mm animated:YES completion:nil];
}
- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController {
    say(@"matchmaker cancelled");
    [viewController dismissViewControllerAnimated:YES completion:nil];
}
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error {
    say([NSString stringWithFormat:@"matchmaker failed %@", error.domain]);
}
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match {
    say(@"matchmaker found a match");
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[TestViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
