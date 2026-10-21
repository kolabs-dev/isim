#pragma once
/* isim GameKit for Objective-C: the classes are the GameKit Swift overlay's (GameKit.framework re-exports
 * libswiftGameKit.dylib): a local Game Center (the device's player, the other isim devices on this computer and test
 * players), with leaderboards, achievements, the dashboard and access point, real-time and turn-based matches, saved
 * games, challenges and game activities. Swift uses the overlay; these declarations are hidden from Swift. The classes
 * are not subclassable from Objective-C, and GameKit's view controllers are UIViewControllers on isim. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GameKit/GKDefines.h>
#import <GameKit/GKError.h>
#import <GameKit/GKPlayer.h>
#import <GameKit/GKEventListener.h>
#import <GameKit/GKLocalPlayer.h>
#import <GameKit/GKSavedGame.h>
#import <GameKit/GKLeaderboard.h>
#import <GameKit/GKAchievement.h>
#import <GameKit/GKChallenge.h>
#import <GameKit/GKGameCenterViewController.h>
#import <GameKit/GKMatchmaker.h>
#import <GameKit/GKMatch.h>
#import <GameKit/GKMatchmakerViewController.h>
#import <GameKit/GKTurnBasedMatch.h>
#import <GameKit/GKTurnBasedMatchmakerViewController.h>
#import <GameKit/GKFriendRequestComposeViewController.h>
#import <GameKit/GKGameActivity.h>
