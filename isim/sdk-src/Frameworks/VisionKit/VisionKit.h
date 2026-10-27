#pragma once
/* isim VisionKit for Objective-C: the document camera, whose classes are the VisionKit Swift overlay's (VisionKit.framework
   re-exports libswiftVisionKit.dylib). It runs on the simulated camera (ISIM_CAMERA): the page is found on the live frames,
   the shutter adds it, perspective-corrected, and Save hands the scan to the delegate. Without a camera isSupported is NO
   and the controller reports an error to its delegate when it appears, like the Simulator. DataScannerViewController and
   Live Text (ImageAnalyzer, ImageAnalysisInteraction) are Swift-only, as in Apple's SDK. Swift uses the overlay; these
   declarations are hidden from Swift. */
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

@interface VNDocumentCameraScan : NSObject
@property (nonatomic, readonly) NSUInteger pageCount;
@property (nonatomic, readonly, strong) NSString *title;
- (UIImage *)imageOfPageAtIndex:(NSUInteger)index;
- (instancetype)init NS_UNAVAILABLE;
@end

@class VNDocumentCameraViewController;
@protocol VNDocumentCameraViewControllerDelegate <NSObject>
@optional
- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFinishWithScan:(VNDocumentCameraScan *)scan;
- (void)documentCameraViewControllerDidCancel:(VNDocumentCameraViewController *)controller;
- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFailWithError:(NSError *)error;
@end

@interface VNDocumentCameraViewController : UIViewController
@property (class, nonatomic, readonly, getter=isSupported) BOOL supported;
@property (nonatomic, weak, nullable) id<VNDocumentCameraViewControllerDelegate> delegate;
- (instancetype)init;
@end

NS_ASSUME_NONNULL_END
#endif
