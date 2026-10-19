#pragma once
/* isim: drag items for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <Foundation/NSItemProvider.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UIDragPreview;
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UIDragItem : NSObject
- (instancetype)initWithItemProvider:(NSItemProvider *)itemProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) __kindof NSItemProvider *itemProvider;
@property (nullable, nonatomic, strong) id localObject;
@property (nullable, nonatomic, copy) UIDragPreview *_Nullable (^previewProvider)(void);
@end
NS_ASSUME_NONNULL_END
#endif
