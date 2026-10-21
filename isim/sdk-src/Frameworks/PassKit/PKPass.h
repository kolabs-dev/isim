#pragma once
/* isim PassKit: Wallet passes read from their .pkpass archives (the manifest's hashes are checked and the pass must be
 * signed; the signature's chain to Apple's WWDR certificate is not), and isim's Wallet (PKPassLibrary) in the device
 * data. */
#import <PassKit/PKConstants.h>
#import <PassKit/PKError.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface PKObject : NSObject
@end
@interface PKPassRelevantDate : NSObject
@property (nonatomic, copy, readonly, nullable) NSDate *date;
@property (nonatomic, copy, readonly, nullable) NSDateInterval *interval;
@end
@interface PKPass : PKObject
- (nullable instancetype)initWithData:(NSData *)data error:(NSError **)error;
@property (nonatomic, readonly) PKPassType passType;
@property (nonatomic, copy, readonly) NSString *serialNumber;
@property (nonatomic, copy, readonly) NSString *passTypeIdentifier;
@property (nonatomic, copy, readonly, nullable) NSURL *webServiceURL;
@property (nonatomic, copy, readonly, nullable) NSString *authenticationToken;
@property (nonatomic, copy, readonly) UIImage *icon;
@property (nonatomic, copy, readonly) NSString *localizedName;
@property (nonatomic, copy, readonly) NSString *localizedDescription;
@property (nonatomic, copy, readonly) NSString *organizationName;
@property (nonatomic, copy, readonly, nullable) NSDate *relevantDate;
@property (nonatomic, copy, readonly) NSArray<PKPassRelevantDate *> *relevantDates;
@property (nonatomic, copy, readonly, nullable) NSDictionary *userInfo;
@property (nonatomic, copy, readonly, nullable) NSURL *passURL;
@property (nonatomic, assign, readonly, getter=isRemotePass) BOOL remotePass;
@property (nonatomic, copy, readonly) NSString *deviceName;
- (nullable id)localizedValueForFieldKey:(NSString *)key;
@end
typedef NS_ENUM(NSInteger, PKPassLibraryAddPassesStatus) {
    PKPassLibraryDidAddPasses = 0, PKPassLibraryShouldReviewPasses, PKPassLibraryDidCancelAddPasses
};
typedef NSString * PKPassLibraryNotificationName NS_TYPED_ENUM;
PK_EXTERN PKPassLibraryNotificationName const PKPassLibraryDidChangeNotification;
PK_EXTERN PKPassLibraryNotificationName const PKPassLibraryRemotePaymentPassesDidChangeNotification;
typedef NSString * PKPassLibraryNotificationKey NS_TYPED_ENUM;
PK_EXTERN PKPassLibraryNotificationKey const PKPassLibraryAddedPassesUserInfoKey;
PK_EXTERN PKPassLibraryNotificationKey const PKPassLibraryReplacementPassesUserInfoKey;
PK_EXTERN PKPassLibraryNotificationKey const PKPassLibraryRemovedPassInfosUserInfoKey;
PK_EXTERN PKPassLibraryNotificationKey const PKPassLibraryPassTypeIdentifierUserInfoKey;
PK_EXTERN PKPassLibraryNotificationKey const PKPassLibrarySerialNumberUserInfoKey;
PK_EXTERN PKPassLibraryNotificationKey const PKPassLibraryRecoveredPassesUserInfoKey;
@interface PKPassLibrary : NSObject
+ (BOOL)isPassLibraryAvailable;
+ (BOOL)isSuppressingAutomaticPassPresentation;
- (NSArray<PKPass *> *)passes;
- (NSArray<PKPass *> *)passesOfType:(PKPassType)passType;
- (nullable PKPass *)passWithPassTypeIdentifier:(NSString *)identifier serialNumber:(NSString *)serialNumber;
- (BOOL)containsPass:(PKPass *)pass;
- (void)removePass:(PKPass *)pass;
- (BOOL)replacePassWithPass:(PKPass *)pass;
- (void)addPasses:(NSArray<PKPass *> *)passes withCompletionHandler:(nullable void (^)(PKPassLibraryAddPassesStatus status))completion;
- (void)openPaymentSetup;
- (BOOL)canAddFelicaPass;
@end
@class PKAddPassesViewController;
@protocol PKAddPassesViewControllerDelegate <NSObject>
@optional
- (void)addPassesViewControllerDidFinish:(PKAddPassesViewController *)controller;
@end
@interface PKAddPassesViewController : UIViewController
+ (BOOL)canAddPasses;
- (nullable instancetype)initWithPass:(PKPass *)pass;
- (nullable instancetype)initWithPasses:(NSArray<PKPass *> *)passes;
@property (nonatomic, weak, nullable) id<PKAddPassesViewControllerDelegate> delegate;
@end
@interface PKAddPassButton : UIButton
+ (instancetype)addPassButtonWithStyle:(PKAddPassButtonStyle)addPassButtonStyle;
- (instancetype)initWithAddPassButtonStyle:(PKAddPassButtonStyle)style;
@property (nonatomic, assign) PKAddPassButtonStyle addPassButtonStyle;
@end
NS_ASSUME_NONNULL_END
#endif
