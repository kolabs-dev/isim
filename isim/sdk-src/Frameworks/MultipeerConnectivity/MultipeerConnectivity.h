#pragma once
/* isim MultipeerConnectivity for Objective-C: the classes are the MultipeerConnectivity Swift overlay's
   (MultipeerConnectivity.framework re-exports libswiftMultipeerConnectivity.dylib), with the same peers as Swift:
   advertisers are Bonjour services, browsers find them, and invited peers talk over TCP (data, resources, streams),
   between apps on isim devices (not real iOS devices). Swift uses the overlay; these declarations are hidden from
   Swift. The classes are not subclassable from Objective-C. */
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class MCSession, MCNearbyServiceAdvertiser, MCNearbyServiceBrowser, MCBrowserViewController, MCAdvertiserAssistant;

FOUNDATION_EXPORT NSString * const MCErrorDomain;
typedef NS_ENUM(NSInteger, MCErrorCode) {
    MCErrorUnknown = 0, MCErrorNotConnected = 1, MCErrorInvalidParameter = 2, MCErrorUnsupported = 3, MCErrorTimedOut = 4,
    MCErrorCancelled = 5, MCErrorUnavailable = 6,
};
FOUNDATION_EXPORT NSUInteger const kMCSessionMinimumNumberOfPeers;
FOUNDATION_EXPORT NSUInteger const kMCSessionMaximumNumberOfPeers;

@interface MCPeerID : NSObject <NSCopying>
- (instancetype)initWithDisplayName:(NSString *)myDisplayName NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, nonatomic) NSString *displayName;
@end

typedef NS_ENUM(NSInteger, MCSessionSendDataMode) { MCSessionSendDataReliable = 0, MCSessionSendDataUnreliable = 1 };
typedef NS_ENUM(NSInteger, MCSessionState) { MCSessionStateNotConnected = 0, MCSessionStateConnecting = 1, MCSessionStateConnected = 2 };
typedef NS_ENUM(NSInteger, MCEncryptionPreference) { MCEncryptionOptional = 0, MCEncryptionRequired = 1, MCEncryptionNone = 2 };

@protocol MCSessionDelegate <NSObject>
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state;
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID;
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID;
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID
    withProgress:(NSProgress *)progress;
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID
    atURL:(nullable NSURL *)localURL withError:(nullable NSError *)error;
@optional
- (void)session:(MCSession *)session didReceiveCertificate:(nullable NSArray *)certificate fromPeer:(MCPeerID *)peerID
    certificateHandler:(void (^)(BOOL accept))certificateHandler;
@end

@interface MCSession : NSObject
- (instancetype)initWithPeer:(MCPeerID *)myPeerID;
- (instancetype)initWithPeer:(MCPeerID *)myPeerID securityIdentity:(nullable NSArray *)identity
        encryptionPreference:(MCEncryptionPreference)encryptionPreference NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (weak, nullable, nonatomic) id<MCSessionDelegate> delegate;
@property (readonly, nonatomic) MCPeerID *myPeerID;
@property (readonly, nullable, nonatomic) NSArray *securityIdentity;
@property (readonly, nonatomic) MCEncryptionPreference encryptionPreference;
@property (readonly, nonatomic) NSArray<MCPeerID *> *connectedPeers;
- (BOOL)sendData:(NSData *)data toPeers:(NSArray<MCPeerID *> *)peerIDs withMode:(MCSessionSendDataMode)mode error:(NSError **)error;
- (nullable NSProgress *)sendResourceAtURL:(NSURL *)resourceURL withName:(NSString *)resourceName toPeer:(MCPeerID *)peerID
                     withCompletionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (nullable NSOutputStream *)startStreamWithName:(NSString *)streamName toPeer:(MCPeerID *)peerID error:(NSError **)error;
- (void)disconnect;
/* not on isim (no out-of-band connections): the data is nil with an error; connecting does nothing */
- (void)nearbyConnectionDataForPeer:(MCPeerID *)peerID withCompletionHandler:(void (^)(NSData * _Nullable connectionData, NSError * _Nullable error))completionHandler;
- (void)connectPeer:(MCPeerID *)peerID withNearbyConnectionData:(NSData *)data;
- (void)cancelConnectPeer:(MCPeerID *)peerID;
@end

@protocol MCNearbyServiceAdvertiserDelegate <NSObject>
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(nullable NSData *)context
    invitationHandler:(void (^)(BOOL accept, MCSession * _Nullable session))invitationHandler;
@optional
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error;
@end
@interface MCNearbyServiceAdvertiser : NSObject
- (instancetype)initWithPeer:(MCPeerID *)myPeerID discoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info
                 serviceType:(NSString *)serviceType NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)startAdvertisingPeer;
- (void)stopAdvertisingPeer;
@property (weak, nullable, nonatomic) id<MCNearbyServiceAdvertiserDelegate> delegate;
@property (readonly, nonatomic) MCPeerID *myPeerID;
@property (readonly, nullable, nonatomic) NSDictionary<NSString *, NSString *> *discoveryInfo;
@property (readonly, nonatomic) NSString *serviceType;
@end

@protocol MCNearbyServiceBrowserDelegate <NSObject>
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info;
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID;
@optional
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error;
@end
@interface MCNearbyServiceBrowser : NSObject
- (instancetype)initWithPeer:(MCPeerID *)myPeerID serviceType:(NSString *)serviceType NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)startBrowsingForPeers;
- (void)stopBrowsingForPeers;
- (void)invitePeer:(MCPeerID *)peerID toSession:(MCSession *)session withContext:(nullable NSData *)context timeout:(NSTimeInterval)timeout;
@property (weak, nullable, nonatomic) id<MCNearbyServiceBrowserDelegate> delegate;
@property (readonly, nonatomic) MCPeerID *myPeerID;
@property (readonly, nonatomic) NSString *serviceType;
@end

@protocol MCBrowserViewControllerDelegate <NSObject>
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController;
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController;
@optional
- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController shouldPresentNearbyPeer:(MCPeerID *)peerID
            withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info;
@end
@interface MCBrowserViewController : UIViewController
- (instancetype)initWithServiceType:(NSString *)serviceType session:(MCSession *)session;
- (instancetype)initWithBrowser:(MCNearbyServiceBrowser *)browser session:(MCSession *)session NS_DESIGNATED_INITIALIZER;
@property (weak, nullable, nonatomic) id<MCBrowserViewControllerDelegate> delegate;
@property (readonly, nullable, nonatomic) MCNearbyServiceBrowser *browser;
@property (readonly, nonatomic) MCSession *session;
@property (assign, nonatomic) NSUInteger minimumNumberOfPeers;
@property (assign, nonatomic) NSUInteger maximumNumberOfPeers;
@end

@protocol MCAdvertiserAssistantDelegate <NSObject>
@optional
- (void)advertiserAssistantWillPresentInvitation:(MCAdvertiserAssistant *)advertiserAssistant;
- (void)advertiserAssistantDidDismissInvitation:(MCAdvertiserAssistant *)advertiserAssistant;
@end
@interface MCAdvertiserAssistant : NSObject
- (instancetype)initWithServiceType:(NSString *)serviceType discoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info
                            session:(MCSession *)session NS_DESIGNATED_INITIALIZER;
- (void)start;
- (void)stop;
@property (weak, nullable, nonatomic) id<MCAdvertiserAssistantDelegate> delegate;
@property (readonly, nonatomic) MCSession *session;
@property (readonly, nullable, nonatomic) NSDictionary<NSString *, NSString *> *discoveryInfo;
@property (readonly, nonatomic) NSString *serviceType;
@end

NS_ASSUME_NONNULL_END
#endif
