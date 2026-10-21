#pragma once
#import <Photos/PhotosTypes.h>
#import <Photos/PHChange.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHPhotoLibrary, UIViewController;
API_AVAILABLE(ios(8))
@protocol PHPhotoLibraryChangeObserver <NSObject>
- (void)photoLibraryDidChange:(PHChange *)changeInstance;
@end
API_AVAILABLE(ios(13))
@protocol PHPhotoLibraryAvailabilityObserver <NSObject>
- (void)photoLibraryDidBecomeUnavailable:(PHPhotoLibrary *)photoLibrary;
@end
/* isim: the device photo library ($ISIM_DATA/Media); the permission alert as on iOS (ISIM_PHOTOS_PERMISSION answers it) */
API_AVAILABLE(ios(8))
@interface PHPhotoLibrary : NSObject
+ (PHPhotoLibrary *)sharedPhotoLibrary;
+ (PHAuthorizationStatus)authorizationStatus;
+ (PHAuthorizationStatus)authorizationStatusForAccessLevel:(PHAccessLevel)accessLevel API_AVAILABLE(ios(14));
+ (void)requestAuthorization:(void (^)(PHAuthorizationStatus status))handler;
+ (void)requestAuthorizationForAccessLevel:(PHAccessLevel)accessLevel handler:(void (^)(PHAuthorizationStatus status))handler API_AVAILABLE(ios(14));
@property (readonly, atomic, nullable, strong) NSError *unavailabilityReason API_AVAILABLE(ios(13));
- (void)presentLimitedLibraryPickerFromViewController:(UIViewController *)controller API_AVAILABLE(ios(14));
- (void)presentLimitedLibraryPickerFromViewController:(UIViewController *)controller completionHandler:(void (^)(NSArray<NSString *> *))completionHandler API_AVAILABLE(ios(15));
/* the change block makes change requests; they apply together when it returns */
- (void)performChanges:(dispatch_block_t)changeBlock completionHandler:(nullable void (^)(BOOL success, NSError * _Nullable error))completionHandler;
- (BOOL)performChangesAndWait:(dispatch_block_t)changeBlock error:(NSError **)error;
- (void)registerChangeObserver:(id<PHPhotoLibraryChangeObserver>)observer;
- (void)unregisterChangeObserver:(id<PHPhotoLibraryChangeObserver>)observer;
/* isim: the library never becomes unavailable */
- (void)registerAvailabilityObserver:(id<PHPhotoLibraryAvailabilityObserver>)observer API_AVAILABLE(ios(13));
- (void)unregisterAvailabilityObserver:(id<PHPhotoLibraryAvailabilityObserver>)observer API_AVAILABLE(ios(13));
@end
NS_ASSUME_NONNULL_END
#endif
