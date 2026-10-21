#pragma once
/* isim GameKit: GKBasePlayer and GKPlayer (the local player, other isim devices on this computer, test players). */
#import <GameKit/GKDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, GKPhotoSize) { GKPhotoSizeSmall = 0, GKPhotoSizeNormal };
@interface GKBasePlayer : NSObject
@property (nonatomic, readonly, nullable) NSString *displayName;
@end
@interface GKPlayer : GKBasePlayer
- (BOOL)scopedIDsArePersistent;
@property (nonatomic, readonly) NSString *gamePlayerID;
@property (nonatomic, readonly) NSString *teamPlayerID;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *alias;
@property (nonatomic, readonly, nullable) NSString *guestIdentifier;
@property (nonatomic, readonly) BOOL isInvitable;
+ (instancetype)anonymousGuestPlayerWithIdentifier:(NSString *)guestIdentifier;
- (void)loadPhotoForSize:(GKPhotoSize)size withCompletionHandler:(void (^ _Nullable)(UIImage * _Nullable photo, NSError * _Nullable error))completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
