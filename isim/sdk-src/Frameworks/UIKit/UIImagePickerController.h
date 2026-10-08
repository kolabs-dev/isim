#pragma once
/* isim SDK: UIImagePickerController and saving to the photo library (self-authored, API-compatible names).
 * Sources: the device photo library (ISIM_DATA/Media: photos and videos) and, when a simulated camera is configured
 * (ISIM_CAMERA, see AVFoundation), the camera: live preview, photo and video capture, front / back. */
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
    UIImagePickerControllerQualityType640x480 = 3, UIImagePickerControllerQualityTypeIFrame1280x720 = 4, UIImagePickerControllerQualityTypeIFrame960x540 = 5,
} NS_SWIFT_NAME(UIImagePickerController.QualityType);
typedef NS_ENUM(NSInteger, UIImagePickerControllerImageURLExportPreset) {
    UIImagePickerControllerImageURLExportPresetCompatible = 0, UIImagePickerControllerImageURLExportPresetCurrent,
} NS_SWIFT_NAME(UIImagePickerController.ImageURLExportPreset);
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
UIKIT_EXTERN UIImagePickerControllerInfoKey const UIImagePickerControllerLivePhoto NS_SWIFT_NAME(UIImagePickerController.InfoKey.livePhoto);

@class UIImagePickerController;
@protocol UIImagePickerControllerDelegate <NSObject>
@optional
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
@end

/* The photo library source shows the device's photo library (isim's ISIM_DATA/Media). The camera is available only
 * with a simulated camera (ISIM_CAMERA); without one, like the iOS Simulator, isSourceTypeAvailable(.camera) is NO
 * and choosing it raises NSInvalidArgumentException. */
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
@property (nonatomic) CGAffineTransform cameraViewTransform;
@property (nonatomic) UIImagePickerControllerImageURLExportPreset imageExportPreset;
@property (nonatomic, copy) NSString *videoExportPreset;
+ (nullable NSArray<NSNumber *> *)availableCaptureModesForCameraDevice:(UIImagePickerControllerCameraDevice)cameraDevice;
/* with showsCameraControls = NO: capture without the built-in controls */
- (void)takePicture;
- (BOOL)startVideoCapture;
- (void)stopVideoCapture;
@end

/* Saves to the device photo library; asks for add-only access (NSPhotoLibraryAddUsageDescription) the first time.
 * completionSelector: - (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo */
UIKIT_EXTERN void UIImageWriteToSavedPhotosAlbum(UIImage *image, id _Nullable completionTarget, SEL _Nullable completionSelector, void *_Nullable contextInfo);
UIKIT_EXTERN BOOL UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(NSString *videoPath);
/* completionSelector: - (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo */
UIKIT_EXTERN void UISaveVideoAtPathToSavedPhotosAlbum(NSString *videoPath, id _Nullable completionTarget, SEL _Nullable completionSelector, void *_Nullable contextInfo);

NS_ASSUME_NONNULL_END
