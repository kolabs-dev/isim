#pragma once
/* isim: drag previews for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIDragPreviewParameters.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UIDragPreview : NSObject
- (instancetype)initWithView:(UIView *)view parameters:(UIDragPreviewParameters *)parameters NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithView:(UIView *)view;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly, copy) UIDragPreviewParameters *parameters;
@end
NS_ASSUME_NONNULL_END
#endif
