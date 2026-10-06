#pragma once
/* isim SDK: UIImagePickerController and saving to the photo library (self-authored, API-compatible names). */
#import <UIKit/UINavigationController.h>
#import <UIKit/UIImage.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UIImagePickerControllerSourceType) {
    UIImagePickerControllerSourceTypePhotoLibrary = 0,
    UIImagePickerControllerSourceTypeCamera = 1,
    UIImagePickerControllerSourceTypeSavedPhotosAlbum = 2,
} NS_SWIFT_NAME(UIImagePickerController.SourceType);
typedef NS_ENUM(NSInteger, UIImagePickerControllerQualityType) {
    UIImagePickerControllerQualityTypeHigh = 0, UIImagePickerControllerQualityTypeMedium = 1, UIImagePickerControllerQualityTypeLow = 2,
} NS_SWIFT_NAME(UIImagePickerController.QualityType);
typedef NS_ENUM(NSInteger, UIImagePickerControllerCameraDevice) { UIImagePickerControllerCameraDeviceRear, UIImagePickerControllerCameraDeviceFront } NS_SWIFT_NAME(UIImagePickerController.CameraDevice);
typedef NS_ENUM(NSInteger, UIImagePickerControllerCameraCaptureMode) { UIImagePickerControllerCameraCaptureModePhoto, UIImagePickerControllerCameraCaptureModeVideo } NS_SWIFT_NAME(UIImagePickerController.CameraCaptureMode);
typedef NS_ENUM(NSInteger, UIImagePickerControllerCameraFlashMode) {
    UIImagePickerControllerCameraFlashModeOff = -1, UIImagePickerControllerCameraFlashModeAuto = 0, UIImagePickerControllerCameraFlashModeOn = 1 } NS_SWIFT_NAME(UIImagePickerController.CameraFlashMode);

typedef NSString *UIImagePickerControllerInfoKey NS_TYPED_ENUM NS_SWIFT_NAME(UIImagePickerController.InfoKey);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerMediaType NS_SWIFT_NAME(UIImagePickerController.InfoKey.mediaType);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerOriginalImage NS_SWIFT_NAME(UIImagePickerController.InfoKey.originalImage);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerEditedImage NS_SWIFT_NAME(UIImagePickerController.InfoKey.editedImage);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerCropRect NS_SWIFT_NAME(UIImagePickerController.InfoKey.cropRect);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerMediaURL NS_SWIFT_NAME(UIImagePickerController.InfoKey.mediaURL);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerReferenceURL NS_SWIFT_NAME(UIImagePickerController.InfoKey.referenceURL);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerMediaMetadata NS_SWIFT_NAME(UIImagePickerController.InfoKey.mediaMetadata);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerImageURL NS_SWIFT_NAME(UIImagePickerController.InfoKey.imageURL);
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerPHAsset NS_SWIFT_NAME(UIImagePickerController.InfoKey.phAsset);

@class UIImagePickerController;
@protocol UIImagePickerControllerDelegate <NSObject>
@optional
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
@end

/* The photo library source shows the device's photo library (isim's ISIM_DATA/Media); like the iOS Simulator there
 * is no camera: isSourceTypeAvailable(.camera) is NO and choosing it raises NSInvalidArgumentException. */
@interface UIImagePickerController : UINavigationController
+ (BOOL)isSourceTypeAvailable:(UIImagePickerControllerSourceType)sourceType;
+ (nullable NSArray<NSString *> *)availableMediaTypesForSourceType:(UIImagePickerControllerSourceType)sourceType;
+ (BOOL)isCameraDeviceAvailable:(UIImagePickerControllerCameraDevice)cameraDevice;
+ (BOOL)isFlashAvailableForCameraDevice:(UIImagePickerControllerCameraDevice)cameraDevice;
@property (nullable, nonatomic, weak) id<UINavigationControllerDelegate, UIImagePickerControllerDelegate> delegate;
@property (nonatomic) UIImagePickerControllerSourceType sourceType;
@property (nonatomic, copy) NSArray<NSString *> *mediaTypes;
@property (nonatomic) BOOL allowsEditing;
@property (nonatomic) UIImagePickerControllerQualityType videoQuality;
@property (nonatomic) NSTimeInterval videoMaximumDuration;
@property (nonatomic) BOOL showsCameraControls;
@property (nullable, nonatomic, strong) UIView *cameraOverlayView;
@property (nonatomic) UIImagePickerControllerCameraDevice cameraDevice;
@property (nonatomic) UIImagePickerControllerCameraCaptureMode cameraCaptureMode;
@property (nonatomic) UIImagePickerControllerCameraFlashMode cameraFlashMode;
- (void)takePicture;
@end

/* Saves to the device photo library; asks for add-only access (NSPhotoLibraryAddUsageDescription) the first time.
 * completionSelector: - (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo */
UIKIT_EXTERN void UIImageWriteToSavedPhotosAlbum(UIImage *image, id _Nullable completionTarget, SEL _Nullable completionSelector, void *_Nullable contextInfo);
UIKIT_EXTERN BOOL UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(NSString *videoPath);

NS_ASSUME_NONNULL_END
