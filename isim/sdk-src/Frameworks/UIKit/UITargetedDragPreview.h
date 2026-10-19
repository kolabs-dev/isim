#pragma once
/* isim: targeted drag previews for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UITargetedPreview.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UITargetedDragPreview : UITargetedPreview
@end
NS_ASSUME_NONNULL_END
#endif
