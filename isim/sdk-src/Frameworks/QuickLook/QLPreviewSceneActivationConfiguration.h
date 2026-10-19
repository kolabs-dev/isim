#pragma once
/* a window scene that previews files (issue #237). Activated (UIWindowScene.ActivationAction / ActivationInteraction,
 * a scene session request) it shows a QLPreviewController over the items, starting at initialPreviewIndex. Adapted:
 * isim presents it full screen over the app's window rather than in a window of its own. */
#import <UIKit/UIKit.h>
#import <QuickLook/QLPreviewController.h>
NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(15.0))
@interface QLPreviewSceneOptions : NSObject
@property (nonatomic, assign) NSInteger initialPreviewIndex;
@property (nonatomic, assign) QLPreviewItemEditingMode editingMode;
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@interface QLPreviewSceneActivationConfiguration : UIWindowSceneActivationConfiguration
- (instancetype)initWithItemsAtURLs:(NSArray<NSURL *> *)urls options:(nullable QLPreviewSceneOptions *)options NS_SWIFT_NAME(init(itemsAt:options:)) NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithUserActivity:(NSUserActivity *)userActivity NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
