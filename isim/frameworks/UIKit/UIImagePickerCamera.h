/* private: UIImagePickerController's camera screen and crop screen (UIImagePickerCamera.m) */
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

BOOL isim_ui_camera_available(void);
void isim_ui_camera_request_access(UIViewController *presenter, void (^done)(BOOL ok));

@interface __IsimCameraController : UIViewController
@property (nonatomic) UIImagePickerControllerCameraDevice cameraDevice;
@property (nonatomic) UIImagePickerControllerCameraCaptureMode captureMode;
@property (nonatomic) BOOL allowsPhoto, allowsVideo, showsControls;
@property (nonatomic) UIImagePickerControllerQualityType quality;
@property (nonatomic) NSTimeInterval maxDuration;
@property (nonatomic) CGAffineTransform previewTransform;
@property (nonatomic, strong, nullable) UIView *overlay;
@property (nonatomic, copy, nullable) void (^onPhoto)(UIImage *image, NSDictionary *metadata);
@property (nonatomic, copy, nullable) void (^onMovie)(NSURL *url);
@property (nonatomic, copy, nullable) void (^onCancel)(void);
@property (nonatomic, copy, nullable) void (^onModeChange)(UIImagePickerControllerCameraCaptureMode mode);
- (void)takePicture;
- (BOOL)startVideoCapture;
- (void)stopVideoCapture;
@end

@interface __IsimCropController : UIViewController
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy, nullable) NSString *cancelTitle;
@property (nonatomic, copy, nullable) void (^onChoose)(UIImage *edited, CGRect cropRect);
@property (nonatomic, copy, nullable) void (^onCancel)(void);
- (CGRect)cropRect;
@end

NS_ASSUME_NONNULL_END
