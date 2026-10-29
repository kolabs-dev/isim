#pragma once
/* isim PushKit for Objective-C: the classes are the PushKit Swift overlay's (PushKit.framework re-exports
   libswiftPushKit.dylib), with the same VoIP pushes as Swift (`isim push BUNDLE payload.apns` with "apns-push-type":
   "voip"; an app that does not report an incoming call to CallKit is terminated, like iOS 13+). Swift uses the
   overlay; these declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PKPushRegistry, PKPushCredentials, PKPushPayload, PKVoIPPushMetadata;

typedef NSString *PKPushType NS_STRING_ENUM;
FOUNDATION_EXPORT PKPushType const PKPushTypeVoIP;
FOUNDATION_EXPORT PKPushType const PKPushTypeFileProvider;
FOUNDATION_EXPORT PKPushType const PKPushTypeComplication;

@interface PKPushCredentials : NSObject
@property (readonly, copy) PKPushType type;
@property (readonly, copy) NSData *token;
@end

@interface PKPushPayload : NSObject
@property (readonly, copy) PKPushType type;
@property (readonly, copy) NSDictionary *dictionaryPayload;
@end

/* iOS 26.4: what the system says about a VoIP push (mustReport is NO while the app is in the foreground) */
API_AVAILABLE(ios(26.4))
@interface PKVoIPPushMetadata : NSObject
@property (readonly) BOOL mustReport;
@end

@protocol PKPushRegistryDelegate <NSObject>
@required
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)pushCredentials forType:(PKPushType)type;
@optional
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type
    withCompletionHandler:(void (^)(void))completion;
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type
    API_DEPRECATED_WITH_REPLACEMENT("-pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:", ios(8.0, 11.0));
- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type;
/* iOS 26.4: called instead of the method above for VoIP pushes when the delegate implements it */
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingVoIPPushWithPayload:(PKPushPayload *)payload
            metadata:(PKVoIPPushMetadata *)metadata withCompletionHandler:(void (^)(void))completion API_AVAILABLE(ios(26.4));
@end

@interface PKPushRegistry : NSObject
@property (nonatomic, weak, nullable) id<PKPushRegistryDelegate> delegate;
@property (nonatomic, copy, nullable) NSSet<PKPushType> *desiredPushTypes;
- (nullable NSData *)pushTokenForType:(PKPushType)type;
/* the delegate is called on the queue (NULL: the main queue) */
- (instancetype)initWithQueue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
#endif
