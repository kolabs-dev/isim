#pragma once
/* isim GameKit: saved games (kept in the device data; see the overlay's GameKitMore.swift). */
#import <GameKit/GKLocalPlayer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface GKSavedGame : NSObject
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly, nullable) NSString *deviceName;
@property (nonatomic, readonly, nullable) NSDate *modificationDate;
- (void)loadDataWithCompletionHandler:(void (^ _Nullable)(NSData * _Nullable data, NSError * _Nullable error))handler;
@end
@interface GKLocalPlayer (GKSavedGame)
- (void)fetchSavedGamesWithCompletionHandler:(void (^ _Nullable)(NSArray<GKSavedGame *> * _Nullable savedGames, NSError * _Nullable error))handler;
- (void)saveGameData:(NSData *)data withName:(NSString *)name
   completionHandler:(void (^ _Nullable)(GKSavedGame * _Nullable savedGame, NSError * _Nullable error))handler;
- (void)deleteSavedGamesWithName:(NSString *)name completionHandler:(void (^ _Nullable)(NSError * _Nullable error))handler;
- (void)resolveConflictingSavedGames:(NSArray<GKSavedGame *> *)conflictingSavedGames withData:(NSData *)data
                   completionHandler:(void (^ _Nullable)(NSArray<GKSavedGame *> * _Nullable savedGames, NSError * _Nullable error))handler;
@end
NS_ASSUME_NONNULL_END
#endif
