#pragma once
/* isim GameKit: a real-time match (data goes over local connections between the isim devices). */
#import <GameKit/GKPlayer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKMatch;
typedef NS_ENUM(NSInteger, GKMatchSendDataMode) { GKMatchSendDataReliable = 0, GKMatchSendDataUnreliable };
typedef NS_ENUM(NSInteger, GKPlayerConnectionState) { GKPlayerStateUnknown = 0, GKPlayerStateConnected, GKPlayerStateDisconnected };
@protocol GKMatchDelegate <NSObject>
@optional
- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromRemotePlayer:(GKPlayer *)player;
- (void)match:(GKMatch *)match didReceiveData:(NSData *)data forRecipient:(GKPlayer *)recipient fromRemotePlayer:(GKPlayer *)player;
- (void)match:(GKMatch *)match player:(GKPlayer *)player didChangeConnectionState:(GKPlayerConnectionState)state;
- (void)match:(GKMatch *)match didFailWithError:(nullable NSError *)error;
- (BOOL)match:(GKMatch *)match shouldReinviteDisconnectedPlayer:(GKPlayer *)player;
@end
@interface GKMatch : NSObject
@property (nonatomic, readonly) NSArray<GKPlayer *> *players;
@property (nonatomic, weak, nullable) id<GKMatchDelegate> delegate;
@property (nonatomic, readonly) NSUInteger expectedPlayerCount;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *properties;
@property (nonatomic, readonly, nullable) NSDictionary<GKPlayer *, NSDictionary<NSString *, id> *> *playerProperties;
- (BOOL)sendData:(NSData *)data toPlayers:(NSArray<GKPlayer *> *)players dataMode:(GKMatchSendDataMode)mode error:(NSError **)error;
- (BOOL)sendDataToAllPlayers:(NSData *)data withDataMode:(GKMatchSendDataMode)mode error:(NSError **)error;
- (void)disconnect;
- (void)chooseBestHostingPlayerWithCompletionHandler:(void (^)(GKPlayer * _Nullable player))completionHandler;
- (void)rematchWithCompletionHandler:(void (^ _Nullable)(GKMatch * _Nullable match, NSError * _Nullable error))completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
