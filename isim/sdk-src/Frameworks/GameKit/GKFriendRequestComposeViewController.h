#pragma once
/* isim GameKit: the friend request composer (the request goes to a player on isim's local Game Center). */
#import <GameKit/GKPlayer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GKFriendRequestComposeViewController;
@protocol GKFriendRequestComposeViewControllerDelegate <NSObject>
- (void)friendRequestComposeViewControllerDidFinish:(GKFriendRequestComposeViewController *)viewController;
@end
@interface GKFriendRequestComposeViewController : UIViewController
+ (NSUInteger)maxNumberOfRecipients;
- (void)setMessage:(nullable NSString *)message;
- (void)addRecipientPlayers:(NSArray<GKPlayer *> *)players;
- (void)addRecipientsWithEmailAddresses:(NSArray<NSString *> *)emailAddresses;
@property (nonatomic, weak, nullable) id<GKFriendRequestComposeViewControllerDelegate> composeViewDelegate;
@end
NS_ASSUME_NONNULL_END
#endif
